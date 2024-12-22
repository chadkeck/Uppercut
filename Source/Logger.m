#import "Logger.h"
#import <pthread.h>

@implementation Logger

static Logger *sharedInstance = nil;

+ (Logger *)sharedInstance {
	@synchronized(self) {
		if (sharedInstance == nil) {
			sharedInstance = [[Logger alloc] init];
		}
	}
	return sharedInstance;
}

- (void)awakeFromNib {
	[[Logger sharedInstance] setLogView:textView];
	[[Logger sharedInstance] setLogPanel:logPanel];
}

- (void)setLogPanel:(NSPanel *)panel {
	logPanel = panel;
}

- (void)setLogView:(NSTextView *)view {
	textView = view;

	if (textStorage) {
		[textStorage release];
	}
	
	textStorage = [[NSTextStorage alloc] init];
	NSLayoutManager *layout = [[NSLayoutManager alloc] init];
	NSTextContainer *container = [[NSTextContainer alloc] initWithContainerSize:NSMakeSize(1e6, 1e6)];

	[textStorage addLayoutManager:layout];
	[layout addTextContainer:container];
	[container setTextView:textView];
	[layout release];
	[container release];

	NSAttributedString *emptyString = [[NSAttributedString alloc] initWithString:@""];
	[[textView textStorage] setAttributedString:emptyString];
	[emptyString release];
	
	[textView setEditable:NO];
	// enable automatic word wrapping
	[[textView textContainer] setWidthTracksTextView:YES];
	[textView setHorizontallyResizable:NO];
}

- (void)dealloc {
	[lastDate release];
	[textStorage release];
	[textView release];
	[logPanel release];
	[super dealloc];
}

- (BOOL)isMainThread {
	return pthread_main_np() == 1;
}

- (void)log:(NSString *)message {
	if (lastDate) {
		[lastDate release];
	}
	lastDate = [[NSCalendarDate alloc] init];

	NSString *timestamp = [lastDate descriptionWithCalendarFormat:@"%Y-%m-%d %H:%M:%S"];
	NSString *logMessage = [NSString stringWithFormat:@"%@ %@\n", timestamp, message];
	
	// perform UI updates on main thread
	if ([self isMainThread]) {
		[self appendLogMessage:logMessage];
	} else {
		[self performSelectorOnMainThread:@selector(appendLogMessage:)
							   withObject:logMessage
							waitUntilDone:NO];
	}
}

- (void)appendLogMessage:(NSString *)logMessage {
	[textStorage beginEditing];
	
	NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
	float defaultFontSize = -1.0;
	[attrs setObject:[NSFont userFixedPitchFontOfSize:defaultFontSize] forKey:NSFontAttributeName];
	NSAttributedString *attrString = [[NSAttributedString alloc]
										initWithString:logMessage
											attributes:attrs];
	[textStorage appendAttributedString:attrString];
	[attrString release];
	
	[textStorage endEditing];
	
	// scroll to bottom
	NSRange range = NSMakeRange([[textView string] length], 0);
	[textView scrollRangeToVisible:range];
}

- (void)clear {
	if ([self isMainThread]) {
		[[textView textStorage] setAttributedString:[[NSAttributedString alloc] initWithString:@""]];
	} else {
		[self performSelectorOnMainThread:@selector(clear)
							   withObject:nil
							waitUntilDone:NO];
	}
}

// FIXME: this will show the log panel, but won't hide it again
- (IBAction)onToggleVisible:(id)sender {
	if ([logPanel isKeyWindow]) {
		[logPanel orderBack:nil];
	} else {
		[logPanel makeKeyAndOrderFront:nil];
	}
}

@end
