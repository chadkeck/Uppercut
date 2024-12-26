#import "FTPClient.h"
#import <Foundation/NSRange.h>

// Private interface
@interface FTPClient (Private)
- (void)_sendCommand:(NSString *)command;
- (void)_parseResponse:(NSString *)response;
- (void)_setupDataConnection;
- (void)_handleCommandResponse:(NSString *)response;
- (void)_handleDataResponse:(NSString *)response;
- (int)_parsePortNumber:(NSString *)portString;
@end

@implementation FTPClient

- (id)init {
    self = [super init];
    if (self) {
        _commandClient = [[TCPClient alloc] init];
        _dataClient = [[TCPClient alloc] init];
		
        _host = nil;
        _port = 21; // Default FTP port
        _username = nil;
        _password = nil;
		
        _isConnected = NO;
        _isAuthenticated = NO;
        _transferMode = FTPTransferModePassive;
		
        _responseBuffer = [[NSMutableString alloc] init];
        _delegate = nil;
		
        // Set up both command and data connection delegates
        [_commandClient setDelegate:self];
		[_dataClient setDelegate:self];
		
		// Store the current file being transferred 
		_currentFile = nil;
    }
    return self;
}

- (void)dealloc {
    [self disconnect];
	
    [_commandClient release];
    [_dataClient release];
    [_host release];
    [_username release];
    [_password release];
    [_responseBuffer release];
	
    [super dealloc];
}

#pragma mark - Property accessors

