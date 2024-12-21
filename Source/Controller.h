/* Controller */

#import <Cocoa/Cocoa.h>
#import "TCPClient.h"
#import "NetworkStatusEnum.h"
#import "NetworkStatusController.h"

@interface Controller : NSObject {
	IBOutlet NSTextField *hostField;
	IBOutlet NSTextField *portField;
	IBOutlet NSButton *connectButton;
	IBOutlet NetworkStatusController *networkStatusController;
	TCPClient *_client;
}

#pragma mark - UI Actions
- (IBAction)onClick:(id)sender;

#pragma mark - TCPClientDelegate
- (void)tcpClientDidConnect:(id)client;
- (void)tcpClient:(id)client didReceiveData:(NSData *)data;
- (void)tcpClient:(id)client didFailWithError:(NSError *)error;
- (void)tcpClientDidDisconnect:(id)client;

@end
