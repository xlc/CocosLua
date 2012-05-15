//
//  LuaConsole.h
//  CocosLua
//
//  Created by Xiliang Chen on 12-5-15.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface LuaConsole : UIView

@property (nonatomic, readonly) UITextView *textView;
@property (nonatomic) BOOL visible;

+ (LuaConsole *)sharedConsole;

- (void)appendMessage:(NSString *)msg;

@end
