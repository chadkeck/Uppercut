@protocol IRCClientDelegate
- (void)ircClient:(id)client didReceiveCredentials:(NSDictionary *)credentials;
@end