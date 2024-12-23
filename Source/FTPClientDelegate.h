@protocol FTPClientDelegate
- (void)ftpClient:(id)client didReceiveDirectoryListing:(NSArray *)entries;
- (void)ftpClient:(id)client didReceiveData:(NSData *)data forFile:(NSString *)filename;
- (void)ftpClient:(id)client didFailWithError:(NSError *)error;
- (void)ftpClientDidConnect:(id)client;
- (void)ftpClientDidDisconnect:(id)client;
- (void)ftpClientDidAuthenticate:(id)client;
@end
