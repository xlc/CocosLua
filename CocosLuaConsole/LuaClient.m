//
//  LuaClient.m
//  CocosLua
//
//  Created by Xiliang Chen on 12-5-18.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import "LuaClient.h"

#import "MessagePacket.h"

@interface LuaClient () <NSStreamDelegate>

@property (nonatomic) BOOL connected;

- (void)handleData:(NSData *)data;

@end

@implementation LuaClient {
    NSInputStream *_inputStream;
    NSOutputStream *_outputStream;
}

@synthesize connected = _connected;

- (id)initWithNetService:(NSNetService *)service
{
    self = [super init];
    if (self) {
        if (![service getInputStream:&_inputStream outputStream:&_outputStream]) {
            MILOG(@"fail to create stream");
            [self release];
            return nil;
        }
        _inputStream.delegate = self;
        _outputStream.delegate = self;
        [_inputStream open];
        [_outputStream open];
        [_inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
        [_outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
        _connected = YES;
    }
    return self;
}

- (void)dealloc
{
    [self close];
    
    [super dealloc];
}

#pragma mark -

- (void)handleData:(NSData *)data {
    MessagePacket *message = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    if (!message) {
        MWLOG(@"Fail to decode data: %@", data);
    }
}

- (void)sendPacket:(MessagePacket *)packet {
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:packet];
    const uint8_t *buff = [data bytes];
    NSUInteger length = [data length];
    while (length > 0) {
        NSInteger len = [_outputStream write:buff maxLength:length];
        if (len >= 0) {
            buff += len;
            length -= len;
        } else {
            MWLOG(@"Fail to write packet with code: %d", len);
            break;
        }
    }
    
}

- (void)close {
    [_inputStream close];
    [_inputStream release];
    _inputStream = nil;
    [_outputStream close];
    [_outputStream release];
    _outputStream = nil;
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

@end
