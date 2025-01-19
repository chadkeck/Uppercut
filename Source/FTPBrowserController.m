#import "FTPBrowserController.h"
#import "FTPListParser.h"
#import "NetworkStatusEnum.h"

@interface FTPBrowserController (Private)
- (void)_loadDirectoryAtPath:(NSString *)path column:(int)column;
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
BOOL _receivedFirstDirectoryListing;
NSMutableSet *_loadingColumns; // Track which column we're loading
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
        _loadingColumns = [[NSMutableSet alloc] init];
        _downloadBuffer = [[NSMutableData alloc] init];
        _downloadFilename = nil;
        _receivedFirstDirectoryListing = NO;

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
    [_loadingColumns release];

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

    // Important: Enable action sending on selection
    [_browser setSendsActionOnArrowKeys:YES];
    [_browser setTarget:self];
    [_browser setAction:@selector(_handleBrowserAction:)];
	
	_ftpClient = [[FTPClient alloc] init];
	[_ftpClient setDelegate:self];

    // Load initial directory
    [self refresh];
}

- (void)disconnect {
	_receivedFirstDirectoryListing = NO;
	[_ftpClient disconnect];
}

- (void)_handleBrowserAction:(id)sender {
    NSLog(@"BROWSER | _handleBrowserAction");
    [self _handleSelectionInColumn:[_browser selectedColumn]];
}

- (void)_handleSelectionInColumn:(int)column {
    NSLog(@"BROWSER | _handleSelectionInColumn: %d", column);

    NSString *currentPath = [self _pathForColumn:column];
    NSArray *listing = [_directoryCache objectForKey:currentPath];

    if (!listing) {
        NSLog(@"BROWSER | No listing found for path: %@", currentPath);
        return;
    }

    int selectedRow = [_browser selectedRowInColumn:column];
    if (selectedRow < 0 || selectedRow >= [listing count]) {
        NSLog(@"BROWSER | Invalid row selected: %d", selectedRow);
        return;
    }

    NSDictionary *entry = [listing objectAtIndex:selectedRow];
    NSString *filename = [entry objectForKey:@"filename"];
    BOOL isDirectory = [[entry objectForKey:@"isDirectory"] boolValue];

    NSLog(@"BROWSER | Selected %@ (directory?: %@)", filename, isDirectory ? @"YES" : @"NO");

    // Update current path array
    while ([_currentPath count] > column + 1) {
        [_currentPath removeLastObject];
    }

    [_currentPath addObject:filename];
    NSLog(@"BROWSER | Updated path array: %@", _currentPath);

    // If directory, load next column
    if (isDirectory) {
        int nextColumn = column + 1;
        NSString *newPath = [self _pathForColumn:nextColumn];
        NSLog(@"BROWSER | Loading new directory: %@", newPath);

        // Clear cache for deeper paths
        NSEnumerator *enumerator = [_directoryCache keyEnumerator];
        NSString *key;
        NSMutableArray *keysToRemove = [NSMutableArray array];
        while ((key = [enumerator nextObject])) {
            if ([self _getColumnForPath:key] >= nextColumn) {
                [keysToRemove addObject:key];
            }
        }

        enumerator = [keysToRemove objectEnumerator];
        while ((key = [enumerator nextObject])) {
            [_directoryCache removeObjectForKey:key];
        }

        // Load the directory in the next column
        [self _loadDirectoryAtPath:newPath column:nextColumn];
    }
}

