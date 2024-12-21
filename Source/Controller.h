/* Controller */

#import <Cocoa/Cocoa.h>
#import "TcpClient.h"

@interface Controller : NSObject {
	IBOutlet NSTextField *textField;
	IBOutlet NSTextField *hostField;
	IBOutlet NSTextField *portField;
	IBOutlet NSButton *connectButton;
	TcpClient *_client;
}

- (IBAction)onClick:(id)sender;
@end
