#import "IRCClient.h"
#import "Logger.h"

@implementation IRCClient

- (id)init {
    self = [super init];
    if (self) {
        _host = nil;
        _port = 0;
        _isConnected = NO;
		_debounceTimer = nil;
		_delegate = nil;
		
		_client = [[TCPClient alloc] init];
		[_client setDelegate:self];
		[_client setHost:@"localhost"];
		[_client setPort:1234];
    }
    return self;
}

- (void)dealloc {
    // Clean up socket and run loop source
    [self disconnect];
    
    // Release retained objects
	[_client release];
	[_host release];
	[_debounceTimer release];
    [super dealloc];
}

- (void)setHost:(NSString *)host {
	NSLog(@"IRC CLIENT  | setHost (%@)", host);
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
	NSDictionary *connectionDetails = [NSDictionary dictionaryWithObjectsAndKeys:
		@"192.168.1.100", @"host",
		@"21", @"port",
		@"ftpuser", @"username",
		@"ftptest", @"password",
		nil];
	NSLog(@"IRC CLIENT | fake details %@", connectionDetails);
	
	if (_delegate && [_delegate respondsToSelector:@selector(ircClient:didReceiveCredentials:)]) {
		[_delegate ircClient:self didReceiveCredentials:connectionDetails];
	}
	return NO;














	[_client setHost:[self host]];
	[_client setPort:[self port]];
	NSLog(@"IRC | connect to %@:%d", [_client host], [_client port]);
	[_client connect];
    return YES;
}

- (BOOL)processPrivateMessage:(NSString *)message {
	NSString *controlBString = [NSString stringWithFormat:@"%c", 0x02]; // shows as ^B in vim
	NSArray *components = [message componentsSeparatedByString:controlBString];

	if ([components count] != 10) return NO;
	if ([[components objectAtIndex:1] isEqualToString:@"FTP ADDRESS:"]) return YES;
	
	return NO;
}

- (NSDictionary *)getFTPConnectionDetails:(NSString *)message {
	NSString *controlBString = [NSString stringWithFormat:@"%c", 0x02]; // shows as ^B in vim
	NSArray *components = [message componentsSeparatedByString:controlBString];

	NSString *ftpHost = [[components objectAtIndex:2] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	NSString *ftpPort = [[components objectAtIndex:4] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	NSString *ftpUsername = [[components objectAtIndex:6] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	NSString *ftpPassword = [[components objectAtIndex:8] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	NSDictionary *connectionDetails = [NSDictionary dictionaryWithObjectsAndKeys:
		ftpHost, @"host",
		ftpPort, @"port",
		ftpUsername, @"username",
		ftpPassword, @"password",
		nil];
	NSLog(@"connection details: %@", connectionDetails);
	return connectionDetails;
}

- (void)disconnect {
	[self sendMessage:@"QUIT"];
	[_client disconnect];
}

- (BOOL)sendMessage:(NSString *)message {
    if (!_isConnected) {
        return NO;
    }
	
	NSLog(@"IRC | sending message: %@", message);
	
	NSString *messageWithNewline = [message stringByAppendingString:@"\r\n"];
	NSData *data = [messageWithNewline dataUsingEncoding:NSUTF8StringEncoding];
	[_client sendData:data];
	return YES;
}

- (BOOL)answerPing:(NSString *)pingMessage {
	NSArray *components = [pingMessage componentsSeparatedByString:@":"];
	if ([components count] == 2) {
		NSString *pongResponse = [NSString stringWithFormat:@"PONG :%@", [components objectAtIndex:1]];
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

- (void)setDelegate:(id<IRCClientDelegate>)delegate {
	NSLog(@"irc client setDelegate: %@", delegate);
    // Delegates are not retained to avoid retain cycles
    _delegate = delegate;
}

// TCPClientDelegate methods
- (void)tcpClientDidConnect:(id)client {
	NSLog(@"IRC | tcpClientDidConnect");
	_isConnected = YES;

	[self sendMessage:@"NICK app_learning_irc"];
	[self sendMessage:@"USER app_learning_irc 0 * :Trying to learn TCP and IRC app"];
//	[self sendMessage:[NSString stringWithFormat:@"NICK %@", [self _getRandomNick]]];
//	[self sendMessage:[NSString stringWithFormat:@"USER %@", [self _getRandomUser]]];
}

- (void)tcpClient:(id)client didReceiveData:(NSData *)data {
	NSString *message = [[NSString alloc] initWithData:data 
											  encoding:NSUTF8StringEncoding];
	NSLog(@"IRC | Received message: %@", message);
	
	// only listen to messages that start with colon
	//  - Handle PRIVMSG, ERROR, PING
	//  - split them and look for command (e.g. "001", "332")
	
	// after 001, send JOIN #xbins
	// after 332, send PRIVMSG #xbins !list
	// after PRIVMSG, if message has "FTP ADDRESS", parse it and get host, port, and credentials
	// after ERROR, disconnect
	
	// example message: :irc.efnet.nl 001 {nick} :Welcome to EFNet...
	
	if ([message hasPrefix:@"PING "]) {
		NSLog(@"A");
		[self answerPing:message];
	} else {
		if ([message hasPrefix:@":"]) {
			NSLog(@"B");
			NSArray *components = [message componentsSeparatedByString:@" "];
			if ([components count] > 0) {
				NSString *possibleCommand = [components objectAtIndex:1];
				NSLog(@"C possibleCommand: %@", possibleCommand);
			if ([possibleCommand isEqualToString:@"001"]) {
					[self sendMessage:@"JOIN #xbins"];
				} else if ([possibleCommand isEqualToString:@"332"]) {
					[self sendMessage:@"PRIVMSG #xbins !list"];
				} else if ([possibleCommand isEqualToString:@"PRIVMSG"]) {
					NSLog(@"Got a privmsg");
					if ([self processPrivateMessage:message]) {
						NSDictionary *ftpConnectionDetails = [self getFTPConnectionDetails:message];
						if (_delegate && [_delegate respondsToSelector:@selector(ircClient:didReceiveCredentials:)]) {
							[_delegate ircClient:self didReceiveCredentials:ftpConnectionDetails];
						}

						[self disconnect];
					} else {
						NSLog(@"That privmsg didn't look like FTP credentials");
					}
				}
			} else {
				NSLog(@"D");
				// no spaces in message... weird
			}
		}
	}
	
	[message release];
}

- (void)tcpClient:(id)client didFailWithError:(NSError *)error {
	NSLog(@"IRC | Connection failed with error: %@", error);
	_isConnected = NO;
}

- (void)tcpClientDidDisconnect:(id)client {
	NSLog(@"IRC | tcpClientDidDisconnect");
	_isConnected = NO;
}

@end
