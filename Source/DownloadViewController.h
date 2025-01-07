#import <Cocoa/Cocoa.h>

@interface DownloadViewController : NSObject {
	IBOutlet NSTextField *_filenameText;
	IBOutlet NSProgressIndicator *_progressBar;
}

- (void)reset;
- (void)updateDownloadState:(NSDictionary *)downloadInfo;

@end