- (int)_getColumnForPath:(NSString *)path {
    if ([path isEqualToString:@"/"]) {
        return 0;
    }

    // Count slashes to determine depth, but don't count trailing slash
    NSString *cleanPath = [path hasSuffix:@"/"] ?
        [path substringToIndex:[path length] - 1] : path;

    int slashCount = 0;
    int i;
    for (i = 0; i < [cleanPath length]; i++) {
        if ([cleanPath characterAtIndex:i] == '/') {
            slashCount++;
        }
    }

    // First slash doesn't count for column number since it's the root
    return slashCount > 0 ? slashCount - 1 : 0;
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

- (void)_loadDirectoryAtPath:(NSString *)path column:(int)column {
	if ([_loadingColumns containsObject:[NSNumber numberWithInt:column]]) {
        NSLog(@"BROWSER | WARNING | Column %d already loading path %@", column, path);
        return;
    }

    NSLog(@"BROWSER | _loadDirectoryAtPath %@ for column %d", path, column);

    // Mark this column as loading
    [_loadingColumns addObject:[NSNumber numberWithInt:column]];
	NSLog(@"BROWSER | _loadDirectoryAtPath _loadingColumns: (%@)", _loadingColumns);

    // Clear cache for this path
    [_directoryCache removeObjectForKey:path];

    // Request directory listing from FTP client
    [_ftpClient listDirectory:path];
}

- (NSString *)_pathForColumn:(int)column {
    NSMutableString *path = [NSMutableString string];
    NSLog(@"BROWSER | _pathForColumn START");
    NSLog(@"  Column requested: %d", column);
    NSLog(@"  Current path array: %@", _currentPath);

    // Special case for root
    if (column == 0) {
        NSLog(@"  Returning root path /");
        return @"/";
    }

    // Build path from components
    int i;
    for (i = 0; i <= column && i < [_currentPath count]; i++) {
        NSString *component = [_currentPath objectAtIndex:i];

        // Skip empty components
        if ([component length] == 0) {
            continue;
        }

        // Skip if it's just a slash
        if ([component isEqualToString:@"/"]) {
            continue;
        }

        // Clean up component
        if ([component hasPrefix:@"/"]) {
            component = [component substringFromIndex:1];
        }
        if ([component hasSuffix:@"/"]) {
            component = [component substringToIndex:[component length] - 1];
        }

        // Add component
        if (i == 0) {
            [path appendString:@"/"];
        }

        if ([component length] > 0) {
            if (![path hasSuffix:@"/"]) {
                [path appendString:@"/"];
            }
            [path appendString:component];
        }
    }

    // Ensure path starts with /
    if (![path hasPrefix:@"/"]) {
        [path insertString:@"/" atIndex:0];
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

//    NSLog(@"BROWSER | numberOfRowsInColumn:%d | loadingColumns:%@", column, _loadingColumns);

    // If this column is loading, show one row
    if ([_loadingColumns containsObject:[NSNumber numberWithInt:column]]) {
	    NSLog(@"BROWSER | numberOfRowsInColumn:%d | will return 1 since we're loading", column);
        return 1;
    }

    // If we have a listing, return its count
    if (listing) {
		NSLog(@"BROWSER | numberOfRowsInColumn:%d | will return %d because we already have it loaded", column, [listing count]);
		NSLog(@"    path: (%@), listing: (%@)", path, listing);
        return [listing count];
    }

    // Start loading this column
	NSLog(@"BROWSER | numberOfRowsInColumn:%d | will return 1 because we need to load it");
    [self _loadDirectoryAtPath:path column:column];
    return 1;
}

- (void)browser:(NSBrowser *)sender willDisplayCell:(id)cell atRow:(int)row column:(int)column {
    NSLog(@"BROWSER | willDisplayCell at column %d and row %d", column, row);
	NSLog(@"BROWSER | willDisplayCell _loadingColumns: (%@)", _loadingColumns);
    
    // Always set default font
    NSFont *regularFont = [NSFont systemFontOfSize:12.0];
    [cell setFont:regularFont];
    
    // Show loading state if this column is loading
    if ([_loadingColumns containsObject:[NSNumber numberWithInt:column]]) {
		NSLog(@"BROWSER | willDisplayCell YEEEEEEEEEEEESSSSSSSSSSSSSSSSSSSSSSSSSSSSSS");
        [cell setStringValue:@"Loading..."];
        [cell setLeaf:YES];
        return;
    }

    NSString *path = [self _pathForColumn:column];
    NSArray *listing = [_directoryCache objectForKey:path];
    
    if (!listing || row >= [listing count]) {
        [cell setStringValue:@"Loading..."];
        [cell setLeaf:YES];
        return;
    }

    NSDictionary *entry = [listing objectAtIndex:row];
    NSString *filename = [entry objectForKey:@"filename"];
    BOOL isDirectory = [[entry objectForKey:@"isDirectory"] boolValue];
    
    if (!filename) {
        NSLog(@"WARN: Nil filename found in entry: %@", entry);
        [cell setStringValue:@"[Error]"];
        [cell setLeaf:YES];
        return;
    }

    NSLog(@"CELL | filename %@", filename);
    [cell setStringValue:filename];
    [cell setLeaf:!isDirectory];
}

- (BOOL)browser:(NSBrowser *)sender selectRow:(int)row inColumn:(int)column {
    NSLog(@"BROWSER | selectRow:%d inColumn:%d", row, column);
    NSString *path = [self _pathForColumn:column];
    NSArray *listing = [_directoryCache objectForKey:path];

    if (!listing || row >= [listing count]) {
        return NO;
    }

    // Let the browser update its selection
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

    if (!selectedItem || [selectedItem isEqualToString:@"Loading..."]) {
        return;
    }

    int selectedColumn = [_browser selectedColumn];
    NSString *currentPath = [self _pathForColumn:selectedColumn];
    NSArray *listing = [_directoryCache objectForKey:currentPath];

    // Find the selected entry in the current directory listing
    NSEnumerator *enumerator = [listing objectEnumerator];
    NSDictionary *entry;
    NSDictionary *selectedEntry = nil;
    while ((entry = [enumerator nextObject])) {
        if ([[entry objectForKey:@"filename"] isEqualToString:selectedItem]) {
            selectedEntry = entry;
            break;
        }
    }

    if (!selectedEntry) {
        NSLog(@"BROWSER | Warning: Could not find selected entry %@ in listing", selectedItem);
        return;
    }

    BOOL isDirectory = [[selectedEntry objectForKey:@"isDirectory"] boolValue];

    // Update current path array
    while ([_currentPath count] > selectedColumn + 1) {
        [_currentPath removeLastObject];
    }

    [_currentPath addObject:selectedItem];
    NSLog(@"BROWSER | Updated path array: %@", _currentPath);

    // Load the next directory if this is a directory
    if (isDirectory) {
        int nextColumn = selectedColumn + 1;
        NSString *newPath = [self _pathForColumn:nextColumn];
        NSLog(@"BROWSER | Loading directory at path: %@", newPath);

        // Clear cache for this path and all deeper paths
        NSEnumerator *keyEnumerator = [_directoryCache keyEnumerator];
        NSString *key;
        NSMutableArray *keysToRemove = [NSMutableArray array];

        while ((key = [keyEnumerator nextObject])) {
            if ([self _getColumnForPath:key] >= nextColumn) {
                [keysToRemove addObject:key];
            }
        }

        keyEnumerator = [keysToRemove objectEnumerator];
        while ((key = [keyEnumerator nextObject])) {
            [_directoryCache removeObjectForKey:key];
        }

        [self _loadDirectoryAtPath:newPath column:nextColumn];
        [_browser reloadColumn:nextColumn];
    }
}

#pragma mark - FTPClientDelegate Methods

- (void)ftpClient:(id)client didReceiveDirectoryListing:(NSArray *)entries {
    int loadingColumn = [[_loadingColumns anyObject] intValue];
    NSLog(@"BROWSER | didReceiveDirectoryListing for column %d", loadingColumn);
    NSLog(@"BROWSER | entries: %@", entries);
    
    [self _logBrowserState:@"Before adding new directory listing"];

    // Handle first listing notification
    if (!_receivedFirstDirectoryListing) {
        NSLog(@"BROWSER | Received first directory listing");
        _receivedFirstDirectoryListing = YES;

        NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithInt:[entries count]], @"entryCount",
            nil];

        [[NSNotificationCenter defaultCenter]
            postNotificationName:@"firstDirectoryListing"
            object:self
            userInfo:info];
    }

    // Convert entries into dictionaries
    NSMutableArray *listing = [NSMutableArray array];
    NSEnumerator *enumerator = [entries objectEnumerator];
    NSString *entry;
    
    while ((entry = [enumerator nextObject])) {
        NSDictionary *fileInfo = [FTPListParser dictionaryFromLine:entry];
        if (fileInfo) {
            [listing addObject:fileInfo];
        } else {
            NSLog(@"WARN | couldn't parse %@", entry);
        }
    }
    
    // Get path for loading column
    NSString *path = [self _pathForColumn:loadingColumn];
    
    // Store in cache
    [_directoryCache setObject:listing forKey:path];
    NSLog(@"BROWSER | added %d files/dirs to cache at path %@", [listing count], path);
    
    // Remove the loading state for this column
    [_loadingColumns removeObject:[NSNumber numberWithInt:loadingColumn]];
    
    // Reload the column
    [_browser reloadColumn:loadingColumn];
    
    [self _logBrowserState:@"After adding new listing"];
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
