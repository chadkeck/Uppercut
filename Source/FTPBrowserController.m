#import "FTPBrowserController.h"
#import "FTPListParser.h"
#import "NetworkStatusEnum.h"

@interface FTPBrowserController (Private)
- (void)_loadDirectoryAtPath:(NSString *)path;
- (NSString *)_pathForColumn:(int)column;
NSMutableData *_downloadBuffer;
NSString *_downloadFilename;
NSString *_downloadPath;
NSFileHandle *_downloadFileHandle;
float _downloadProgress;
unsigned long long _currentFileSize;
unsigned long long _bytesReceived;
unsigned long _writeCount;
unsigned long _lastSyncBytes;  // Track bytes at last sync
const unsigned long SYNC_THRESHOLD = 1024 * 1024 * 10;  // Sync every 10MB
@end

@implementation FTPBrowserController

- (void)_logBrowserState:(NSString *)context {
    NSLog(@"--------------------");
    NSLog(@"Browser State (%@)", context);
    NSLog(@"Selected column: %d", [_browser selectedColumn]);
    NSLog(@"Last column: %d", [_browser lastColumn]);
    NSLog(@"Current path components: %@", _currentPath);
    NSLog(@"Cache keys: %@", [_directoryCache allKeys]);
    NSLog(@"--------------------");
}

- (void)_syncFileHandle {
    if (!_downloadFileHandle) return;

    NS_DURING
        // Force synchronous write to disk
        [_downloadFileHandle synchronizeFile];
        fsync([_downloadFileHandle fileDescriptor]);
        _lastSyncBytes = _bytesReceived;
    NS_HANDLER
        NSLog(@"Warning: Failed to sync file handle: %@", [localException reason]);
    NS_ENDHANDLER
}

- (id)init {
	NSLog(@"BROWSER | init");
    self = [super init];
    if (self) {
        _ftpClient = nil;
        _directoryCache = [[NSMutableDictionary alloc] init];
        _currentPath = [[NSMutableArray alloc] init];
        _isLoading = NO;
        _downloadBuffer = [[NSMutableData alloc] init];
        _downloadFilename = nil;

        // Add root path
        [_currentPath addObject:@"/"];
    }
    return self;
}

- (void)dealloc {
    NSLog(@"BROWSER | dealloc");
    [self _cleanupDownload];

    [_ftpClient release];
    [_directoryCache release];
    [_currentPath release];
    [_browser release];
    [_downloadBuffer release];

    [super dealloc];
}

- (void)awakeFromNib {
	NSLog(@"BROWSER | awakeFromNib");
    // Configure browser
	[_browser retain];
    [_browser setDelegate:self];
    [_browser setMaxVisibleColumns:3];
    [_browser setAllowsMultipleSelection:NO];
    [_browser setAllowsEmptySelection:NO];
    [_browser setHasHorizontalScroller:YES];
    [_browser setDoubleAction:@selector(handleDoubleClick:)];
	
	_ftpClient = [[FTPClient alloc] init];
	[_ftpClient setDelegate:self];

    // Load initial directory
    [self refresh];
}

- (void)connectToFTP:(NSString *)host withUsername:(NSString *)username password:(NSString *)password {
	[_ftpClient setHost:host];
	[_ftpClient setPort:21];
	[_ftpClient setUsername:username];
	[_ftpClient setPassword:password];
	[_ftpClient connect];
}

- (void)refresh {
    // Clear cache and reload
    [_directoryCache removeAllObjects];
    [_currentPath removeAllObjects];
    [_currentPath addObject:@"/"];

    NSLog(@"BROWSER | refresh | _browser %@", _browser);
    [_browser loadColumnZero];
}

- (void)setDownloadDirectory:(NSString *)directory {
	if (_downloadDirectory != directory) {
		[directory retain];
		[_downloadDirectory release];
		_downloadDirectory = directory;
	}
	
}

- (void)cancelCurrentDownload {
	NSLog(@"BROWSER | cancelling current download");
	
	// cancel the FTP transfer
	[_ftpClient abortTransfer];
	
    // We'll clean up the download when we receive the abort confirmation
}