- (void)setHost:(NSString *)host {
    if (_host != host) {
        [host retain];
        [_host release];
        _host = host;
    }
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

- (void)setUsername:(NSString *)username {
    if (_username != username) {
        [username retain];
        [_username release];
        _username = username;
    }
}

- (void)setPassword:(NSString *)password {
    if (_password != password) {
        [password retain];
        [_password release];
        _password = password;
    }
}

- (void)setTransferMode:(FTPTransferMode)mode {
    _transferMode = mode;
}

- (BOOL)isConnected {
    return _isConnected;
}

#pragma mark - Connection Management

- (BOOL)connect {
    if (_isConnected) {
        return NO;
    }
    
    [_commandClient setHost:_host];
    [_commandClient setPort:_port];
    return [_commandClient connect];
}

- (void)disconnect {
    if (_isConnected) {
        [self _sendCommand:@"QUIT"];
    }
    
    [_commandClient disconnect];
    [_dataClient disconnect];
    
    _isConnected = NO;
    _isAuthenticated = NO;
}

#pragma mark - FTP Commands

- (void)authenticate {
    if (!_isConnected || _isAuthenticated) {
        return;
    }
    
    // Send username
    NSString *userCommand = [NSString stringWithFormat:@"USER %@", _username];
    [self _sendCommand:userCommand];
}

- (NSString *)escapeSpacesInString:(NSString *)input {
	if (!input) return nil;

	NSMutableString *output = [NSMutableString stringWithString:input];

	// Define replacements
	NSDictionary *replacements = [NSDictionary dictionaryWithObjectsAndKeys:
		@" ", @"\\ ",
		nil];

	// Perform replacements
	NSEnumerator *enumerator = [replacements keyEnumerator];
	NSString *character;
	while ((character = [enumerator nextObject])) {
		[output replaceOccurrencesOfString:character
								withString:[replacements objectForKey:character]
								   options:NSLiteralSearch
									 range:NSMakeRange(0, [output length])];
	}

	return output;
}

- (void)listDirectory:(NSString *)path {
	NSLog(@"FTP | listDirectory %@ | _isAuthenticated %@", path, _isAuthenticated ? @"YES" : @"NO");
    if (!_isAuthenticated) {
        return;
    }
    
    // Set up data connection first
    [self _setupDataConnection];
    
    // Send LIST command
	if ([path length] > 0) {
		NSString *escapedPath = [self escapeSpacesInString:path];
		NSString *listCommand = [NSString stringWithFormat:@"LIST %@", escapedPath];
		[self _sendCommand:listCommand];
	} else {
		[self _sendCommand:@"LIST"];
	}
}

- (void)changeDirectory:(NSString *)path {
    if (!_isAuthenticated) {
        return;
    }
    
    NSString *cdCommand = [NSString stringWithFormat:@"CWD %@", path];
    [self _sendCommand:cdCommand];
}

- (void)downloadFile:(NSString *)path {
    if (!_isAuthenticated) {
		NSLog(@"FTP | WARNING | downloadFile called when not authenticated");
        return;
    }
	
	[path retain];
	[_currentFile release];
	_currentFile = path;
    
    // Set up data connection
    [self _setupDataConnection];
    
    // Set binary mode for file transfer
    [self _sendCommand:@"TYPE I"];
    
    // Send RETR command
    NSString *retrCommand = [NSString stringWithFormat:@"RETR %@", path];
    [self _sendCommand:retrCommand];
}

#pragma mark - Private Methods

- (void)_sendCommand:(NSString *)command {
    NSString *commandWithNewline = [command stringByAppendingString:@"\r\n"];
    NSData *data = [commandWithNewline dataUsingEncoding:NSUTF8StringEncoding];
    [_commandClient sendData:data];
    
    NSLog(@"FTP | Sent command: (%@)", command);
}

- (void)_setupDataConnection {
    if (_transferMode == FTPTransferModePassive) {
        // Request passive mode
        [self _sendCommand:@"PASV"];
    } else {
        // Active mode not implemented in this example
        NSLog(@"FTP | Active mode not implemented");
    }
}

- (void)_handlePASV:(NSString *)response {
	NSString *numbersString = nil;
	
	// Find position of first parenthesis
	unsigned int openPos = 0;
	unsigned int closePos = 0;
	unsigned int length = [response length];
	unsigned int i;
	
	// Search for opening parenthesis
	for (i = 0; i < length; i++) {
		if ([response characterAtIndex:i] == '(') {
			openPos = i;
			break;
		}
	}

	// Search for closing parenthesis
	for (i = length - 1; i > openPos; i--) {
		if ([response characterAtIndex:i] == ')') {
			closePos = i;
			break;
		}
	}

	// Extract numbers if parentheses were found
	if (openPos > 0 && closePos > openPos) {
		numbersString = [response substringWithRange:NSMakeRange(openPos + 1, closePos - openPos - 1)];
	
		NSArray *components = [numbersString componentsSeparatedByString:@","];
		NSLog(@"FTP | PASV components: %@", components);
		if ([components count] >= 6) {
			int p1 = [[components objectAtIndex:4] intValue];
			int p2 = [[components objectAtIndex:5] intValue];
			int dataPort = (p1 * 256) + p2;
		
			// Connect data client
			[_dataClient disconnect]; // clear any previous socket
			[_dataClient setHost:_host];
			[_dataClient setPort:dataPort];
			NSLog(@"FTP | PASV | _dataClient %@", _dataClient);
			NSLog(@"FTP | PASV | connecting to %@:%d", _host, dataPort);
			if (![_dataClient connect]) {
				NSLog(@"FTP | PASV | connect failed", _host, dataPort);
			}
		}
	}
}

- (void)_handleCommandResponse:(NSString *)response {
	NSLog(@"FTP | _handleCommandResponse %@", response);
    // Parse response code
    if ([response length] < 3) {
		NSLog(@"FTP | WARNING | response length < 3");
        return;
    }
    
    int responseCode = [[response substringToIndex:3] intValue];
    
    switch (responseCode) {
        case 220: // Service ready
            if (!_isAuthenticated && _username) {
                [self authenticate];
            }
            break;
			
		case 226: // Directory send OK
			// TODO: might have to use this when an empty directory is navigated to since the data client doesn't seem to get any data
			break;
			
        case 227:
            // Entering passive mode
            // Parse passive mode response (h1,h2,h3,h4,p1,p2)
			[self _handlePASV:response];
			break;
	
		case 331: // Username OK, need password
			if (_password) {
				NSString *passCommand = [NSString stringWithFormat:@"PASS %@", _password];
				[self _sendCommand:passCommand];
			}
			break;
		
		case 230: // User logged in
			_isAuthenticated = YES;
			if (_delegate && [_delegate respondsToSelector:@selector(ftpClientDidAuthenticate:)]) {
				[_delegate ftpClientDidAuthenticate:self];
			}
			break;
			
		case 421: // Timeout
			[self disconnect];
			break;
		
		default:
			NSLog(@"FTP | default case hit");
			break;
	}
}

- (void)_handleDataResponse:(NSString *)response {
	NSLog(@"FTP | _handleDataResponse %@", response);
	if ([response length] == 0) {
		// TODO: do something?
		return;
	}
	
	NSArray *entries = [response componentsSeparatedByString:@"\n"];
	NSLog(@"FTP | entries count: %d", [entries count]);
	
	if (_delegate && [_delegate respondsToSelector:@selector(ftpClient:didReceiveDirectoryListing:)]) {
		[_delegate ftpClient:self didReceiveDirectoryListing:entries];
	}
}

#pragma mark - TCPClientDelegate methods

- (void)tcpClientDidConnect:(id)client {
	if (client == _commandClient) {
		_isConnected = YES;
		
		if (_delegate && [_delegate respondsToSelector:@selector(ftpClientDidConnect:)]) {
			[_delegate ftpClientDidConnect:self];
		}
	}
}

- (void)tcpClient:(id)client didReceiveData:(NSData *)data {
//	NSLog(@"FTP | didReceiveData: %@", data);
	NSString *dataAsString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	BOOL isCommandClient = (client == _commandClient);
	NSLog(@"FTP | didReceiveData for client %@ | as string (%@)", isCommandClient ? @"Command" : @"Data", dataAsString);
	
	if (client == _commandClient) {
		NSString *response = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
		[self _handleCommandResponse:response];
		[response release];
	} else if (client == _dataClient) {
		NSLog(@"FTP | _dataClient got data of length: %d", [data length]);
		
		// i think if the data has a length of 0, that's the end and we should close the data connection
		
		// Handle data channel responses (directory listings, file downloads)
		if (_delegate && [_delegate respondsToSelector:@selector(ftpClient:didReceiveData:forFile:)]) {
			NSString *response = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
			[self _handleDataResponse:response];
			[response release];
			
			NSLog(@"FTP | sending to delegate");
			[_delegate ftpClient:self didReceiveData:data forFile:nil];
		} else {
			NSLog(@"WARNING | FTP | _dataClient didReceiveData no delegate");
		}
	}
}

- (void)tcpClient:(id)client didFailWithError:(NSError *)error {
	if (_delegate && [_delegate respondsToSelector:@selector(ftpClient:didFailWithError:)]) {
		[_delegate ftpClient:self didFailWithError:error];
	}
}

- (void)tcpClientDidDisconnect:(id)client {
	if (client == _commandClient) {
		_isConnected = NO;
		_isAuthenticated = NO;
		
		if (_delegate && [_delegate respondsToSelector:@selector(ftpClientDidDisconnect:)]) {
			[_delegate ftpClientDidDisconnect:self];
		}
	}
}

- (void)setDelegate:(id<FTPClientDelegate>)delegate {
	_delegate = delegate; // Don't retain delegate
}

@end
