/* Controller */

#import <Cocoa/Cocoa.h>
#import "IRCClient.h"
#import "FTPClient.h"
#import "FTPBrowserController.h"
#import "NetworkStatusEnum.h"
#import "NetworkStatusController.h"

@interface Controller : NSObject <TCPClientDelegate, IRCClientDelegate, FTPClientDelegate> {
	IBOutlet NSButton *connectButton;
	
	IBOutlet NetworkStatusController *networkStatusController;
	IRCClient *_ircClient;
	FTPClient *_ftpClient;
	IBOutlet FTPBrowserController *_browser;
}

#pragma mark - UI Actions
- (IBAction)onClickConnect:(id)sender;

#pragma mark - IRCClientDelegate
- (void)ircClient:(id)client didReceiveCredentials:(NSDictionary *)credentials;

@end
