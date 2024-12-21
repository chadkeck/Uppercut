#import "TCPClient.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <netdb.h>

// Callback function for socket events
static void socketCallback(CFSocketRef socket, CFSocketCallBackType type, 
    CFDataRef address, const void *data, void *info) {
    
    TCPClient *client = (TCPClient *)info;
    
    switch (type) {
        case kCFSocketConnectCallBack:
            if (data == NULL) {
                NSLog(@"Connection established successfully");
                [client performSelectorOnMainThread:@selector(handleConnect) 
                    withObject:nil waitUntilDone:NO];
            } else {
                NSLog(@"Connection failed");
                NSError *error = [NSError errorWithDomain:@"TCPClientError" 
                    code:1 userInfo:nil];
                [client performSelectorOnMainThread:@selector(handleError:) 
                    withObject:error waitUntilDone:NO];
            }
            break;
            
        case kCFSocketDataCallBack: {
            NSData *receivedData = (NSData *)data;
            NSLog(@"Received %d bytes of data", [receivedData length]);
            [client performSelectorOnMainThread:@selector(handleReceiveData:) 
                withObject:receivedData waitUntilDone:NO];
            break;
        }
    }
}

@implementation TCPClient

- (id)init {
    self = [super init];
    if (self) {
        _socket = NULL;
        _host = nil;
        _port = 0;
        _delegate = nil;
        _runLoopSource = NULL;
        _isConnected = NO;
    }
    return self;
}

- (void)dealloc {
    // Clean up socket and run loop source
    [self disconnect];
    
    // Release retained objects
    [_host release];
    [super dealloc];
}

// Getter/setter implementations with proper memory management
- (void)setDelegate:(id<TCPClientDelegate>)delegate {
    // Delegates are not retained to avoid retain cycles
    _delegate = delegate;
}

- (id<TCPClientDelegate>)delegate {
    return _delegate;
}

- (void)setHost:(NSString *)host {
    // Retain new value, release old value
    [host retain];
    [_host release];
    _host = host;
}

- (NSString *)host {
    return _host;
}

- (void)setPort:(int)port {
    _port = port;
}

- (int)port {
    return _port;
}

- (BOOL)isConnected {
    return _isConnected;
}

- (BOOL)connect {
    if (_socket != NULL) {
        return NO;
    }
    
    // Create socket context
    CFSocketContext context;
    memset(&context, 0, sizeof(context));
    context.info = (void *)self;
    
    // Create socket with callbacks
    _socket = CFSocketCreate(kCFAllocatorDefault, PF_INET, SOCK_STREAM, 
        IPPROTO_TCP, kCFSocketConnectCallBack | kCFSocketDataCallBack,
        socketCallback, &context);
        
    if (_socket == NULL) {
        NSLog(@"Failed to create socket");
        return NO;
    }
    
    // Set socket options
    int yes = 1;
    setsockopt(CFSocketGetNative(_socket), SOL_SOCKET, SO_REUSEADDR, 
        (void *)&yes, sizeof(yes));
    
    // Create run loop source and add to current run loop
    _runLoopSource = CFSocketCreateRunLoopSource(kCFAllocatorDefault, 
        _socket, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), _runLoopSource, 
        kCFRunLoopCommonModes);
    
    // Resolve hostname
    struct hostent *host = gethostbyname([_host UTF8String]);
    if (!host) {
        NSLog(@"Failed to resolve hostname");
        [self disconnect];
        return NO;
    }
    
    // Set up connection address
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(_port);
    addr.sin_addr = *((struct in_addr *)host->h_addr);
    
    // Connect socket
    CFDataRef addressData = CFDataCreate(NULL, (UInt8 *)&addr, sizeof(addr));
    CFSocketConnectToAddress(_socket, addressData, -1);
    CFRelease(addressData);
    
    NSLog(@"Attempting connection to %@:%d", _host, _port);
    return YES;
}

- (void)disconnect {
    if (_socket != NULL) {
        CFSocketInvalidate(_socket);
        CFRelease(_socket);
        _socket = NULL;
    }
    
    if (_runLoopSource != NULL) {
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), _runLoopSource, 
            kCFRunLoopCommonModes);
        CFRelease(_runLoopSource);
        _runLoopSource = NULL;
    }
    
    _isConnected = NO;
    NSLog(@"Disconnected");
    
    if (_delegate && [_delegate respondsToSelector:@selector(tcpClientDidDisconnect:)]) {
        [_delegate tcpClientDidDisconnect:self];
    }
}

- (BOOL)sendData:(NSData *)data {
    if (!_isConnected || _socket == NULL) {
        return NO;
    }
    
    CFSocketError result = CFSocketSendData(_socket, NULL, (CFDataRef)data, -1);
    if (result == kCFSocketSuccess) {
        NSLog(@"Sent %d bytes of data", [data length]);
        return YES;
    } else {
        NSLog(@"Failed to send data");
        return NO;
    }
}

// Internal handlers for socket callbacks
- (void)handleConnect {
    _isConnected = YES;
    if (_delegate && [_delegate respondsToSelector:@selector(tcpClientDidConnect:)]) {
        [_delegate tcpClientDidConnect:self];
    }
}

- (void)handleReceiveData:(NSData *)data {
    if (_delegate && [_delegate respondsToSelector:@selector(tcpClient:didReceiveData:)]) {
        [_delegate tcpClient:self didReceiveData:data];
    }
}

- (void)handleError:(NSError *)error {
    if (_delegate && [_delegate respondsToSelector:@selector(tcpClient:didFailWithError:)]) {
        [_delegate tcpClient:self didFailWithError:error];
    }
    [self disconnect];
}

@end
