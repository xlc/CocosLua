//
//  LuaConsole.m
//  CocosLua
//
//  Created by Xiliang Chen on 12-5-15.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import "LuaConsole.h"

#import "LuaExecutor.h"

static LuaConsole *sharedConsole;

@interface LuaConsole () <UITextViewDelegate>

@property (nonatomic) UITextView *textView;

- (void)appendError:(NSError *)error;
- (void)appendPromtWithFirstLine:(BOOL)firstline;

- (void)keyboardDidShow:(NSNotification *)notification;
- (void)keyboardWillHide:(NSNotification *)notification;

@end

@implementation LuaConsole {
    NSMutableString *_text;
    NSUInteger _lastPosition;
    BOOL _changeContainNewLine;
    NSMutableString *_buffer;
}

@synthesize textView = _textView;
@synthesize visible = _visible;

#pragma mark -

+ (LuaConsole *)sharedConsole {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedConsole = [[LuaConsole alloc] init];
    });
    return sharedConsole;
}

- (id)init
{
    CGSize size = [[CCDirector sharedDirector] winSize];
    return [self initWithFrame:CGRectMake(0, 0, size.width, size.height)];
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _textView = [[UITextView alloc] initWithFrame:frame];
        _textView.editable = YES;
        _textView.delegate = self;
        _textView.autoresizingMask = UITextAutocorrectionTypeNo;
        _textView.autocapitalizationType = UITextAutocapitalizationTypeNone;
        [self addSubview:_textView];
        
        _text = [[NSMutableString alloc] initWithCapacity:200];
        [_text appendString:@"LuaConsole:\n"];
        [self appendPromtWithFirstLine:YES];
        
        _buffer = [[NSMutableString alloc] initWithCapacity:200];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyboardDidShow:)
                                                     name:UIKeyboardDidShowNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyboardWillHide:)
                                                     name:UIKeyboardWillHideNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [_textView release];
    
    [super dealloc];
}

#pragma mark -

- (void)setVisible:(BOOL)visible {
    if (_visible != visible) {
        _visible = visible;
        if (_visible) { // show
            self.hidden = NO;
            UIView *superview = [CCDirector sharedDirector].view.superview;
            if (!self.superview) {
                [superview addSubview:self];
            }
            [superview bringSubviewToFront:self];
            [_textView becomeFirstResponder];
        } else { // hide
            self.hidden = YES;
        }
    }
}

- (void)appendMessage:(NSString *)msg {
    if ([_text characterAtIndex:[_text length]-1] != '\n')
        [_text appendString:@"\n"];
    [_text appendString:msg];
    _lastPosition = [_text length];
    _textView.text = _text;
}

- (void)appendPromtWithFirstLine:(BOOL)firstline {
    if ([_text characterAtIndex:[_text length]-1] != '\n')
        [_text appendString:@"\n"];
    if (firstline)
        [_text appendString:@"> "];
    else
        [_text appendString:@">>   "];
    _lastPosition = [_text length];
    _textView.text = _text;
}

- (void)appendError:(NSError *)error {
    NSString *message = [NSString stringWithFormat:@"error: %@", [[error userInfo] objectForKey:NSLocalizedFailureReasonErrorKey]];
    [self appendMessage:message];
}

#pragma mark - Keyboard Notification

- (void)keyboardDidShow:(NSNotification *)notification {
    NSDictionary* info = [notification userInfo];
    CGRect kbRect = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue];
    UIWindow *window = [[UIApplication sharedApplication].windows objectAtIndex:0];
    CGSize kbSize = [window convertRect:kbRect toView:self].size;
    CGRect frame = _textView.frame;
    frame.size.height -= kbSize.height;
    _textView.frame = frame;
}

- (void)keyboardWillHide:(NSNotification *)notification {
    CGSize size = [[CCDirector sharedDirector] winSize];
    CGRect frame = _textView.frame;
    frame.size = size;
    _textView.frame = frame;
}

#pragma mark - UITextViewDelegate

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    _changeContainNewLine = NO;
    if (range.location < _lastPosition) { // not able to modify fixed text
        return NO;
    }
    [_text deleteCharactersInRange:range];
    [_text insertString:text atIndex:range.location];
    NSRange newlinepos = [text rangeOfString:@"\n"];
    if (newlinepos.location != NSNotFound)
        _changeContainNewLine = YES;
    return YES;
}

- (void)textViewDidChange:(UITextView *)textView {
    NSRange newlinepos;
    if (_changeContainNewLine) {
        NSString *remain = [_text substringFromIndex:_lastPosition];
        newlinepos = [remain rangeOfString:@"\n" options:NSBackwardsSearch range:NSMakeRange(0, remain.length)];
        NSString *scriptString = [remain substringToIndex:newlinepos.location];
        BOOL completed;
        LuaExecutor *executor = [LuaExecutor sharedExecutor];
        [_buffer appendString:scriptString];
        NSError *error = [executor checkString:_buffer completed:&completed];
        if (error) {
            [self appendError:error];
            [_buffer setString:@""];    // clear buffer
        } else if (completed) {
            NSError *error = [executor executeString:_buffer];
            if (error) {
                [self appendError:error];
            }
            [_buffer setString:@""];    // clear buffer
        }
        
        [self appendPromtWithFirstLine:completed];
    }
}

@end
