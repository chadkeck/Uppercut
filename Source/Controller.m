#import "Controller.h"

@implementation Controller

NSString *kTabFTP = @"FTP";
NSString *kTabConnection = @"Connection";

- (void)awakeFromNib {
	_isConnected = NO;
	[cancelDownloadButton setEnabled:NO];
	
	[self _setDefaultDownloadDirectory];
	[self _installObservers];

	[tabView selectTabViewItemWithIdentifier:kTabConnection];
}

- (void)_setDefaultDownloadDirectory {
	// default downloads to user's "Downloads" directory
	NSString *homeDirectory = NSHomeDirectory();
	NSString *downloadsPath = [homeDirectory stringByAppendingPathComponent:@"Downloads"];
	[self _setDownloadDirectory:downloadsPath];
}

- (void)_installObservers {
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(handleFileClicked:)
												 name:@"fileClicked"
											   object:nil];
											   
	[[NSNotificationCenter defaultCenter] addObserver:self
											selector:@selector(handleConnectionUpdate:)
												name:@"connectionUpdate"
											  object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(handleFTPCredentialsReceived:)
												 name:@"ftpCredentialsReceived"
											   object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											selector:@selector(_handleFirstDirectoryListing:)
												name:@"firstDirectoryListing"
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
}

- (IBAction)onClickCancelDownload:(id)sender {
	NSLog(@"CONTROLLER | cancel download clicked");
	[_browser cancelCurrentDownload];
	[cancelDownloadButton setEnabled:NO];
}

- (void)_handleFirstDirectoryListing:(NSNotification *)notification {
	NSDictionary *connectionInfo = [notification userInfo];
	NSLog(@"CONTROLLER | Received 'firstDirectoryListing' with %@", connectionInfo);
	[tabView selectTabViewItemWithIdentifier:kTabFTP];
//	[_browser performSelector:@selector(loadColumnZero) withObject:nil afterDelay:5.0];
}

- (void)handleConnectionUpdate:(NSNotification *)notification {
	NSDictionary *connectionInfo = [notification userInfo];
	NSLog(@"CONTROLLER | Received 'connectionUpdate' with %@", connectionInfo);
	NSNumber *numState = [connectionInfo objectForKey:@"state"];
	NetworkStatusState state = [numState intValue];
	[networkStatusController setConnectionState:state];
	
	if (state == NetworkStatusStateDisconnected) {
		_isConnected = NO;
//		[connectButton setTitle:@"Connect"];
	} else if (state == NetworkStatusStateConnected) {
		_isConnected = YES;
//		[connectButton setTitle:@"Disconnect"];
	}
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

// TODO can hook into the user clicking on a file here
- (void)handleFileClicked:(NSNotification *)notification {
	NSDictionary *fileInfo = [notification userInfo];
	NSLog(@"CONTROLLER | Received 'fileClicked' with %@", fileInfo);
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[_browser release];
    [_openPanel release];
	[super dealloc];
}

- (void)handleFTPCredentialsReceived:(NSNotification *)notification {
	NSDictionary *credentials = [notification userInfo];
	NSLog(@"CONTROLLER | handleFTPCredentialsReceived | credentials: (%@)", credentials);

	NSString *host = [credentials objectForKey:@"host"];
	NSLog(@"host %@", host);
	NSString *username = [credentials objectForKey:@"username"];
	NSLog(@"username %@", username);
	NSString *password = [credentials objectForKey:@"password"];
	NSLog(@"password %@", password);
	[_browser connectToFTP:host withUsername:username password:password];

	[networkStatusController setConnectionState:NetworkStatusStateWaiting];
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




@end
