/* Controller */

#import <Cocoa/Cocoa.h>
#import "FTPClient.h"
#import "FTPBrowserController.h"
#import "NetworkStatusEnum.h"
#import "NetworkStatusController.h"
#import "DownloadViewController.h"

@interface Controller : NSObject {
	IBOutlet NSTabView *tabView;
	BOOL _isConnected; // to IRC, FTP, or both

	// Connected/FTP pane
	IBOutlet NSTextField *downloadDirectoryTextField;
	IBOutlet NSButton *cancelDownloadButton;
	IBOutlet NSButton *disconnectButton;
	IBOutlet NetworkStatusController *networkStatusController;
	IBOutlet DownloadViewController *downloadViewController;
	IBOutlet FTPBrowserController *_browser;
    NSOpenPanel *_openPanel; // For setting download directory
}

#pragma mark - UI Actions
- (IBAction)onClickDisconnect:(id)sender;
- (IBAction)onClickSaveTo:(id)sender;
- (IBAction)onClickCancelDownload:(id)sender;

#pragma mark - private
- (void)_setDefaultDownloadDirectory;
- (void)_installObservers;
- (void)_setDownloadDirectory:(NSString *)directory;
- (void)_openPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;

@end
