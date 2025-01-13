#import <Cocoa/Cocoa.h>

@interface Logger : NSObject {
	IBOutlet NSPanel *logPanel;
	IBOutlet NSTextView *textView;
	NSTextStorage *textStorage;
	NSString *logFilePath;
	NSCalendarDate *lastDate;
}

+ (Logger *)sharedInstance;

- (void)setLogPanel:(NSPanel *)panel;
- (void)setLogView:(NSTextView *)view;
- (void)log:(NSString *)message;
- (void)appendLogMessage:(NSString *)logMessage;
- (void)clear;
- (void)saveLog;
- (void)loadLog;
- (IBAction)onToggleVisible:(id)sender;

@end
