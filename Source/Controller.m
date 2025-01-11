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
    [_openPanel release];
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
    NSLog(@"CONTROLLER | onClickSaveTo: Opening directory selection sheet");

    // Create and configure the open panel
    _openPanel = [[NSOpenPanel openPanel] retain];
    [_openPanel setCanChooseDirectories:YES];
    [_openPanel setCanChooseFiles:NO];
    [_openPanel setAllowsMultipleSelection:NO];
    [_openPanel setPrompt:@"Select Directory"];

    // Begin the sheet attached to our window
    // First find our window through any of our outlets
    NSWindow *window = [downloadDirectoryTextField window];

    NSLog(@"CONTROLLER | onClickSaveTo: Beginning sheet for window %@", window);

    // Note: In 10.4, we use beginSheetForDirectory:file:types:modalForWindow:modalDelegate:
    // didEndSelector:contextInfo: instead of the newer beginSheetModalForWindow: methods
    [_openPanel beginSheetForDirectory:nil
                                file:nil
                               types:nil
                      modalForWindow:window
                       modalDelegate:self
                      didEndSelector:@selector(_openPanelDidEnd:returnCode:contextInfo:)
                         contextInfo:NULL];
}

- (void)_openPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
    NSLog(@"CONTROLLER | _openPanelDidEnd: Panel closed with return code %d", returnCode);

    if (returnCode == NSOKButton) {
        // Get the selected directory path
        NSString *selectedPath = [[sheet filenames] objectAtIndex:0];
        [self _setDownloadDirectory:selectedPath];
    }

    // Clean up by releasing the panel
    [_openPanel release];
    _openPanel = nil;
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
