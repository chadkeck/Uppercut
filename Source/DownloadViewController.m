#import "DownloadViewController.h"


@implementation DownloadViewController

- (void)awakeFromNib {
	[self reset];
}

- (void)updateDownloadState:(NSDictionary *)downloadInfo {
	NSString *filename = [downloadInfo objectForKey:@"filename"];
	NSNumber *progressNum = [downloadInfo objectForKey:@"progress"];
	double progress = [progressNum doubleValue];
	[_filenameText setStringValue:[NSString stringWithFormat:@"Downloading %@", filename]];
	[_progressBar setDoubleValue:(progress * 100.0)];
}

- (void)reset {
	[_filenameText setStringValue:@""];
	[_progressBar setMinValue:0.0];
	[_progressBar setMaxValue:1.0];
	[_progressBar setDoubleValue:0.0];
}

@end
