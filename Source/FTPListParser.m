#import "FTPListParser.h"

@implementation FTPListParser 

/* Instance variable to store the raw FTP listing line */
NSString *rawLine;

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

/* Class convenience method to parse a single line */
+ (NSDictionary *)dictionaryFromLine:(NSString *)line {
    FTPListParser *parser = [[[FTPListParser alloc] initWithLine:line] autorelease];
    return [parser parseEntry];
}

/* Helper method to identify numeric strings */
- (BOOL)isStringNumeric:(NSString *)str {
    if (!str || ![str length]) {
        return NO;
    }
    NSCharacterSet *nonDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    return [str rangeOfCharacterFromSet:nonDigits].location == NSNotFound;
}

/* Helper method to create newline character set */
- (NSCharacterSet *)newlineCharacterSet {
    return [NSCharacterSet characterSetWithCharactersInString:@"\n\r"];
}

/* Main parsing method */
- (NSDictionary *)parseEntry {
    // Input validation
    if (!rawLine || ![rawLine length]) {
        NSLog(@"FTPListParser: Empty or nil input line");
        return nil;
    }
    
    // Check minimum length for a valid FTP listing
    if ([rawLine length] < 10) {
        NSLog(@"FTPListParser: Line too short to be valid FTP listing: %@", rawLine);
        return nil;
    }

    NSMutableDictionary *entry = [NSMutableDictionary dictionary];
    
    // Parse permissions and type (first 10 chars)
    NSString *perms = [rawLine substringToIndex:10];
    [entry setObject:perms forKey:@"permissions"];
    
    // Check if directory (first char is 'd')
    BOOL isDir = ([perms characterAtIndex:0] == 'd');
    [entry setObject:[NSNumber numberWithBool:isDir] forKey:@"isDirectory"];

    // Create scanner starting after permissions
    NSScanner *scanner = [NSScanner scannerWithString:rawLine];
    [scanner setCharactersToBeSkipped:[NSCharacterSet whitespaceCharacterSet]];
    
    // Skip past permissions
    if ([scanner scanLocation] < 10) {
        [scanner setScanLocation:10];
    }

    // Parse link count - skip if can't find a number
    int linkCount = 1; // Default value
    if ([scanner scanInt:&linkCount]) {
        [entry setObject:[NSNumber numberWithInt:linkCount] forKey:@"linkCount"];
    }

    // Parse owner and group - handle both text and numeric formats
    NSString *owner = nil;
    NSString *group = nil;
    
    // Try to scan owner and group, but don't fail if we can't
    [scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] 
                           intoString:&owner];
    [scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] 
                           intoString:&group];
                           
    if (owner) {
        if ([self isStringNumeric:owner]) {
            [entry setObject:[NSNumber numberWithInt:[owner intValue]] 
                     forKey:@"ownerID"];
        } else {
            [entry setObject:owner forKey:@"owner"];
        }
    }
    
    if (group) {
        if ([self isStringNumeric:group]) {
            [entry setObject:[NSNumber numberWithInt:[group intValue]] 
                     forKey:@"groupID"];
        } else {
            [entry setObject:group forKey:@"group"];
        }
    }

    // Parse file size - use default if we can't find it
    long long fileSize = 0;
    if ([scanner scanLongLong:&fileSize]) {
        [entry setObject:[NSNumber numberWithLongLong:fileSize] 
                 forKey:@"fileSize"];
    }

    // Parse date components with error checking
    NSString *month = nil;
    int day = 1;
    NSString *timeOrYear = nil;
    
    if (![scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] 
                                intoString:&month]) {
        NSLog(@"FTPListParser: Failed to parse month");
        return entry;
    }
    
    if (![scanner scanInt:&day]) {
        NSLog(@"FTPListParser: Failed to parse day");
        return entry;
    }
    
    if (![scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] 
                                intoString:&timeOrYear]) {
        NSLog(@"FTPListParser: Failed to parse time/year");
        return entry;
    }

    // Convert month string to number (1-12)
    NSArray *months = [NSArray arrayWithObjects:
        @"Jan", @"Feb", @"Mar", @"Apr", @"May", @"Jun",
        @"Jul", @"Aug", @"Sep", @"Oct", @"Nov", @"Dec", nil];
        
    // Make sure we have at least 3 characters for month
    if ([month length] < 3) {
        NSLog(@"FTPListParser: Month string too short: %@", month);
        return entry;
    }
    
    NSString *monthPrefix = [month substringToIndex:3];
    unsigned monthIndex = [months indexOfObject:monthPrefix];
    if (monthIndex == NSNotFound) {
        NSLog(@"FTPListParser: Invalid month: %@", month);
        return entry;
    }
    int monthNum = monthIndex + 1; // Convert from 0-based to 1-based

    NSCalendarDate *modDate = nil;
    
    // Check if we have a year or time
    if ([timeOrYear rangeOfString:@":"].location != NSNotFound) {
        // We have a time (HH:MM) - use current year
        if ([timeOrYear length] < 5) { // Need at least H:MM
            NSLog(@"FTPListParser: Invalid time format: %@", timeOrYear);
            return entry;
        }
        
        int hour = [[timeOrYear substringToIndex:2] intValue];
        int minute = [[timeOrYear substringFromIndex:3] intValue];
        
        NSCalendarDate *now = [NSCalendarDate calendarDate];
        modDate = [NSCalendarDate dateWithYear:[now yearOfCommonEra]
                                       month:monthNum
                                         day:day
                                        hour:hour
                                      minute:minute
                                      second:0
                                    timeZone:[NSTimeZone defaultTimeZone]];
                                    
        // If date is in future, subtract a year
        if ([modDate timeIntervalSinceNow] > 0) {
            modDate = [NSCalendarDate dateWithYear:[now yearOfCommonEra] - 1
                                           month:monthNum
                                             day:day
                                            hour:hour
                                          minute:minute
                                          second:0
                                        timeZone:[NSTimeZone defaultTimeZone]];
        }
    } else {
        // We have a year - use 00:00 for time
        int year = [timeOrYear intValue];
        if (year == 0) {
            NSLog(@"FTPListParser: Invalid year: %@", timeOrYear);
            return entry;
        }
        
        modDate = [NSCalendarDate dateWithYear:year
                                       month:monthNum
                                         day:day
                                        hour:0
                                      minute:0
                                      second:0
                                    timeZone:[NSTimeZone defaultTimeZone]];
    }
    
    if (modDate) {
        [entry setObject:modDate forKey:@"modificationDate"];
    }

    // Everything remaining is the filename (may contain spaces)
    NSMutableString *filename = [NSMutableString string];
    NSString *component;
    
    // Create custom newline character set for older OS X versions
    NSCharacterSet *newlines = [self newlineCharacterSet];
    
    while ([scanner scanUpToCharactersFromSet:newlines intoString:&component]) {
        if ([filename length] > 0) {
            [filename appendString:@" "];
        }
        [filename appendString:component];
    }

    if ([filename length] > 0) {
        // Trim any remaining whitespace
        NSString *trimmed = [filename stringByTrimmingCharactersInSet:
                            [NSCharacterSet whitespaceCharacterSet]];
        [entry setObject:trimmed forKey:@"filename"];
    }

    return entry;
}

@end
