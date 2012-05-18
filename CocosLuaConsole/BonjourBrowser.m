//
//  BonjourBrowser.m
//  CocosLua
//
//  Created by Xiliang Chen on 18/05/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "BonjourBrowser.h"

@interface BonjourBrowser () <NSNetServiceBrowserDelegate, NSNetServiceDelegate>

@property (retain) NSThread *runningThread;
@property (retain) NSDictionary *errorDict;

- (void)_start;
- (void)restart;

@end

@implementation BonjourBrowser {
    NSNetServiceBrowser *_browser;
    NSCondition *_condition;
}

@synthesize runningThread = _runningThread;
@synthesize server = _server;
@synthesize errorDict = _errorDict;

- (id)init {
    self = [super init];
    if (self) {
        _browser = [[NSNetServiceBrowser alloc] init];
        _browser.delegate = self;
        _condition = [[NSCondition alloc] init];
    }
    return self;
}

- (void)dealloc {
    [_browser stop];
    [_browser release];
    self.runningThread = nil;
    self.server = nil;
    
    [super dealloc];
}

#pragma mark -

- (void)start {
    [_browser stop];
    [_browser removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [NSThread detachNewThreadSelector:@selector(_start) toTarget:self withObject:nil];
}

- (void)_start {
    @autoreleasepool {
        self.runningThread = [NSThread currentThread];
        NSRunLoop *runloop = [NSRunLoop currentRunLoop]; // create run loop
        [_browser scheduleInRunLoop:runloop forMode:NSDefaultRunLoopMode];
        [_browser searchForServicesOfType:@"_cocoslua._tcp." inDomain:@"local."];
        for (;;) {
            [runloop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:5]];
            if (![self.runningThread isEqual:[NSThread currentThread]]) {
                return;
            }
        }
    }
}

- (void)stop {
    [_browser stop];
    self.runningThread = nil;
}

- (void)restart {
    [self stop];
    self.server = nil;
    [self performSelectorOnMainThread:@selector(start) withObject:nil waitUntilDone:NO];
}

- (BOOL)wait {
    if (self.server) {
        return YES;
    }
    [_condition lock];
    [_condition wait];
    [_condition unlock];
    if (self.server) {
        return YES;
    }
    return NO;
}

- (BOOL)waitForTimeInterview:(NSTimeInterval)time {
    if (self.server) {
        return YES;
    }
    [_condition lock];
    BOOL ret = NO;
    if ([_condition waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:time]]) {
        if (self.server) {
            ret = YES;
        }
    }
    [_condition unlock];
    return ret;
}

#pragma mark - NSNetServiceBrowserDelegate

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing {
    MDLOG(@"");
    self.runningThread = nil;
    self.server = aNetService;
    [self stop];
    [aNetService resolveWithTimeout:5];
    aNetService.delegate = self;
}

- (void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)aNetServiceBrowser {
    if (!self.server) { // did not found anything, restart
        [self restart];
    }
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didNotSearch:(NSDictionary *)errorDict {
    MILOG(@"");
    self.errorDict = errorDict;
    [self restart];
}

#pragma mark - NSNetServiceDelegate

- (void)netServiceDidResolveAddress:(NSNetService *)sender {
    MDLOG(@"");
    [_condition lock];
    [_condition broadcast];
    [_condition unlock];
}

- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary *)errorDict {
    MILOG(@"");
    self.errorDict = errorDict;
    [self restart];
}

@end
