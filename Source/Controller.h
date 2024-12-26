/* Controller */

#import <Cocoa/Cocoa.h>
#import "TCPClient.h"
#import "IRCClient.h"
#import "FTPClient.h"
#import "FTPBrowserController.h"
#import "NetworkStatusEnum.h"
#import "NetworkStatusController.h"

@interface Controller : NSObject <TCPClientDelegate, IRCClientDelegate, FTPClientDelegate> {
	IBOutlet NSButton *connectButton;
	
	IBOutlet NetworkStatusController *networkStatusController;
	TCPClient *_client;
	IRCClient *_ircClient;
	FTPClient *_ftpClient;
	IBOutlet FTPBrowserController *_browser;
}

#pragma mark - UI Actions
- (IBAction)onClickConnect:(id)sender;

#pragma mark - IRCClientDelegate
- (void)ircClient:(id)client didReceiveCredentials:(NSDictionary *)credentials;

#pragma mark - TCPClientDelegate
- (void)tcpClientDidConnect:(id)client;
- (void)tcpClient:(id)client didReceiveData:(NSData *)data;
- (void)tcpClient:(id)client didFailWithError:(NSError *)error;
- (void)tcpClientDidDisconnect:(id)client;

@end
