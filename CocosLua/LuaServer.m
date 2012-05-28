//
//  LuaServer.m
//  CocosLua
//
//  Created by Xiliang Chen on 12-5-17.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import "LuaServer.h"

#import "TCPServer.h"
#import "MessagePacket.h"
#import "LuaExecutor.h"
#import "LuaConsole.h"

static LuaServer *sharedServer;

@interface LuaServer () <TCPServerDelegate, NSStreamDelegate>

@property (nonatomic, retain) NSInputStream *inputStream;
@property (nonatomic, retain) NSOutputStream *outputStream;

- (void)handleData:(NSData *)data;

@end

@implementation LuaServer {
    TCPServer *_server;
}

@synthesize started = _started;
@synthesize connected = _connected;
@synthesize inputStream = _inputStream;
@synthesize outputStream = _outputStream;

+ (LuaServer *)sharedServer {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedServer = [[LuaServer alloc] init];
    });
    return sharedServer;
}

- (id)init
{
    self = [super init];
    if (self) {
        _server = [[TCPServer alloc] init];
        _server.delegate = self;
    }
    return self;
}

- (void)dealloc
{
    [self.inputStream close];
    [self.outputStream close];
    self.inputStream = nil;
    self.outputStream = nil;
    [_server stop];
    [_server release];
    
    [super dealloc];
}

#pragma mark -

- (BOOL)start {
    if (_started) {
        return YES;
    }
    _connected = NO;
    NSError *error;
    if (![_server start:&error]) {
        MWLOG(@"Failed to start TCP server with error: %@", error);
        return NO;
    }
    if (![_server enableBonjourWithDomain:nil applicationProtocol:@"_cocoslua._tcp." name:nil]) {
        MWLOG(@"Failed to enable bonjour");
        return NO;
    }
    _started = YES;
    return YES;
}

- (void)stop {
    if (!_started) {
        return;
    }
    [_server stop];
    _connected = NO;
}

#pragma mark -

- (void)handleData:(NSData *)data {
    MessagePacket *message = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    if (!message) {
        MWLOG(@"Fail to decode data: %@", data);
        return;
    }
    
    // execute message
    switch (message.type) {
        case MessageTypeNone:
            break;
        case MessageTypeString: // execute it and print result/error to console
            [[LuaConsole sharedConsole] handleInputString:message.content];
            break;
            
        case MessageTypeFile:   // save and load scripts TODO detect conflict
        {
            NSFileManager *fileManager = [NSFileManager defaultManager];
            NSArray *files = message.content;
            NSString *documentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
            for (NSArray *file in files) {
                NSData *content = [file objectAtIndex:0];
                NSString *path = [file objectAtIndex:1];
                NSDictionary *attr = [NSDictionary dictionaryWithObject:[file objectAtIndex:2] forKey:NSFileModificationDate];
                [fileManager createFileAtPath:[documentPath stringByAppendingPathComponent:path] contents:content attributes:attr];
            }
            LuaExecutor *executor = [LuaExecutor sharedExecutor];
            for (NSArray *file in files) {
                NSString *script = [[NSString alloc] initWithData:[file objectAtIndex:0] encoding:NSUTF8StringEncoding];
                [executor executeString:script];    // ignore error
            }
        }   
            break;
    }

}

#pragma mark - NSStreamDelegate

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
    switch (eventCode) {
        case NSStreamEventOpenCompleted:
            MDLOG(@"%@: connection did open", aStream);
            break;
        case NSStreamEventEndEncountered:
            MDLOG(@"%@: connection did end", aStream);
            _connected = NO;
            break;
        case NSStreamEventErrorOccurred:
            MILOG(@"%@: connection error: %@", aStream, [aStream streamError]);
            _connected = NO;
            break;
        case NSStreamEventHasBytesAvailable:
            if (aStream == _inputStream) {
                NSMutableData *data = [NSMutableData data];
                uint8_t buff[1024];
                NSInteger len = 0;
                while ([_inputStream hasBytesAvailable]) {
                    len = [_inputStream read:buff maxLength:sizeof(buff)];
                    if (len > 0) {
                        [data appendBytes:buff length:len];
                    } else if (len < 0) {
                        MWLOG(@"fail to read data with code '%d', error: %@", len, [aStream streamError]);
                        break;
                    }
                }
                if ([data length] > 0) {
                    [self handleData:data];
                }
            }
            break;
        default:
            break;
    }
}

#pragma mark - TCPServerDelegate

- (void) serverDidEnableBonjour:(TCPServer*)server withName:(NSString*)name {
    MDLOG(@"bonjour did enable with name '%@'", name);
}

- (void) server:(TCPServer*)server didNotEnableBonjour:(NSDictionary *)errorDict {
    MWLOG(@"bonjour did not enable with error: %@", errorDict);
}

- (void) didAcceptConnectionForServer:(TCPServer*)server inputStream:(NSInputStream *)istr outputStream:(NSOutputStream *)ostr {
    MDLOG(@"start connection");
    [istr open];
    [ostr open];
    [istr scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    [ostr scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    self.inputStream = istr;
    self.outputStream = ostr;
    self.inputStream.delegate = self;
    self.outputStream.delegate = self;
    _connected = YES;
}

@end
