/* Controller */

#import <Cocoa/Cocoa.h>
#import "TcpClient.h"

@interface Controller : NSObject {
	IBOutlet NSTextField *textField;
	TcpClient *_client;
}

- (IBAction)onClick:(id)sender;
@end
