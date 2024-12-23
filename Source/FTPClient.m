#import "FTPClient.h"

@implementation FTPClient

static void dataSocketCallback(CFSocketRef socket, 
                             CFSocketCallBackType type,
                             CFDataRef address,
                             const void *data,
                             void *info) {
    FTPClient *client = (FTPClient *)info;
	NSLog(@"xxxxxxxxxxxxxxxxxxxxxxxx");
    if (type == kCFSocketAcceptCallBack) {
        CFSocketNativeHandle nativeSocketHandle = *(CFSocketNativeHandle *)data;
        CFReadStreamRef readStream = NULL;
        CFWriteStreamRef writeStream = NULL;
        
        CFStreamCreatePairWithSocket(kCFAllocatorDefault, 
                                   nativeSocketHandle,
                                   &readStream,
                                   &writeStream);
        
        if (readStream && writeStream) {
            client->dataStream = readStream;
            client->dataWriteStream = writeStream;
            CFReadStreamOpen(readStream);
            CFWriteStreamOpen(writeStream);
        }
    }
}

- (id)initWithHostname:(NSString *)host
				  port:(int)portNumber
			  username:(NSString *)user
			  password:(NSString *)pass
				  mode:(FTPMode)ftpMode {
    self = [super init];
    if (self) {
        hostname = [host retain];
        commandPort = portNumber;
		username = [user retain];
		password = [pass retain];
        mode = ftpMode;
        isConnected = NO;
		isAuthenticated = NO;
        receivedData = [[NSMutableData alloc] init];
        fileData = [[NSMutableData alloc] init];
        transferType = FTPTransferTypeASCII;
        currentDirectory = [@"/" retain];
    }
    return self;
}

- (void)dealloc {
    [self disconnect];
    [hostname release];
	[username release];
	[password release];
    [receivedData release];
    [fileData release];
    [currentDirectory release];
    [pendingFilename release];
    [super dealloc];
}

- (void)setDelegate:(id<FTPClientDelegate>)aDelegate {
    delegate = aDelegate;
}

- (void)authenticate {
	NSString *userCommand = [NSString stringWithFormat:@"USER %@", username];
	NSLog(@"FTP | authenticate sending command %@", userCommand);
	[self sendCommand:userCommand];
}

- (void)setupActiveMode {
    struct sockaddr_in addr;
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port = 0;
	
	NSLog(@"FTP | setupActiveMode");
    
    CFSocketContext context = {0, self, NULL, NULL, NULL};
    listenSocket = CFSocketCreate(kCFAllocatorDefault,
                                PF_INET,
                                SOCK_STREAM,
                                IPPROTO_TCP,
                                kCFSocketAcceptCallBack,
                                dataSocketCallback,
                                &context);
    
    CFDataRef addressData = CFDataCreate(NULL, (UInt8 *)&addr, sizeof(addr));
    CFSocketSetAddress(listenSocket, addressData);
    CFRelease(addressData);
    
    // Get the assigned port
    addressData = CFSocketCopyAddress(listenSocket);
    struct sockaddr_in *actualAddr = (struct sockaddr_in *)CFDataGetBytePtr(addressData);
    dataPort = ntohs(actualAddr->sin_port);
    CFRelease(addressData);
    
    CFRunLoopSourceRef source = CFSocketCreateRunLoopSource(kCFAllocatorDefault,
                                                          listenSocket,
                                                          0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopCommonModes);
    CFRelease(source);
}

- (BOOL)connect {
    CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault,
                                     (CFStringRef)hostname,
                                     commandPort,
                                     &commandStream,
                                     &commandWriteStream);
    
    if (!commandStream || !commandWriteStream) {
        if ([delegate respondsToSelector:@selector(ftpClient:didFailWithError:)]) {
            NSError *error = [NSError errorWithDomain:@"FTPClientError" 
                                               code:-1 
                                           userInfo:nil];
            [delegate ftpClient:self didFailWithError:error];
        }
        return NO;
    }

    if (mode == FTPModeActive) {
        [self setupActiveMode];
    }

    CFReadStreamOpen(commandStream);
    CFWriteStreamOpen(commandWriteStream);
    
    isConnected = YES;
	[self authenticate];
    
    if ([delegate respondsToSelector:@selector(ftpClientDidConnect:)]) {
        [delegate ftpClientDidConnect:self];
    }
    
    return YES;
}

- (void)disconnect {
//	NSLog(@"FTP | disconnect | commandStream: %@ | commandWriteStream: %@", commandStream, commandWriteStream);
    if (commandStream) {
        CFReadStreamClose(commandStream);
        CFRelease(commandStream);
        commandStream = NULL;
    }
    
    if (commandWriteStream) {
        CFWriteStreamClose(commandWriteStream);
        CFRelease(commandWriteStream);
        commandWriteStream = NULL;
    }
    
    if (dataStream) {
        CFReadStreamClose(dataStream);
        CFRelease(dataStream);
        dataStream = NULL;
    }
    
    if (dataWriteStream) {
        CFWriteStreamClose(dataWriteStream);
        CFRelease(dataWriteStream);
        dataWriteStream = NULL;
    }
    
    if (listenSocket) {
        CFSocketInvalidate(listenSocket);
        CFRelease(listenSocket);
        listenSocket = NULL;
    }
    
    isConnected = NO;
    
    if ([delegate respondsToSelector:@selector(ftpClientDidDisconnect:)]) {
        [delegate ftpClientDidDisconnect:self];
    }
}

