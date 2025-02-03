#import "DelayedMessage.h"

@implementation DelayedMessage

+ (DelayedMessage *)delayedMessageWithString:(NSString *)aMessage target:(id)aTarget {
    return [[[DelayedMessage alloc] initWithString:aMessage target:aTarget] autorelease];
}

- (id)initWithString:(NSString *)aMessage target:(id)aTarget {
    self = [super init];
    if (self) {
        message = [aMessage copy];
        target = [aTarget retain];
    }
    return self;
}

- (void)dealloc {
    [message release];
    [target release];
    [super dealloc];
}

- (void)send {
    // Call _sendMessage: on the target (IRCClient)
    [target _sendMessage:message];
}

@end
