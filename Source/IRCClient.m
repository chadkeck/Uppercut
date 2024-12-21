#import "IRCClient.h"

@implementation IRCClient

- (id)init {
    self = [super init];
    if (self) {
        _host = nil;
        _port = 0;
        _isConnected = NO;
		_debounceTimer = nil;
    }
    return self;
}

- (void)awakeFromNib {
	_client = [[TCPClient alloc] init];
	[_client setDelegate:self];
	[_client setHost:@"localhost"];
	[_client setPort:1234];
}

- (void)dealloc {
    // Clean up socket and run loop source
    [self disconnect];
    
    // Release retained objects
    [_host release];
    [super dealloc];
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
    return YES;
}

- (void)disconnect {
	// TODO: send QUIT message
}

- (BOOL)sendMessage:(NSString *)message {
    if (!_isConnected) {
        return NO;
    }
	
	NSString *messageWithNewline = [message stringByAppendingString:@"\r\n"];
	NSData *data = [messageWithNewline dataUsingEncoding:NSUTF8StringEncoding];
	[_client sendData:data];
	return YES;
}

- (BOOL)_answerPing:(NSString *)pingMessage {
	NSArray *components = [pingMessage componentsSeparatedByString:@":"];
	if ([components length] == 2) {
		NSString *pongResponse = [NSString stringWithFormat:@"PONG :%@", components[1]];
		[self sendMessage:pongResponse];
	}
	return NO;
}

- (NSString *)_getRandomUser {
	return [NSString stringWithFormat:@"%@ 0 * %@", [self _getRandomNick], [self _getRandomNick]];
}

- (NSString *)_getRandomNick {
	return [self _getRandomString:10];
}

// FIXME: this will probably be wrong on 64-bit systems
- (NSString *)_getRandomString:(int)length {
    static NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
    NSMutableString *randomString = [NSMutableString stringWithCapacity:length];

	int i;
    for (i = 0; i < length; i++) {
        uint32_t index = arc4random() % [letters length];
        unichar randomChar = [letters characterAtIndex:index];
        [randomString appendFormat:@"%C", randomChar];
    }

    return randomString;
}


// TCPClientDelegate methods
- (void)tcpClientDidConnect:(id)client {
	_isConnected = NO;
}

- (void)tcpClient:(id)client didReceiveData:(NSData *)data {
	NSString *message = [[NSString alloc] initWithData:data 
											  encoding:NSUTF8StringEncoding];
	NSLog(@"Received message: %@", message);
	
	if ([message hasPrefix:@"PING "]) {
		[self answerPing:message];
	}
	
//	[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
	
	[message release];
}

- (void)tcpClient:(id)client didFailWithError:(NSError *)error {
	NSLog(@"Connection failed with error: %@", error);
	_isConnected = NO;
}

- (void)tcpClientDidDisconnect:(id)client {
	_isConnected = NO;
}

@end
