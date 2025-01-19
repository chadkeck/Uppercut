#import <Cocoa/Cocoa.h>
#import "IRCClient.h"

@interface InitialConnectionController : NSObject {
	IBOutlet NSProgressIndicator *spinner;
	IBOutlet NSTextField *statusTextField;
	IBOutlet NSButton *connectButton;

	IRCClient *_ircClient;
}

#pragma mark - UI Actions
- (IBAction)onClickConnect:(id)sender;

#pragma mark - Private
- (void)_installObservers;
- (void)_connectToEfnet;
- (void)_handleConnectionUpdate:(NSNotification *)notification;

@end
