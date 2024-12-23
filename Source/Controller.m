#import "Controller.h"
#import "Logger.h"

@implementation Controller

- (void)awakeFromNib {
	_client = [[TCPClient alloc] init];
	[_client setDelegate:self];
	[_client setHost:@"localhost"];
	[_client setPort:1234];
	
	_ircClient = [[IRCClient alloc] init];
	[_ircClient setDelegate:self];
	
	_ftpClient = nil;
	
	// FIXME: there must be a better place to put this, like applicationDidFinishLaunching
	[[Logger sharedInstance] log:@"Uppercut started"];
}

- (void)dealloc {
	[_client release];
	[_ircClient release];
	[_ftpClient release];
	[super dealloc];
}

- (void)ircClient:(id)client didReceiveCredentials:(NSDictionary *)credentials {
	NSLog(@"controller got ftp creds: %@", credentials);

	_ftpClient = [[FTPClient alloc]
		initWithHostname:[credentials objectForKey:@"host"]
		port:21
		username:[credentials objectForKey:@"username"]
		password:[credentials objectForKey:@"password"]
		mode:FTPModeActive];
	[_ftpClient setDelegate:self];
	[_ftpClient connect];
}

- (void)ftpClientDidConnect:(id)client {
	NSLog(@"controller | ftpClientDidConnect");
}
- (void)ftpClient:(id)client didFailWithError:(NSError *)error {
	NSLog(@"controller | ftpClient didFailWithError %@", error);
}
- (void)ftpClient:(id)client didReceiveData:(NSData *)data {
	NSLog(@"controller | ftpClient didReceiveData %@", data);
}
- (void)ftpClientDidDisconnect:(id)client {
	NSLog(@"controller | ftpClientDidDisconnect");
}
- (void)ftpClient:(id)client didReceiveDirectoryListing:(NSArray *)listing {
	NSLog(@"controller | ftpClient didReceiveDirectoryListing %@", listing);
}
- (void)ftpClient:(id)client didDownloadFile:(NSString *)filename {
	NSLog(@"controller | ftpClient didDownloadFile %@", filename);
}


- (IBAction)onClickConnect:(id)sender {
//	[_ircClient setHost:@"irc.efnet.nl"]; // banned
//	[_ircClient setHost:@"irc.deft.com"]; // banned
//	[_ircClient setHost:@"irc.servercentral.net"];
//	[_ircClient setHost:@"irc.underworld.no"];
	[_ircClient setHost:@"efnet.port80.se"];
//	[_ircClient setHost:@"efnet.deic.eu"];
//	[_ircClient setHost:@"irc.efnet.nl"];
//	[_ircClient setHost:@"irc.swepipe.se"];
//	[_ircClient setHost:@"irc.efnet.fr"];
//	[_ircClient setHost:@"irc.choopa.net"];

	[_ircClient setPort:6667];
	[_ircClient connect];




	return;


	NSString *host = [hostField stringValue];
	int port = [portField intValue];
	
	// TODO: some validation on host and port
	
	[_client setHost:[hostField stringValue]];
	[_client setPort:[portField intValue]];
	
	if (![_client isConnected]) {
		[[Logger sharedInstance] log:[NSString stringWithFormat:@"Connecting to %@:%d", host, port]];

		[_client connect];
		[networkStatusController setConnectionState:NetworkStatusStateWaiting];
	} else {
		[_client disconnect];
	}
}

- (IBAction)onClickSendData:(id)sender {
	NSLog(@"send data clicked");
	
	if (![_client isConnected]) {
		return;
	}
		
	// send data
	NSString *message = [[sendDataTextField stringValue] stringByAppendingString:@"\r\n"];
	NSData *data = [message dataUsingEncoding:NSUTF8StringEncoding];
	[_client sendData:data];
	
	[[Logger sharedInstance] log:[NSString stringWithFormat:@"Sent message: %@", message]];
	
	// clear the input field
	[sendDataTextField setStringValue:@""];
}

// TCPClientDelegate methods
- (void)tcpClientDidConnect:(id)client {
	[[Logger sharedInstance] log:@"Connected"];
	
	[connectButton setTitle:@"Disconnect"];
	[hostField setEnabled:FALSE];
	[portField setEnabled:FALSE];
	[networkStatusController setConnectionState:NetworkStatusStateConnected];

}

- (void)tcpClient:(id)client didReceiveData:(NSData *)data {
	NSString *message = [[NSString alloc] initWithData:data 
											  encoding:NSUTF8StringEncoding];

	// check for disconnect
	if ([data length] == 0) {
		[self tcpClientDidDisconnect:client];
	} else {
		[[Logger sharedInstance] log:[NSString stringWithFormat:@"Received message: %@", message]];
	
		[dataTextView setString:message];
	}
	
	[message release];
}

- (void)tcpClient:(id)client didFailWithError:(NSError *)error {
	NSLog(@"Connection failed with error: %@", error);
	[[Logger sharedInstance] log:[NSString stringWithFormat:@"Connection failed with error: %@", error]];

	[connectButton setTitle:@"Connect"];
	[hostField setEnabled:TRUE];
	[portField setEnabled:TRUE];
	[networkStatusController setConnectionState:NetworkStatusStateDisconnected];
}

- (void)tcpClientDidDisconnect:(id)client {
	[[Logger sharedInstance] log:@"Disconnected"];
	
	[connectButton setTitle:@"Connect"];
	[hostField setEnabled:TRUE];
	[portField setEnabled:TRUE];
	[networkStatusController setConnectionState:NetworkStatusStateDisconnected];
}
@end