- (void)_cleanupDownload {
    NS_DURING
        if (_downloadFileHandle != nil) {
            // Sync any remaining data
            [self _syncFileHandle];

            // Close file handle
            [_downloadFileHandle closeFile];
            [_downloadFileHandle release];
            _downloadFileHandle = nil;

            // If download was cancelled, delete partial file
            if (_downloadPath) {
                NSFileManager *fileManager = [NSFileManager defaultManager];
                [fileManager removeFileAtPath:_downloadPath handler:nil];
            }
        }

        [_downloadPath release];
        _downloadPath = nil;
        [_downloadFilename release];
        _downloadFilename = nil;

        _downloadProgress = 0.0;
        _currentFileSize = 0;
        _bytesReceived = 0;
        _writeCount = 0;
        _lastSyncBytes = 0;
    NS_HANDLER
        NSLog(@"Error cleaning up download: %@", [localException reason]);
    NS_ENDHANDLER
}

#pragma mark - Private Methods

- (void)_loadDirectoryAtPath:(NSString *)path {
    if (_isLoading) {
		NSLog(@"BROWSER | WARNING | _loadDirectoryAtPath(%@) already loading", path);
        return;
    }
    
    _isLoading = YES;
	
	NSLog(@"BROWSER | _loadDirectoryAtPath %@", path);
    
    // Check cache first
    NSArray *cachedListing = [_directoryCache objectForKey:path];
    if (cachedListing) {
		NSLog(@"BROWSER | _loadDirectoryAtPath | CACHE HIT %@", path);
        _isLoading = NO;
        return;
    }
    
    // Request directory listing from FTP client
    [_ftpClient listDirectory:path];
}

- (NSString *)_pathForColumn:(int)column {
    NSMutableString *path = [NSMutableString string];
    NSLog(@"BROWSER | _pathForColumn START");
    NSLog(@"  Column requested: %d", column);
    NSLog(@"  Current path array: %@", _currentPath);

    // Always start with root
    [path appendString:@"/"];

    // Don't include the root slash from _currentPath if it's there
    int startIndex = [[_currentPath objectAtIndex:0] isEqualToString:@"/"] ? 1 : 0;

    // Only process up to the requested column
    int endIndex = column + 1;
    if (endIndex > [_currentPath count]) {
        endIndex = [_currentPath count];
    }

    NSLog(@"  Processing components from index %d to %d", startIndex, endIndex);

    int i;
    for (i = startIndex; i < endIndex; i++) {
        NSString *component = [_currentPath objectAtIndex:i];

        // Skip empty components
        if ([component length] == 0) {
            continue;
        }

        // Skip if it's just a slash
        if ([component isEqualToString:@"/"]) {
            continue;
        }

        // Remove leading slash from component if present
        if ([component hasPrefix:@"/"]) {
            component = [component substringFromIndex:1];
        }

        // Add component with leading slash if needed
        if (![path hasSuffix:@"/"]) {
            [path appendString:@"/"];
        }
        [path appendString:component];
    }

    NSLog(@"  Final path: %@", path);
    NSLog(@"BROWSER | _pathForColumn END");
    return path;
}

