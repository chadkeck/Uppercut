#import "IRCClient.h"
#import "Logger.h"
#import "NetworkStatusEnum.h"

@implementation IRCClient

- (id)init {
    self = [super init];
    if (self) {
        _host = nil;
        _port = 0;
        _isConnected = NO;
		
		_tcpClient = [[TCPClient alloc] init];
		[_tcpClient setDelegate:self];
		[_tcpClient setHost:@"localhost"];
		[_tcpClient setPort:1234];
    }
    return self;
}

- (void)dealloc {
    // Clean up socket and run loop source
    [self disconnect];
    
    // Release retained objects
	[_tcpClient release];
	[_host release];

    [super dealloc];
}

#pragma mark Getters/setters

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

#pragma mark - Connection

- (BOOL)isConnected {
    return _isConnected;
}

- (BOOL)connect {

/*
	// Testing connection
	NSDictionary *connectionDetails = [NSDictionary dictionaryWithObjectsAndKeys:
		@"192.168.1.100", @"host",
		@"21", @"port",
		@"ftpuser", @"username",
		@"ftptest", @"password",
		nil];
	NSLog(@"IRC CLIENT | fake details %@", connectionDetails);
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"ftpCredentialsReceived"
														object:self
													  userInfo:connectionDetails];
	return NO;
*/









//	[_tcpClient setHost:@"efnet.port80.se"]; // this hostname fails to resolve
	[_tcpClient setHost:[self host]];
	[_tcpClient setPort:[self port]];
	NSLog(@"IRC | connect to %@:%d", [_tcpClient host], [_tcpClient port]);
	return [_tcpClient connect];
}

- (void)disconnect {
	[self _sendMessage:@"QUIT"];
	[_tcpClient disconnect];
//	[self _sendConnectionUpdate:[NSNumber numberWithInt:NetworkStatusStateDisconnected]];
}

#pragma mark - Private

- (BOOL)_processPrivateMessage:(NSString *)message {
	NSString *controlBString = [NSString stringWithFormat:@"%c", 0x02]; // shows as ^B in vim
	NSArray *components = [message componentsSeparatedByString:controlBString];

	if ([components count] != 11) return NO;
	if ([[components objectAtIndex:1] isEqualToString:@"FTP ADDRESS:"]) return YES;
	
	return NO;
}

- (NSDictionary *)_getFTPConnectionDetails:(NSString *)message {
	NSString *controlBString = [NSString stringWithFormat:@"%c", 0x02]; // shows as ^B in vim
	NSArray *components = [message componentsSeparatedByString:controlBString];

	NSString *ftpHost =     [[components objectAtIndex:2] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	NSString *ftpPort =     [[components objectAtIndex:4] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
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

- (BOOL)_sendMessage:(NSString *)message {
    if (!_isConnected) {
        return NO;
    }
	
	NSLog(@"IRC | sending message: %@", message);
	
	NSString *messageWithNewline = [message stringByAppendingString:@"\r\n"];
	NSData *data = [messageWithNewline dataUsingEncoding:NSUTF8StringEncoding];
	[_tcpClient sendData:data];
	return YES;
}

- (BOOL)_answerPing:(NSString *)pingMessage {
	NSArray *components = [pingMessage componentsSeparatedByString:@":"];
	if ([components count] == 2) {
		NSString *pongResponse = [NSString stringWithFormat:@"PONG :%@", [components objectAtIndex:1]];
		[self _sendMessage:pongResponse];
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

- (void)_sendConnectionUpdate:(NSString *)update withState:(NSNumber *)state {
	NSDictionary *connectionInfo = [NSDictionary dictionaryWithObjectsAndKeys:
		update, @"update",
		state, @"state",
		nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"connectionUpdate"
													object:self
												  userInfo:connectionInfo];
}

#pragma mark - TCPClientDelegate

- (void)tcpClientDidConnect:(id)client {
	NSLog(@"IRC | tcpClientDidConnect");
	_isConnected = YES;
	
	[self _sendConnectionUpdate:@"Connected to IRC..."
					  withState:[NSNumber numberWithInt:NetworkStatusStateConnected]];

	[self _sendMessage:@"NICK app_learning_irc"];
	[self _sendMessage:@"USER app_learning_irc 0 * :Trying to learn TCP and IRC app"];
//	[self _sendMessage:[NSString stringWithFormat:@"NICK %@", [self _getRandomNick]]];
//	[self _sendMessage:[NSString stringWithFormat:@"USER %@", [self _getRandomUser]]];
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
		[self _answerPing:message];
	} else {
		if ([message hasPrefix:@":"]) {
			NSArray *components = [message componentsSeparatedByString:@" "];
			if ([components count] > 0) {
				NSString *possibleCommand = [components objectAtIndex:1];
			if ([possibleCommand isEqualToString:@"001"]) {
					[self _sendMessage:@"JOIN #xbins"];
				} else if ([possibleCommand isEqualToString:@"332"]) {
					[self _sendMessage:@"PRIVMSG #xbins !list"];
				} else if ([possibleCommand isEqualToString:@"PRIVMSG"]) {
					NSLog(@"Got a privmsg");
					if ([self _processPrivateMessage:message]) {
						NSDictionary *ftpConnectionDetails = [self _getFTPConnectionDetails:message];
						[[NSNotificationCenter defaultCenter] postNotificationName:@"ftpCredentialsReceived"
																			object:self
																		  userInfo:ftpConnectionDetails];
						[self disconnect];
					}
				}
			} else {
				// no spaces in message... weird
			}
		}
	}
	
	[message release];
}

- (void)tcpClient:(id)client didFailWithError:(NSError *)error {
	NSLog(@"IRC | Connection failed with error: %@", error);
	_isConnected = NO;
	[self _sendConnectionUpdate:@"IRC connection failed"
					 withState:[NSNumber numberWithInt:NetworkStatusStateDisconnected]];
}

// This is called after we disconnect from IRC after received credentials.
// It's also called when the hostname fails to resolve.
- (void)tcpClientDidDisconnect:(id)client {
	NSLog(@"IRC | tcpClientDidDisconnect");
	_isConnected = NO;

	// Happy path:
	//   We don't need to send an update message since we'll immediately move into
	//   connecting to FTP.
}

@end
