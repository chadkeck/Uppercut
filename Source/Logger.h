#import <Cocoa/Cocoa.h>

@interface Logger : NSObject {
	IBOutlet NSPanel *logPanel;
	IBOutlet NSTextView *textView;
	NSTextStorage *textStorage;
	NSString *logFilePath;
	NSCalendarDate *lastDate;
}

#pragma mark - Public
+ (Logger *)sharedInstance;
- (void)log:(NSString *)message;
- (void)clear;
- (void)setLogPanel:(NSPanel *)panel;
- (void)setLogView:(NSTextView *)view;
- (void)appendLogMessage:(NSString *)logMessage;

#pragma mark - Protected
- (void)saveLog;
- (void)loadLog;

#pragma mark - UI Actions
- (IBAction)onToggleVisible:(id)sender;

@end
