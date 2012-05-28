//
//  FileManager.m
//  CocosLua
//
//  Created by Xiliang Chen on 12-5-27.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import "FileManager.h"

#import "SCEvents.h"
#import "LuaClient.h"
#import "MessagePacket.h"

@interface FileManager () <SCEventListenerProtocol>

- (void)eventThread;
- (void)scanDirectroy;
- (void)sendFiles:(NSArray *)files;

@end

@implementation FileManager {
    SCEvents *_watcher;
    BOOL _sync;
    LuaClient *_client;
    NSThread *_eventThread;
    NSMutableDictionary *_fileInfoDict;
}

@synthesize workingDirectroy = _workingDirectroy;

+ (FileManager *)sharedManager {
    static FileManager *sharedManager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[FileManager alloc] init];
    });
    return sharedManager;
}

- (id)init
{
    self = [super init];
    if (self) {
        _fileInfoDict = [[NSMutableDictionary alloc] init];
        _watcher = [[SCEvents alloc] init];
        [_watcher setDelegate:self];
        self.workingDirectroy = [[NSUserDefaults standardUserDefaults] stringForKey:@"WorkingDirectroy"];
        _eventThread = [[NSThread alloc] initWithTarget:self selector:@selector(eventThread) object:nil];
        [_eventThread start];
    }
    return self;
}

- (void)eventThread {
    @autoreleasepool {
        NSRunLoop *runloop = [NSRunLoop currentRunLoop];
        [runloop addPort:[NSMachPort port] forMode:NSDefaultRunLoopMode];
        BOOL running = YES;
        while (![_eventThread isCancelled] && running) {
            @autoreleasepool {
                running = [runloop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:5]];
            }
        }
    }
}

- (void)dealloc
{
    [_eventThread cancel];
    self.workingDirectroy = nil;
    [_watcher release];
    [_eventThread release];
    [_fileInfoDict release];
    
    [super dealloc];
}

#pragma mark -

- (void)setWorkingDirectroy:(NSString *)workingDirectroy {
    [_workingDirectroy autorelease];
    _workingDirectroy = [workingDirectroy copy];
    [[NSUserDefaults standardUserDefaults] setObject:_workingDirectroy forKey:@"WorkingDirectroy"];
    
    [_watcher stopWatchingPaths];
    if (_sync && workingDirectroy) {
        BOOL directory = NO;
        if ([[NSFileManager defaultManager] fileExistsAtPath:_workingDirectroy isDirectory:&directory]) {
            if (directory) {
                [_watcher performSelector:@selector(startWatchingPaths:) onThread:_eventThread withObject:[NSArray arrayWithObject:workingDirectroy] waitUntilDone:NO];
                [self performSelector:@selector(scanDirectroy) onThread:_eventThread withObject:nil waitUntilDone:NO];
                return;
            }
        }
        [_workingDirectroy release];
        _workingDirectroy = nil;
    }
}

- (void)start:(LuaClient *)client {
    _client = client;
    _sync = YES;
    self.workingDirectroy = _workingDirectroy;  // enable watcher
}

- (void)stop {
    _client = nil;
    _sync = NO;
    [_watcher stopWatchingPaths];
}

#pragma mark -

- (void)scanDirectroy { // TODO handle remove file
    NSMutableArray *filesToSend = [[NSMutableArray alloc] init];
    NSDirectoryEnumerator *dirEnum = [[NSFileManager defaultManager] enumeratorAtPath:_workingDirectroy];
    NSString *file;
    while (file = [dirEnum nextObject]) {
        if ([file characterAtIndex:0] == '.') {
            [dirEnum skipDescendants];
            continue;
        }
        if ([[file pathExtension] isEqualToString: @"lua"]) {   // only process .lua file
            NSDate *modifcationDate = [[dirEnum fileAttributes] valueForKey:NSFileModificationDate];
            NSDate *lastDate = [_fileInfoDict objectForKey:file];
            if (![modifcationDate isEqualToDate:lastDate]) {
                [_fileInfoDict setObject:modifcationDate forKey:file];
                [filesToSend addObject:file];
            }
        }
    }
    [self sendFiles:filesToSend];
    [filesToSend release];
}

- (void)sendFiles:(NSArray *)files {    // TODO perform syntax checking before sending file
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:[files count]];
    for (NSString *file in files) {
        NSString *content = [NSData dataWithContentsOfFile:[_workingDirectroy stringByAppendingPathComponent:file]];
        [array addObject:[NSArray arrayWithObjects:content, file, [_fileInfoDict objectForKey:file], nil]];
    }
    [_client sendPacket:[MessagePacket packetWithType:MessageTypeFile content:array]];
}

#pragma mark - SCEventListenerProtocol

- (void)pathWatcherEventsOccurred:(SCEvents *)pathWatcher {
    [self scanDirectroy];
}

@end
