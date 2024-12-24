#import <Foundation/Foundation.h>

@interface FTPListParser : NSObject {
    NSString *rawLine;
}

// Initialize with a line from FTP LIST command
- (id)initWithLine:(NSString *)line;

// Parse the current line and return a dictionary with file information
- (NSDictionary *)parseEntry;

// Class method for convenience
+ (NSDictionary *)dictionaryFromLine:(NSString *)line;

@end
