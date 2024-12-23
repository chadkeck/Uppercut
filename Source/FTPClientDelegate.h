@protocol FTPClientDelegate
- (void)ftpClientDidConnect:(id)client;
- (void)ftpClient:(id)client didFailWithError:(NSError *)error;
- (void)ftpClient:(id)client didReceiveData:(NSData *)data;
- (void)ftpClientDidDisconnect:(id)client;
- (void)ftpClient:(id)client didReceiveDirectoryListing:(NSArray *)listing;
- (void)ftpClient:(id)client didDownloadFile:(NSString *)filename;
@end
