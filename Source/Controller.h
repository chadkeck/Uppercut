/* Controller */

#import <Cocoa/Cocoa.h>
#import "TcpClient.h"
#import "NetworkStatusEnum.h"

@interface Controller : NSObject {
	IBOutlet NSTextField *hostField;
	IBOutlet NSTextField *portField;
	IBOutlet NSButton *connectButton;
	IBOutlet NSTextField *connectionStatusTextField;
	IBOutlet NSImageView *connectionStatusImageView;
	TcpClient *_client;
}

#pragma mark - UI Actions
- (IBAction)onClick:(id)sender;

#pragma mark - Connection Status
- (void)setConnectionLightState:(NetworkStatusState)state;

#pragma mark - TcpClientDelegate
- (void)tcpClientDidConnect:(id)client;
- (void)tcpClient:(id)client didReceiveData:(NSData *)data;
- (void)tcpClient:(id)client didFailWithError:(NSError *)error;
- (void)tcpClientDidDisconnect:(id)client;

@end
