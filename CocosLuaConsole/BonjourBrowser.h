//
//  BonjourBrowser.h
//  CocosLua
//
//  Created by Xiliang Chen on 18/05/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BonjourBrowser : NSObject

@property (retain) NSNetService *server;
@property (retain, readonly) NSDictionary *errorDict;

- (void)start;
- (void)stop;
- (BOOL)wait;
- (BOOL)waitForTimeInterview:(NSTimeInterval)time;

@end