- (void)ftpClient:(id)client didReceiveFileSize:(unsigned long long)size forFile:(NSString *)filename {
    [_downloadFilename release];
    _downloadFilename = [[filename lastPathComponent] retain];

    _currentFileSize = size;
    _bytesReceived = 0;
    _writeCount = 0;
    _lastSyncBytes = 0;
    _downloadProgress = 0.0;

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *basePath = [_downloadDirectory stringByAppendingPathComponent:_downloadFilename];
    _downloadPath = [basePath retain];

    // Handle existing files by appending number
    int counter = 1;
    while ([fileManager fileExistsAtPath:_downloadPath]) {
        NSString *newName = [NSString stringWithFormat:@"%@_%d%@",
            [[_downloadFilename stringByDeletingPathExtension] retain],
            counter,
            [[_downloadFilename pathExtension] length] > 0 ?
                [NSString stringWithFormat:@".%@", [_downloadFilename pathExtension]] : @""];
        [_downloadPath release];
        _downloadPath = [[_downloadDirectory stringByAppendingPathComponent:newName] retain];
        counter++;
    }

    NSLog(@"FTP | Creating file at path: %@", _downloadPath);

    // Create empty file
    if (![fileManager createFileAtPath:_downloadPath contents:[NSData data] attributes:nil]) {
        NSLog(@"ERROR: Failed to create file at %@", _downloadPath);
        [self _cleanupDownload];
        return;
    }

    // Open file handle for writing
    _downloadFileHandle = [[NSFileHandle fileHandleForWritingAtPath:_downloadPath] retain];
    if (!_downloadFileHandle) {
        NSLog(@"ERROR: Could not open file handle for writing at %@", _downloadPath);
        [self _cleanupDownload];
        return;
    }

    // Format size for display
    NSString *sizeString;
    if (size < 1024) {
        sizeString = [NSString stringWithFormat:@"%llu bytes", size];
    } else if (size < 1024 * 1024) {
        sizeString = [NSString stringWithFormat:@"%.1f KB", size / 1024.0];
    } else {
        sizeString = [NSString stringWithFormat:@"%.1f MB", size / (1024.0 * 1024.0)];
    }
	
	// Notify the download is starting
    NSDictionary *startInfo = [NSDictionary dictionaryWithObjectsAndKeys:
        _downloadFilename, @"filename",
        sizeString, @"size",
        nil];

    [[NSNotificationCenter defaultCenter] postNotificationName:@"downloadStarted"
                                                    object:self
                                                    userInfo:startInfo];

    // Then send initial progress update
    NSDictionary *progressInfo = [NSDictionary dictionaryWithObjectsAndKeys:
        _downloadFilename, @"filename",
        sizeString, @"size",
        [NSNumber numberWithFloat:0.0], @"progress",
        nil];

    [[NSNotificationCenter defaultCenter] postNotificationName:@"downloadProgress"
                                                    object:self
                                                    userInfo:progressInfo];
}

- (void)ftpClient:(id)client didUpdateProgress:(double)progress bytesReceived:(unsigned long long)bytesReceived forFile:(NSString *)filename {
//	NSLog(@"BROWSER | didUpdateProgress | progress %.2f%% | forFile (%@):", progress * 100.0, filename);
	
	_downloadProgress = progress;

    // Calculate the amount downloaded
    NSString *progressString;

    if (bytesReceived < 1024ULL) {
        progressString = [NSString stringWithFormat:@"%llu bytes", bytesReceived];
    } else if (bytesReceived < 1024ULL * 1024ULL) {
		double kb = (double)bytesReceived / 1024.0;
        progressString = [NSString stringWithFormat:@"%.1f KB", kb];
    } else {
		double mb = (double)bytesReceived / (1024.0 * 1024.0);
        progressString = [NSString stringWithFormat:@"%.1f MB", mb];
    }

    // Update the interface with progress
    NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
        [_downloadFilename lastPathComponent], @"filename",
        progressString, @"downloaded",
        [NSNumber numberWithFloat:progress], @"progress",
        nil];

    //NSLog(@"BROWSER | didUpdateProgress | progressString %@, info (%@)", progressString, info);

    [[NSNotificationCenter defaultCenter] postNotificationName:@"downloadProgress"
                                                      object:self
                                                    userInfo:info];
}

