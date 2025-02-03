#import <Foundation/Foundation.h>

@interface DelayedMessage : NSObject {
    NSString *message;
    id target;
}

+ (DelayedMessage *)delayedMessageWithString:(NSString *)aMessage target:(id)aTarget;
- (id)initWithString:(NSString *)aMessage target:(id)aTarget;
- (void)send;

@end
