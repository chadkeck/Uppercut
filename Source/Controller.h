/* Controller */

#import <Cocoa/Cocoa.h>
#import "IRCClient.h"
#import "FTPClient.h"
#import "FTPBrowserController.h"
#import "NetworkStatusEnum.h"
#import "NetworkStatusController.h"
#import "DownloadViewController.h"

@interface Controller : NSObject <TCPClientDelegate, IRCClientDelegate, FTPClientDelegate> {
	IBOutlet NSTextField *downloadDirectoryTextField;
	IBOutlet NSButton *cancelDownloadButton;

	IBOutlet NetworkStatusController *networkStatusController;
	IBOutlet DownloadViewController *downloadViewController;
	IRCClient *_ircClient;
	FTPClient *_ftpClient;
	IBOutlet FTPBrowserController *_browser;
    NSPanel *_openPanel;
}

#pragma mark - UI Actions
- (IBAction)onClickConnect:(id)sender;
- (IBAction)onClickSaveTo:(id)sender;
- (IBAction)onClickCancelDownload:(id)sender;

#pragma mark - IRCClientDelegate
- (void)ircClient:(id)client didReceiveCredentials:(NSDictionary *)credentials;

#pragma mark - private
- (void)_setDownloadDirectory:(NSString *)directory;
- (void)_openPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;


@end
