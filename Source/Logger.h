#import <Cocoa/Cocoa.h>

@interface Logger : NSObject {
	IBOutlet NSPanel *logPanel;
	IBOutlet NSTextView *textView;
	NSTextStorage *textStorage;
	NSCalendarDate *lastDate;
}

+ (Logger *)sharedInstance;

- (void)setLogPanel:(NSPanel *)panel;
- (void)setLogView:(NSTextView *)view;
- (void)log:(NSString *)message;
- (void)clear;
- (IBAction)onToggleVisible:(id)sender;

@end
