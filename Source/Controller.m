#import "Controller.h"
#import "Logger.h"

@implementation Controller

- (void)awakeFromNib {
	_ircClient = [[IRCClient alloc] init];
	[_ircClient setDelegate:self];
	
	_ftpClient = nil;
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(handleFileClicked:)
												 name:@"fileClicked"
											   object:nil];
											   
	[[NSNotificationCenter defaultCenter] addObserver:self
											selector:@selector(handleConnectionUpdate:)
												name:@"connectionUpdate"
											  object:nil];
	
	// FIXME: there must be a better place to put this, like applicationDidFinishLaunching
	[[Logger sharedInstance] log:@"Uppercut started"];
}

- (void)handleConnectionUpdate:(NSNotification *)notification {
	NSDictionary *connectionInfo = [notification userInfo];
	NSLog(@"CONTROLLER | Received 'connectionUpdate' with %@", connectionInfo);
	NSNumber *numState = [connectionInfo objectForKey:@"state"];
	NetworkStatusState state = [numState intValue];
	[networkStatusController setConnectionState:state];
}

- (void)handleFileClicked:(NSNotification *)notification {
	NSDictionary *fileInfo = [notification userInfo];
	NSLog(@"CONTROLLER | Received 'fileClicked' with %@", fileInfo);
}

- (void)dealloc {
	[_ircClient release];
	[_ftpClient release];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[_browser release];
	[super dealloc];
}

- (void)ircClient:(id)client didReceiveCredentials:(NSDictionary *)credentials {
	NSLog(@"CONTROLLER | didReceiveCredentials | credentials: (%@)", credentials);

	// this is kind of wonky that we have the _ftpClient here instead of wrapping
	// all of it inside the FTPBrowserController
	_ftpClient = [[FTPClient alloc] init];
	[_ftpClient setHost:[credentials objectForKey:@"host"]];
	[_ftpClient setPort:21];
	[_ftpClient setUsername:[credentials objectForKey:@"username"]];
	[_ftpClient setPassword:[credentials objectForKey:@"password"]];
	[_ftpClient connect];
	
	[networkStatusController setConnectionState:NetworkStatusStateWaiting];
	
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

@end