- (void)ftpClient:(id)client didReceiveData:(NSData *)data forFile:(NSString *)filename {
     if (!filename || !_downloadFileHandle) {
        return;
    }

    NS_DURING
        // Write data chunk to file
        [_downloadFileHandle writeData:data];
        _writeCount++;

        // Update progress tracking
        _bytesReceived += [data length];
        if (_currentFileSize > 0) {
            _downloadProgress = (double)_bytesReceived / (double)_currentFileSize;
        }

        // Check if enough new data has accumulated since last sync
        if (_bytesReceived - _lastSyncBytes >= SYNC_THRESHOLD) {
            [self _syncFileHandle];
        }

        // Check if this is the end of transfer (data length 0)
        if ([data length] == 0) {
            // Final sync to ensure all data is written
            [self _syncFileHandle];

            // Close file handle and notify success
            [_downloadFileHandle closeFile];
            [_downloadFileHandle release];
            _downloadFileHandle = nil;

            NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
                _downloadPath, @"path",
                _downloadFilename, @"filename",
                nil];

            [[NSNotificationCenter defaultCenter] postNotificationName:@"fileDownloaded"
                                                            object:self
                                                            userInfo:info];

            [self _cleanupDownload];
        }
    NS_HANDLER
        NSLog(@"Error writing to file: %@", [localException reason]);
        [self _cleanupDownload];

        NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
            [NSString stringWithFormat:@"Error writing file: %@", [localException reason]], @"error",
            _downloadFilename, @"filename",
            nil];

        [[NSNotificationCenter defaultCenter] postNotificationName:@"fileDownloadError"
                                                        object:self
                                                        userInfo:info];
    NS_ENDHANDLER
}

- (void)ftpClientDidConnect:(id)client {
	NSLog(@"BROWSER | ftpClientDidConnect");
	
	NSNumber *numState = [NSNumber numberWithInt:NetworkStatusStateConnected];
	NSDictionary *connectionInfo = [NSDictionary dictionaryWithObjectsAndKeys:
		@"FTP Connected", @"update",
		numState, @"state",
		nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"connectionUpdate"
													object:self
												  userInfo:connectionInfo];
}
- (void)ftpClientDidDisconnect:(id)client {
	NSLog(@"BROWSER | ftpClientDidDisconnect");
	
	NSNumber *numState = [NSNumber numberWithInt:NetworkStatusStateDisconnected];
	NSDictionary *connectionInfo = [NSDictionary dictionaryWithObjectsAndKeys:
		@"FTP Disconnected", @"update",
		numState, @"state",
		nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"connectionUpdate"
													object:self
												  userInfo:connectionInfo];
}

- (void)ftpClientDidAuthenticate:(id)client {
	NSLog(@"BROWSER | ftpClientDidAuthenticate");
	[_ftpClient listDirectory:@""];
}

- (void)ftpClientDidAbortTransfer:(id)client {
    NSLog(@"BROWSER | FTP transfer aborted by server");

    // Now we can safely clean up
    [self _cleanupDownload];

    // Notify UI that download was cancelled
    NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
        @"Download cancelled", @"status",
        _downloadFilename, @"filename",
        nil];

    [[NSNotificationCenter defaultCenter] postNotificationName:@"downloadCancelled"
                                                      object:self
                                                    userInfo:info];
}

#pragma mark - NSBrowser Delegate Methods

- (int)browser:(NSBrowser *)sender numberOfRowsInColumn:(int)column {
    NSString *path = [self _pathForColumn:column];
    NSArray *listing = [_directoryCache objectForKey:path];

    // Clear this column and higher columns when loading new data
    if (!listing) {
        // If we're already loading this path, don't request it again
        if (!_isLoading) {
            NSEnumerator *enumerator = [_directoryCache keyEnumerator];
            NSString *key;
            NSMutableArray *keysToRemove = [NSMutableArray array];

            while ((key = [enumerator nextObject])) {
                if ([self _getColumnForPath:key] >= column) {
                    [keysToRemove addObject:key];
                }
            }

            enumerator = [keysToRemove objectEnumerator];
            while ((key = [enumerator nextObject])) {
                [_directoryCache removeObjectForKey:key];
            }

            // Request new directory listing
            [self _loadDirectoryAtPath:path];
        }
        return 1;  // Always show exactly one "Loading..." row
    }

    return [listing count];
}

- (int)_getColumnForPath:(NSString *)path {
    if ([path isEqualToString:@"/"]) {
        return 0;
    }

    NSArray *components = [path componentsSeparatedByString:@"/"];
    // Subtract 1 because the first component will be empty (path starts with /)
    int count = [components count] - 1;
    return count > 0 ? count : 0;
}

