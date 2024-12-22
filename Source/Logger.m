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

- (id)init {
	if (self = [super init]) {
		lastDate = [[NSCalendarDate alloc] init];
		textStorage = nil;

		// Set up log file path in Application Support
		NSArray *paths = NSSearchPathForDirectoriesInDomains(
				NSApplicationSupportDirectory, NSUserDomainMask, YES);
		NSString *appSupport = [paths objectAtIndex:0];
		NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
		NSString *logDir = [appSupport stringByAppendingPathComponent:bundleID];

		// Create directory if it doesn't exist
		[[NSFileManager defaultManager] createDirectoryAtPath:logDir
												   attributes:nil];

		logFilePath = [[logDir stringByAppendingPathComponent:@"application.log"] retain];

		// Register for app termination notification
		[[NSNotificationCenter defaultCenter]
			addObserver:self
			   selector:@selector(applicationWillTerminate:)
				   name:NSApplicationWillTerminateNotification
				 object:nil];
	}
	return self;
}

- (void)dealloc {
	[lastDate release];
	[textStorage release];
	[textView release];
	[logPanel release];
	[logFilePath release];
	[super dealloc];
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
	
	[self loadLog];
	
	[textView setEditable:NO];
	// enable automatic word wrapping
	[[textView textContainer] setWidthTracksTextView:YES];
	[textView setHorizontallyResizable:NO];
}

- (BOOL)isMainThread {
	return pthread_main_np() == 1;
}

- (NSString *)escapeString:(NSString *)input {
	if (!input) return nil;

	NSMutableString *output = [NSMutableString stringWithString:input];

	// Define replacements
	NSDictionary *replacements = [NSDictionary dictionaryWithObjectsAndKeys:
		@"\\n", @"\n",
		@"\\r", @"\r",
		@"\\t", @"\t",
		@"\\\\", @"\\",
		nil];

	// Perform replacements
	NSEnumerator *enumerator = [replacements keyEnumerator];
	NSString *character;
	while ((character = [enumerator nextObject])) {
		[output replaceOccurrencesOfString:character
								withString:[replacements objectForKey:character]
								   options:NSLiteralSearch
									 range:NSMakeRange(0, [output length])];
	}

	return output;
}

- (void)log:(NSString *)message {
	if (lastDate) {
		[lastDate release];
	}
	lastDate = [[NSCalendarDate alloc] init];

	NSString *timestamp = [lastDate descriptionWithCalendarFormat:@"%Y-%m-%d %H:%M:%S"];
	NSString *escapedMessage = [self escapeString:message];
	NSString *logMessage = [NSString stringWithFormat:@"%@ %@\n", timestamp, escapedMessage];

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

- (void)loadLog {
	if (!textStorage) {
		NSLog(@"Unable to load log. Error 1");
		return;
	}

	NSString *existingLog = [NSString stringWithContentsOfFile:logFilePath];
	if (existingLog) {
		NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
		float defaultFontSize = -1.0;
		[attrs setObject:[NSFont userFixedPitchFontOfSize:defaultFontSize] forKey:NSFontAttributeName];
		NSAttributedString *attrString = [[NSAttributedString alloc]
									initWithString:existingLog
										attributes:attrs];
		[textStorage setAttributedString:attrString];
		[attrString release];

		// Scroll to bottom of loaded content
		if (textView) {
			NSRange range = NSMakeRange([textStorage length], 0);
			[textView scrollRangeToVisible:range];
		}
	}
}

- (void)saveLog {
	if (!textStorage) return;

	NSString *logContent = [textStorage string];
	NSLog(@"Saving log of length: %d to %@", [logContent length], logFilePath);
	[logContent writeToFile:logFilePath atomically:YES];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
	[self saveLog];
}

@end
