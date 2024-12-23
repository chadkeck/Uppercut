#import "FTPClient.h"
#import <Foundation/NSRange.h>

// Private interface
@interface FTPClient (Private)
- (void)_sendCommand:(NSString *)command;
- (void)_parseResponse:(NSString *)response;
- (void)_setupDataConnection;
- (void)_handleResponse:(NSString *)response;
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

- (void)listDirectory:(NSString *)path {
    if (!_isAuthenticated) {
        return;
    }
    
    // Set up data connection first
    [self _setupDataConnection];
    
    // Send LIST command
    NSString *listCommand = path ? [NSString stringWithFormat:@"LIST %@", path] : @"LIST";
    [self _sendCommand:listCommand];
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
    
    NSLog(@"FTP | Sent command: %@", command);
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
		numbersString = [response substringWithRange:NSMakeRange(openPos + 1,
															 closePos - openPos - 1)];
	
		NSArray *components = [numbersString componentsSeparatedByString:@","];
		NSLog(@"FTP | PASV components: %@", components);
		if ([components count] >= 6) {
			int p1 = [[components objectAtIndex:4] intValue];
			int p2 = [[components objectAtIndex:5] intValue];
			int dataPort = (p1 * 256) + p2;
		
			// Connect data client
			[_dataClient setHost:_host];
			[_dataClient setPort:dataPort];
			[_dataClient connect];
		}
	}
}

- (void)_handleResponse:(NSString *)response {
	NSLog(@"FTP | _handleResponse %@", response);
    // Parse response code
    if ([response length] < 3) {
        return;
    }
    
    int responseCode = [[response substringToIndex:3] intValue];
    
    switch (responseCode) {
        case 220: // Service ready
            if (!_isAuthenticated && _username) {
                [self authenticate];
            }
            break;
			
        case 227:
            // Entering passive mode
            // Parse passive mode response (h1,h2,h3,h4,p1,p2)
			[self _handlePASV:response];
			break;
	
		case 331: // Username okay, need password
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
	NSLog(@"FTP | didReceiveData: %@", data);
	if (client == _commandClient) {
		NSString *response = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
		[self _handleResponse:response];
		[response release];
	} else if (client == _dataClient) {
		NSLog(@"FTP | _dataClient got data: %@", data);
		
		// i think if the data has a length of 0, that's the end and we should close the data connection
		
		// Handle data channel responses (directory listings, file downloads)
		if (_delegate && [_delegate respondsToSelector:@selector(ftpClient:didReceiveData:forFile:)]) {
			NSLog(@"FTP | sending to delegate");
			
			NSString *response = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
			NSLog(@"ooooooooooooo response: %@", response);
			[self _handleResponse:response];
			[response release];
			
			// TODO: transform data to something (string?)
			
			[_delegate ftpClient:self didReceiveData:data forFile:nil];
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
