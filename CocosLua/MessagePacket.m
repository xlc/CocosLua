//
//  DataPacket.m
//  CocosLua
//
//  Created by Xiliang Chen on 12-5-17.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import "MessagePacket.h"

@implementation MessagePacket

@synthesize type = _type;
@synthesize content = _content;

+ (id)packetWithType:(MessageType)type content:(id)content {
    return [[[self alloc] initWithType:type content:content] autorelease];
}

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

- (NSString *)description {
    return [NSString stringWithFormat:@"%@: %d - %@", [super description], _type, _content];
}

@end