- (void)browser:(NSBrowser *)sender willDisplayCell:(id)cell atRow:(int)row column:(int)column {
    NSLog(@"BROWSER | willDisplayCell at row %d and column %d", row, column);
    NSString *path = [self _pathForColumn:column];
    NSArray *listing = [_directoryCache objectForKey:path];

    // Always set a default font first
    NSFont *regularFont = [NSFont systemFontOfSize:12.0];
    [cell setFont:regularFont];

    if (!listing) {
        // Show loading state
        [cell setStringValue:@"Loading..."];
        [cell setLeaf:YES];
        return;
    }

    if (row < [listing count]) {
        NSDictionary *entry = [listing objectAtIndex:row];
        NSString *filename = [entry objectForKey:@"filename"];

        // Guard against nil filename
        if (filename == nil) {
            NSLog(@"WARN: Nil filename found in entry: %@", entry);
            [cell setStringValue:@"[Error]"];
            [cell setLeaf:YES];
            return;
        }

        BOOL isDirectory = [[entry objectForKey:@"isDirectory"] boolValue];

        NSLog(@"CELL | filename %@", filename);
        [cell setStringValue:filename];
        [cell setLeaf:!isDirectory];
    }
}

- (BOOL)browser:(NSBrowser *)sender selectRow:(int)row inColumn:(int)column {
    NSString *path = [self _pathForColumn:column];
    NSArray *listing = [_directoryCache objectForKey:path];
	
	[self _logBrowserState:@"Before selection"];

    if (!listing || row >= [listing count]) {
        return NO;
    }

    NSDictionary *entry = [listing objectAtIndex:row];
    BOOL isDirectory = [[entry objectForKey:@"isDirectory"] boolValue];

    // Update the path
    NSString *name = [entry objectForKey:@"name"];

    // Update current path array
    while ([_currentPath count] > column + 1) {
        [_currentPath removeLastObject];
    }
    [_currentPath addObject:name];

    // If this is a directory, preload the next column
    if (isDirectory) {
        NSString *newPath = [self _pathForColumn:column + 1];
        [self _loadDirectoryAtPath:newPath];
    }

    return YES;
}

- (NSString *)browser:(NSBrowser *)sender titleOfColumn:(int)column {
    if (column == 0) {
        return @"Root";
    }

    if (column < [_currentPath count]) {
        return [_currentPath objectAtIndex:column - 1];
    }

    return @"[unknown]";
}

- (BOOL)browser:(NSBrowser *)sender isColumnValid:(int)column {
    NSString *path = [self _pathForColumn:column];
    return [_directoryCache objectForKey:path] != nil;
}

id findEntryWithFilename(NSArray *array, NSString *filename) {
    NSEnumerator *enumerator = [array objectEnumerator];
    id entry;
	   
    while ((entry = [enumerator nextObject])) {
		if ([[entry valueForKey:@"filename"] isEqualToString:filename]) {
			return entry;
		}
	}
	return nil;
}

- (void)handleDoubleClick:(id)sender {
    NSLog(@"BROWSER | handleDoubleClick");

    NSString *path = [self _pathForColumn:[_browser selectedColumn]];
    NSString *selectedItem = [[_browser selectedCell] stringValue];

    if (selectedItem && [selectedItem isEqualToString:@"Loading..."]) return;

    // Only handle file downloads on double-click
    if ([[_browser selectedCell] isLeaf]) {
        NSString *fullPath = [NSString stringWithFormat:@"%@/%@", path, selectedItem];
        [_ftpClient downloadFile:fullPath];

/*
		NSArray *entries = [_directoryCache objectForKey:path];
		NSDictionary *entry = findEntryWithFilename(entries, selectedItem);

		[[NSNotificationCenter defaultCenter] postNotificationName:@"fileClicked"
															object:self
														  userInfo:entry];
*/
    }
}

