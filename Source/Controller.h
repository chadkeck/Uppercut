/* Controller */

#import <Cocoa/Cocoa.h>
#import "TCPClient.h"
#import "IRCClient.h"
#import "FTPClient.h"
#import "NetworkStatusEnum.h"
#import "NetworkStatusController.h"

@interface Controller : NSObject <TCPClientDelegate, IRCClientDelegate, FTPClientDelegate> {
	IBOutlet NSTextField *hostField;
	IBOutlet NSTextField *portField;
	IBOutlet NSButton *connectButton;
	
	IBOutlet NSTextField *sendDataTextField;
	IBOutlet NSButton *sendDataButton;
	IBOutlet NSTextView *dataTextView;
	
	IBOutlet NetworkStatusController *networkStatusController;
	TCPClient *_client;
	IRCClient *_ircClient;
	FTPClient *_ftpClient;
}

#pragma mark - UI Actions
- (IBAction)onClickConnect:(id)sender;
- (IBAction)onClickSendData:(id)sender;

#pragma mark - IRCClientDelegate
- (void)ircClient:(id)client didReceiveCredentials:(NSDictionary *)credentials;

#pragma mark - TCPClientDelegate
- (void)tcpClientDidConnect:(id)client;
- (void)tcpClient:(id)client didReceiveData:(NSData *)data;
- (void)tcpClient:(id)client didFailWithError:(NSError *)error;
- (void)tcpClientDidDisconnect:(id)client;

#pragma mark - FTPClientDelegate
- (void)ftpClient:(id)client didReceiveDirectoryListing:(NSArray *)entries;
- (void)ftpClient:(id)client didReceiveData:(NSData *)data forFile:(NSString *)filename;
- (void)ftpClient:(id)client didFailWithError:(NSError *)error;
- (void)ftpClientDidConnect:(id)client;
- (void)ftpClientDidDisconnect:(id)client;
- (void)ftpClientDidAuthenticate:(id)client;


@end
