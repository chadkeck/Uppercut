/* Controller */

#import <Cocoa/Cocoa.h>
#import "TcpClient.h"

typedef enum {
	TrafficLightStateRed,
	TrafficLightStateGreen,
	TrafficLightStateOrange,
	TrafficLightStateGray
} TrafficLightState;

@interface Controller : NSObject {
	IBOutlet NSTextField *hostField;
	IBOutlet NSTextField *portField;
	IBOutlet NSButton *connectButton;
	IBOutlet NSTextField *connectionStatusTextField;
	IBOutlet NSImageView *connectionStatusImageView;
	TcpClient *_client;
}

- (IBAction)onClick:(id)sender;
- (void)setConnectionLightState:(TrafficLightState)state;
@end
