//
//  DataPacket.m
//  CocosLua
//
//  Created by Xiliang Chen on 12-5-17.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import "MessagePacket.h"

#import "LuaConsole.h"
#import "LuaExecutor.h"

@implementation MessagePacket

@synthesize type = _type;
@synthesize content = _content;

- (id)initWithType:(MessageType)type content:(id)content;
{
    self = [super init];
    if (self) {
        _type = type;
        _content = [content retain];
    }
    return self;
}

- (void)dealloc
{
    [_content release];
    
    [super dealloc];
}

#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self) {
        _type = [aDecoder decodeIntForKey:@"type"];
        _content = [[aDecoder decodeObjectForKey:@"content"] retain];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeInt:_type forKey:@"type"];
    [aCoder encodeObject:_content forKey:@"content"];
}

#pragma mark -

- (void)execute {
    switch (_type) {
        case MessageTypeNone:
            break;
        case MessageTypeString: // execute it and print result/error to console
        {
            NSError *error;
            NSArray *result = [[LuaExecutor sharedExecutor] executeString:_content error:&error];
            if (error)
                [[LuaConsole sharedConsole] appendError:error];
            else
                [[LuaConsole sharedConsole] appendArray:result];
        }
            break;
            
        case MessageTypeFile:   // TODO save file then execute it
            break;
    }
}

@end
