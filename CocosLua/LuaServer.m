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
    NSError *error;
    if (![_server start:&error]) {
        MWLOG(@"Failed to start TCP server with error: %@", error);
        return NO;
    }
    if (![_server enableBonjourWithDomain:nil applicationProtocol:@"CocosLua" name:nil]) {
        MWLOG(@"Failed to enable bonjour");
        return NO;
    }
    return YES;
}

- (void)stop {
    if (!_started) {
        return;
    }
    [_server stop];
}

- (void)handleData:(NSData *)data {
    MessagePacket *message = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    if (!message) {
        MWLOG(@"Fail to decode data: %@", data);
    }
    [message execute];
}

#pragma mark - NSStreamDelegate

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
    switch (eventCode) {
        case NSStreamEventOpenCompleted:
            MDLOG(@"%@: connection did open", aStream);
            break;
        case NSStreamEventEndEncountered:
            MDLOG(@"%@: connection did end", aStream);
            break;
        case NSStreamEventErrorOccurred:
            MILOG(@"%@: connection error: %@", aStream, [aStream streamError]);
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
            MILOG(@"%@: unhandled event %d", aStream, eventCode);
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
    self.inputStream = istr;
    self.outputStream = ostr;
    self.inputStream.delegate = self;
    self.outputStream.delegate = self;
}

@end
