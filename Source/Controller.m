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
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(handleFileClicked:)
												 name:@"fileClicked"
											   object:nil];
	
	// FIXME: there must be a better place to put this, like applicationDidFinishLaunching
	[[Logger sharedInstance] log:@"Uppercut started"];
}

- (void)handleFileClicked:(NSNotification *)notification {
	NSDictionary *fileInfo = [notification userInfo];
	NSLog(@"CONTROLLER | Received 'fileClicked' with %@", fileInfo);
}

- (void)dealloc {
	[_client release];
	[_ircClient release];
	[_ftpClient release];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[_browser release];
	[super dealloc];
}

- (void)ircClient:(id)client didReceiveCredentials:(NSDictionary *)credentials {
	NSLog(@"controller got ftp creds: %@", credentials);

	_ftpClient = [[FTPClient alloc] init];
	[_ftpClient setHost:[credentials objectForKey:@"host"]];
	[_ftpClient setPort:21];
	[_ftpClient setUsername:[credentials objectForKey:@"username"]];
	[_ftpClient setPassword:[credentials objectForKey:@"password"]];
	[_ftpClient connect];
	
	NSLog(@"CONTROLLER | didReceiveCredentials | _browser %@", _browser);
	
	[_browser setFTPClient:_ftpClient];
}

- (IBAction)onClickConnect:(id)sender {
    NSArray *efnetServers = [NSArray arrayWithObjects:
		@"irc.efnet.nl", // banned
		@"irc.deft.com", // banned
		@"irc.servercentral.net",
		@"irc.underworld.no",
		@"efnet.port80.se",
		@"efnet.deic.eu",
		@"irc.swepipe.se",
		@"irc.efnet.fr",
		@"irc.choopa.net",
		nil];

	int randomIndex = arc4random() % [efnetServers count];
	[_ircClient setHost:[efnetServers objectAtIndex:randomIndex]];
	[_ircClient setPort:6667];
	[_ircClient connect];
}

// TCPClientDelegate methods
- (void)tcpClientDidConnect:(id)client {
	[[Logger sharedInstance] log:@"Connected"];
	
	[connectButton setTitle:@"Disconnect"];
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
	}
	
	[message release];
}

- (void)tcpClient:(id)client didFailWithError:(NSError *)error {
	NSLog(@"Connection failed with error: %@", error);
	[[Logger sharedInstance] log:[NSString stringWithFormat:@"Connection failed with error: %@", error]];

	[connectButton setTitle:@"Connect"];
	[networkStatusController setConnectionState:NetworkStatusStateDisconnected];
}

- (void)tcpClientDidDisconnect:(id)client {
	[[Logger sharedInstance] log:@"Disconnected"];
	
	[connectButton setTitle:@"Connect"];
	[networkStatusController setConnectionState:NetworkStatusStateDisconnected];
}
@end