- (void)browserSelectionDidChange:(id)sender {
    NSString *selectedItem = [[_browser selectedCell] stringValue];
    NSLog(@"BROWSER | browserSelectionDidChange | selectedItem %@", selectedItem);

    if (selectedItem && [selectedItem isEqualToString:@"Loading..."]) return;

    int selectedColumn = [_browser selectedColumn];
    int nextColumn = selectedColumn + 1;

    // Only proceed if we're not in a loading state
    if (![selectedItem isEqualToString:@"Loading..."]) {
        // Update current path
        while ([_currentPath count] > nextColumn) {
            NSLog(@"BROWSER | removing last object from (%@)", _currentPath);
            [_currentPath removeLastObject];
        }

        if (selectedItem) {  // Only add if we have a valid selection
            NSLog(@"BROWSER | adding object to _currentPath (%@)", selectedItem);
            [_currentPath addObject:selectedItem];

            // Load the next directory if this is a directory
            if (![[_browser selectedCell] isLeaf]) {
                NSString *newPath = [self _pathForColumn:nextColumn];
                [self _loadDirectoryAtPath:newPath];

                // Clear any cached data for higher columns
                NSEnumerator *enumerator = [_directoryCache keyEnumerator];
                NSString *key;
                NSMutableArray *keysToRemove = [NSMutableArray array];

                while ((key = [enumerator nextObject])) {
                    if ([self _getColumnForPath:key] > selectedColumn) {
                        [keysToRemove addObject:key];
                    }
                }

                enumerator = [keysToRemove objectEnumerator];
                while ((key = [enumerator nextObject])) {
                    [_directoryCache removeObjectForKey:key];
                }

                // Force browser to reload the next column
                [_browser reloadColumn:nextColumn];
            }
        }
    }
}

#pragma mark - FTPClientDelegate Methods

- (void)ftpClient:(id)client didReceiveDirectoryListing:(NSArray *)entries {
	NSLog(@"BROWSER | didReceiveDirectoryListing: %@", entries);
	
	[self _logBrowserState:@"Before adding new directory listing"];
	
    // Convert entries into dictionaries with name and isDirectory
    NSMutableArray *listing = [NSMutableArray array];
    NSEnumerator *enumerator = [entries objectEnumerator];
    NSString *entry;
    
    while ((entry = [enumerator nextObject])) {
//            // Skip . and .. entries
//            if ([name isEqualToString:@"."] || [name isEqualToString:@".."]) {
//                continue;
//            }
		
		NSDictionary *fileInfo = [FTPListParser dictionaryFromLine:entry];
		if (fileInfo) {
//			NSLog(@"BROWSER | didReceiveDirectoryListing: parsed fileInfo %@", fileInfo);
			[listing addObject:fileInfo];
		} else {
			NSLog(@"WARN | couldn't parse %@", entry);
		}
		
    }
	NSLog(@"BROWSER | listing %@", listing);
    
    // Store in cache
    NSString *path = [self _pathForColumn:[_browser selectedColumn]+1];
    [_directoryCache setObject:listing forKey:path];
	
	NSLog(@"BROWSER | added %d files/dirs to cache at path %@", [listing count], path);
	
//	NSLog(@"BROWSER | _directoryCache %@", _directoryCache);
    
    _isLoading = NO;
    
    // Reload the browser column
//	NSLog(@"BROWSER | reloadColumn %d", [_browser selectedColumn]);
	[_browser reloadColumn:[_browser lastColumn]];
//    [_browser reloadColumn:[_browser selectedColumn]+1];


	
	[self _logBrowserState:@"After adding new"];
}

- (void)ftpClient:(id)client didFailWithError:(NSError *)error {
	NSLog(@"BROWSER | fptClient didFailWithError %@", error);
	
    _isLoading = NO;
    
    // Show error in browser
	// FIXME: should maybe use the column method we defined here, not matrixInColumn
    NSBrowserCell *cell = [[_browser matrixInColumn:[_browser selectedColumn]] cellAtRow:0 column:0];
    [cell setStringValue:@"Error loading directory"];
    [cell setLeaf:YES];
}

@end
