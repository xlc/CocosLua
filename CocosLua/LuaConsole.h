//
//  LuaConsole.h
//  CocosLua
//
//  Created by Xiliang Chen on 12-5-15.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@class HighlightingTextView;

@interface LuaConsole : UIView

@property (nonatomic, retain, readonly) HighlightingTextView *textView;
@property (nonatomic) BOOL visible;
@property (nonatomic) BOOL fullScreen;

+ (LuaConsole *)sharedConsole;

- (void)toggleVisible;
- (void)toggleFullScreen;

- (void)appendMessage:(NSString *)msg;
- (void)appendError:(NSError *)error;
- (void)appendArray:(NSArray *)array;

- (void)handleInputString:(NSString *)string;

@end
