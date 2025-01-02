@protocol FTPClientDelegate
- (void)ftpClient:(id)client didReceiveDirectoryListing:(NSArray *)entries;
- (void)ftpClient:(id)client didReceiveData:(NSData *)data forFile:(NSString *)filename;
- (void)ftpClient:(id)client didUpdateProgress:(double)progress bytesReceived:(unsigned long long)bytesReceived forFile:(NSString *)filename;
- (void)ftpClient:(id)client didReceiveFileSize:(unsigned long long)size forFile:(NSString *)filename;
- (void)ftpClient:(id)client didFailWithError:(NSError *)error;
- (void)ftpClientDidConnect:(id)client;
- (void)ftpClientDidDisconnect:(id)client;
- (void)ftpClientDidAuthenticate:(id)client;
@end
