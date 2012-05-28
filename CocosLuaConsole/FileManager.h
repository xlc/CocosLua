//
//  FileManager.h
//  CocosLua
//
//  Created by Xiliang Chen on 12-5-27.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@class LuaClient;

@interface FileManager : NSObject

@property (nonatomic, copy) NSString *workingDirectroy;

+ (FileManager *)sharedManager;

- (void)start:(LuaClient *)client;
- (void)stop;

@end