- (void)setTransferType:(FTPTransferType)type {
    transferType = type;
    NSString *typeCommand = (type == FTPTransferTypeASCII) ? @"TYPE A" : @"TYPE I";
    [self sendCommand:typeCommand];
}

- (void)changeToDirectory:(NSString *)directory {
    NSString *command = [NSString stringWithFormat:@"CWD %@", directory];
    [self sendCommand:command];
    [currentDirectory release];
    currentDirectory = [directory retain];
}

- (void)listDirectory {
    if (mode == FTPModePassive) {
        [self sendCommand:@"PASV"];
    } else {
        struct sockaddr_in addr;
        socklen_t len = sizeof(addr);
        getsockname(CFSocketGetNative(listenSocket), (struct sockaddr *)&addr, &len);
        
        UInt8 *ip = (UInt8 *)&(addr.sin_addr.s_addr);
        UInt8 *port = (UInt8 *)&dataPort;
        
        NSString *portCommand = [NSString stringWithFormat:@"PORT %d,%d,%d,%d,%d,%d",
                               ip[0], ip[1], ip[2], ip[3], port[0], port[1]];
        [self sendCommand:portCommand];
    }
    
    [self sendCommand:@"LIST"];
}

- (void)downloadFile:(NSString *)filename {
    [pendingFilename release];
    pendingFilename = [filename retain];
    
    [self setTransferType:FTPTransferTypeBinary];
    
    if (mode == FTPModePassive) {
        [self sendCommand:@"PASV"];
    } else {
        struct sockaddr_in addr;
        socklen_t len = sizeof(addr);
        getsockname(CFSocketGetNative(listenSocket), (struct sockaddr *)&addr, &len);
        
        UInt8 *ip = (UInt8 *)&(addr.sin_addr.s_addr);
        UInt8 *port = (UInt8 *)&dataPort;
        
        NSString *portCommand = [NSString stringWithFormat:@"PORT %d,%d,%d,%d,%d,%d",
                               ip[0], ip[1], ip[2], ip[3], port[0], port[1]];
        [self sendCommand:portCommand];
    }
    
    NSString *command = [NSString stringWithFormat:@"RETR %@", filename];
    [self sendCommand:command];
}

- (BOOL)sendCommand:(NSString *)command {
    if (!isConnected) return NO;
    
    NSString *commandString = [NSString stringWithFormat:@"%@\r\n", command];
    NSData *data = [commandString dataUsingEncoding:NSUTF8StringEncoding];
    
    if (!CFWriteStreamCanAcceptBytes(commandWriteStream)) return NO;
    
    CFIndex bytesWritten = CFWriteStreamWrite(commandWriteStream,
                                            [data bytes],
                                            [data length]);
    
    return (bytesWritten == [data length]);
}

// Handle server responses here. This is a simplified version.
// In a real implementation, you'd want to handle response codes,
// parse directory listings, etc.
- (void)handleResponse:(NSString *)response {
	NSLog(@"FTP | handleResponse: %@", response);
    NSArray *lines = [response componentsSeparatedByString:@"\r\n"];
	
	int i;
	for (i = 0; i < [lines count]; i++) {
		NSString *line = [lines objectAtIndex:i];
        if ([line length] < 3) continue;
        
        NSString *code = [line substringToIndex:3];
		if ([code isEqualToString:@"331"]) { // username OK, need password
			NSLog(@"FTP | asking for password");
			NSString *passCommand = [NSString stringWithFormat:@"PASS %@", password];
			[self sendCommand:passCommand];
		} else if ([code isEqualToString:@"230"]) { // user logged in
			NSLog(@"FTP | user logged in");
			isAuthenticated = YES;
		} else if ([code isEqualToString:@"227"]) { // Passive mode response
            // Parse PASV response and create data connection
            NSScanner *scanner = [NSScanner scannerWithString:line];
            [scanner scanUpToString:@"(" intoString:NULL];
            
            int i1, i2, i3, i4, p1, p2;
            char dummy;
            [scanner scanString:@"(" intoString:NULL];
            [scanner scanInt:&i1];
            [scanner scanString:@"," intoString:NULL];
            [scanner scanInt:&i2];
            [scanner scanString:@"," intoString:NULL];
            [scanner scanInt:&i3];
            [scanner scanString:@"," intoString:NULL];
            [scanner scanInt:&i4];
            [scanner scanString:@"," intoString:NULL];
            [scanner scanInt:&p1];
            [scanner scanString:@"," intoString:NULL];
            [scanner scanInt:&p2];
            
            int dataPort = (p1 * 256) + p2;
            NSString *dataHost = [NSString stringWithFormat:@"%d.%d.%d.%d", 
                                i1, i2, i3, i4];
            
            CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault,
                                             (CFStringRef)dataHost,
                                             dataPort,
                                             &dataStream,
                                             &dataWriteStream);
            
            CFReadStreamOpen(dataStream);
            CFWriteStreamOpen(dataWriteStream);
        }
    }
}

@end
