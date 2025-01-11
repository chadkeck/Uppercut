#import "Controller.h"
#import "Logger.h"

@implementation Controller

- (void)awakeFromNib {
	_ircClient = [[IRCClient alloc] init];
	[_ircClient setDelegate:self];
	
	_ftpClient = nil;
	
	[cancelDownloadButton setEnabled:NO];
	
	// default downloads to user's "Downloads" directory
	NSString *homeDirectory = NSHomeDirectory();
	NSString *downloadsPath = [homeDirectory stringByAppendingPathComponent:@"Downloads"];
	[self _setDownloadDirectory:downloadsPath];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(handleFileClicked:)
												 name:@"fileClicked"
											   object:nil];
											   
	[[NSNotificationCenter defaultCenter] addObserver:self
											selector:@selector(handleConnectionUpdate:)
												name:@"connectionUpdate"
											  object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											selector:@selector(handleDownloadProgress:)
												name:@"downloadProgress"
											  object:nil];
						
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(handleDownloadSucceeded:)
												 name:@"fileDownloaded"
											   object:nil];
											   
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(handleDownloadStarted:)
												 name:@"downloadStarted"
											   object:nil];
											   
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(handleDownloadCancelled:)
												 name:@"downloadCancelled"
											   object:nil];
	
	// FIXME: there must be a better place to put this, like applicationDidFinishLaunching
	[[Logger sharedInstance] log:@"Uppercut started"];
}

- (IBAction)onClickCancelDownload:(id)sender {
	NSLog(@"CONTROLLER | cancel download clicked");
	[_browser cancelCurrentDownload];
	[cancelDownloadButton setEnabled:NO];
}

- (void)handleConnectionUpdate:(NSNotification *)notification {
	NSDictionary *connectionInfo = [notification userInfo];
	NSLog(@"CONTROLLER | Received 'connectionUpdate' with %@", connectionInfo);
	NSNumber *numState = [connectionInfo objectForKey:@"state"];
	NetworkStatusState state = [numState intValue];
	[networkStatusController setConnectionState:state];
}

- (void)handleDownloadStarted:(NSNotification *)notification {
	[cancelDownloadButton setEnabled:YES];
}

- (void)handleDownloadProgress:(NSNotification *)notification {
	NSDictionary *downloadInfo = [notification userInfo];
//	NSLog(@"CONTROLLER | Received 'downloadProgress' with %@", downloadInfo);
	[downloadViewController updateDownloadState:downloadInfo];
}

- (void)handleDownloadSucceeded:(NSNotification *)notification {
	NSDictionary *downloadInfo = [notification userInfo];
	NSLog(@"CONTROLLER | Received 'fileDownloaded' with %@", downloadInfo);
	[cancelDownloadButton setEnabled:NO];
	[downloadViewController reset];
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

- (IBAction)onClickSaveTo:(id)sender {
	NSLog(@"onClickSaveTo");
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	[openPanel setCanChooseDirectories:YES];
	[openPanel setCanChooseFiles:NO];
	[openPanel setAllowsMultipleSelection:NO];
	[openPanel setPrompt:@"Select Directory"];
	
	int result = [openPanel runModal];
	if (result == NSOKButton) {
		NSURL *url = [openPanel URL];
		[self _setDownloadDirectory:[url path]];
	}
}

- (void)_setDownloadDirectory:(NSString *)directory {
	NSString *directoryName = [directory lastPathComponent];
	NSLog(@"Selected directory: %@ | directoryName: %@", directory, directoryName);

	// TODO: check if directory is writable?

	[downloadDirectoryTextField setStringValue:directoryName];
	[_browser setDownloadDirectory:directory];
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
