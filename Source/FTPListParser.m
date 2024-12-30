#import "FTPListParser.h"

@implementation FTPListParser

- (id)initWithLine:(NSString *)line {
    self = [super init];
    if (self) {
        rawLine = [line retain];
    }
    return self;
}

- (void)dealloc {
    [rawLine release];
    [super dealloc];
}

+ (NSDictionary *)dictionaryFromLine:(NSString *)line {
    FTPListParser *parser = [[[FTPListParser alloc] initWithLine:line] autorelease];
    return [parser parseEntry];
}

- (NSDictionary *)parseEntry {
    if (!rawLine || ![rawLine length]) {
		NSLog(@"PARSER | BAIL");
        return nil;
    }

    NSMutableDictionary *entry = [NSMutableDictionary dictionary];

    // Parse permissions and type
    if ([rawLine length] >= 10) {
        NSString *perms = [rawLine substringToIndex:10];
        [entry setObject:perms forKey:@"permissions"];

        // Check if it's a directory (first char is 'd')
        BOOL isDir = ([perms characterAtIndex:0] == 'd');
        [entry setObject:[NSNumber numberWithBool:isDir] forKey:@"isDirectory"];
    }

    // Use NSScanner for parsing space-separated components
    NSScanner *scanner = [NSScanner scannerWithString:rawLine];
    [scanner setScanLocation:11]; // Skip permissions

    int linkCount;
    [scanner scanInt:&linkCount];
    [entry setObject:[NSNumber numberWithInt:linkCount] forKey:@"linkCount"];

    // Skip owner and group
    NSString *dummy;
    [scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&dummy];
    [scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&dummy];

    // Scan file size
	long long fileSize;
    if ([scanner scanLongLong:&fileSize]) {
        [entry setObject:[NSNumber numberWithUnsignedLongLong:fileSize] forKey:@"fileSize"];
    }

	// Parse date (format: MMM DD HH:MM, like "Dec 23 04:33")
    NSString *month;
    int day;
    NSString *time;

    // Scan the month (three letters)
    [scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&month];

    // Scan the day
    [scanner scanInt:&day];

    // Scan the time
    [scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&time];

    // Convert month string to month number (1-12)
    NSArray *months = [NSArray arrayWithObjects:
        @"Jan", @"Feb", @"Mar", @"Apr", @"May", @"Jun",
        @"Jul", @"Aug", @"Sep", @"Oct", @"Nov", @"Dec", nil];
    int monthNum = [months indexOfObject:[month substringToIndex:3]] + 1;

    // Parse hour and minute from time string (format: HH:MM)
    int hour = [[time substringToIndex:2] intValue];
    int minute = [[time substringFromIndex:3] intValue];

    // Create NSCalendarDate for the current year since FTP listing doesn't include year
    NSCalendarDate *now = [NSCalendarDate calendarDate];
    NSCalendarDate *modDate = [NSCalendarDate dateWithYear:[now yearOfCommonEra]
                                                    month:monthNum
                                                      day:day
                                                     hour:hour
                                                   minute:minute
                                                   second:0
                                                 timeZone:[NSTimeZone defaultTimeZone]];

    // If the resulting date is in the future, it's probably from last year
    if ([modDate timeIntervalSinceNow] > 0) {
        modDate = [NSCalendarDate dateWithYear:[now yearOfCommonEra] - 1
                                       month:monthNum
                                         day:day
                                        hour:hour
                                      minute:minute
                                      second:0
                                    timeZone:[NSTimeZone defaultTimeZone]];
    }

    [entry setObject:modDate forKey:@"modificationDate"];

    // Everything after this is the filename
    NSString *filename;
    [scanner scanUpToString:@"\n" intoString:&filename];
    if ([filename length]) {
        // Trim leading whitespace
        filename = [filename stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        [entry setObject:filename forKey:@"filename"];
//		NSLog("PARSER | filename %@", filename);
    }
//	NSLog("PARSER | entry %@", entry);

    return entry;
}

@end

