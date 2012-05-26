//
//  LuaConsole.m
//  CocosLua
//
//  Created by Xiliang Chen on 12-5-15.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import "LuaConsole.h"

#import "LuaExecutor.h"
#import "HighlightingTextView.h"
#import "LuaSyntaxHighligther.h"

static LuaConsole *sharedConsole;

@interface LuaConsole () <UITextViewDelegate>

@property (nonatomic, retain) HighlightingTextView *textView;
@property (nonatomic, retain) UILabel *titleView;

- (void)appendPromptWithFirstLine:(BOOL)firstline;

- (void)keyboardWillShow:(NSNotification *)notification;
- (void)keyboardWillHide:(NSNotification *)notification;

- (void)handleString:(NSString *)string;

- (void)moveView:(UIPanGestureRecognizer *)recognizer;
- (void)resizeView:(UIPanGestureRecognizer *)recognizer;

@end

@implementation LuaConsole {
    NSMutableString *_text;
    NSUInteger _lastPosition;
    BOOL _changeContainNewLine;
    NSMutableString *_buffer;
    CGRect _orignalFrame;
    UIView *_resizerView;
    UITapGestureRecognizer *_tapRecognizer;
}

@synthesize textView = _textView;
@synthesize titleView = _titleView;
@synthesize visible = _visible;
@synthesize fullScreen = _fullScreen;

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
    return [self initWithFrame:CGRectMake(0, 0, 600, 300)];
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _orignalFrame = frame;
        
        _titleView = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleView.text = @"LuaConsole";
        _titleView.textAlignment = UITextAlignmentCenter;
        _titleView.backgroundColor = [UIColor lightGrayColor];
        _titleView.userInteractionEnabled = YES;
        UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleFullScreen)];
        tapRecognizer.numberOfTapsRequired = 2;
        [_titleView addGestureRecognizer:tapRecognizer];
        [tapRecognizer release];
        UIPanGestureRecognizer *panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(moveView:)];
        [_titleView addGestureRecognizer:panRecognizer];
        [panRecognizer release];
        [self addSubview:_titleView];
        
        _textView = [[HighlightingTextView alloc] initWithFrame:CGRectZero];
        _textView.editable = YES;
        _textView.delegate = self;
        _textView.autoresizingMask = UITextAutocorrectionTypeNo;
        _textView.autocapitalizationType = UITextAutocapitalizationTypeNone;
        LuaSyntaxHighligther *highlighter = [[[LuaSyntaxHighligther alloc] init] autorelease];
        highlighter.commandLineMode = YES;
        _textView.syntaxHighlighter = highlighter;
        _textView.font = [UIFont fontWithName:@"Courier New" size:16];  // TODO only works with this font size
        [self addSubview:_textView];
        
        _resizerView = [[UIView alloc] initWithFrame:CGRectZero];
        _resizerView.backgroundColor = [UIColor grayColor];
        panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(resizeView:)];
        [_resizerView addGestureRecognizer:panRecognizer];
        [panRecognizer release];
        [self addSubview:_resizerView];
        
        _text = [[NSMutableString alloc] initWithString:@"LuaConsole:\n"];
        [self appendPromptWithFirstLine:YES];
        
        _buffer = [[NSMutableString alloc] initWithCapacity:200];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyboardWillShow:)
                                                     name:UIKeyboardWillShowNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyboardWillHide:)
                                                     name:UIKeyboardWillHideNotification object:nil];
        
        _tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleVisible)];
        _tapRecognizer.numberOfTapsRequired = 3;
        _tapRecognizer.numberOfTouchesRequired = 2;
        UIWindow *window = [[[UIApplication sharedApplication] windows] objectAtIndex:0];
        [window addGestureRecognizer:_tapRecognizer];

//        self.fullScreen = YES;
    }
    return self;
}

- (void)dealloc
{
    [_tapRecognizer.view removeGestureRecognizer:_tapRecognizer];
    [_tapRecognizer release];
    
    self.textView = nil;
    self.titleView = nil;
    
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
//            [_textView becomeFirstResponder];
        } else { // hide
            [_textView resignFirstResponder];
            self.hidden = YES;
        }
    }
}

- (void)toggleVisible {
    self.visible = !_visible;
}

- (void)setFullScreen:(BOOL)fullScreen {
    _fullScreen = fullScreen;
    if (_fullScreen) {
        _orignalFrame = self.frame;
        CGRect frame = CGRectZero;
        frame.size = [CCDirector sharedDirector].winSize;
        self.frame = frame;
        _resizerView.hidden = YES;
    } else {
        CGRect frame = self.frame;
        frame.size = _orignalFrame.size;
        self.frame = frame;
        _resizerView.hidden = NO;
    }
}

- (void)toggleFullScreen {
    self.fullScreen = !_fullScreen;
}

- (void)layoutSubviews {
    const int titleViewHeight = 30;
    const int resizerSize = 20;
    
    CGRect frame = self.bounds;
    frame.size.height = titleViewHeight;
    _titleView.frame = frame;
    frame.origin.y = titleViewHeight;
    frame.size.height = self.bounds.size.height - titleViewHeight;
    _textView.frame = frame;
    
    frame.origin.x = self.bounds.size.width - resizerSize;
    frame.origin.y = self.bounds.size.height - resizerSize;
    frame.size.height = resizerSize;
    frame.size.width = resizerSize;
    _resizerView.frame = frame;
}

- (void)moveView:(UIPanGestureRecognizer *)recognizer {
    CGRect frame = self.frame;
    if (_fullScreen) {
        frame = _orignalFrame;
        frame.origin.y = 0;
        self.fullScreen = NO;
    }
    CGPoint delta = [recognizer translationInView:self];
    [recognizer setTranslation:CGPointZero inView:self];
    frame.origin = ccpAdd(frame.origin, delta);
    if (frame.origin.y <= 0) {
        self.fullScreen = YES;
    } else {
        self.frame = frame;
    }
}

- (void)resizeView:(UIPanGestureRecognizer *)recognizer {
    CGPoint delta = [recognizer translationInView:self];
    [recognizer setTranslation:CGPointZero inView:self];
    CGRect frame = self.frame;
    frame.size.width += delta.x;
    frame.size.height += delta.y;
    _orignalFrame = frame;
    self.frame = frame;
}

#pragma mark -

- (void)appendMessage:(NSString *)msg { // TODO what happen when user is typeing?
    if (!msg) return;
    
    NSRange range = [_text rangeOfString:@"> " options:NSBackwardsSearch];
    if (range.length + range.location == [_text length]) {
        [_text deleteCharactersInRange:range];
    }
    if ([_text characterAtIndex:[_text length]-1] != '\n')
        [_text appendString:@"\n"];
    [_text appendString:msg];
    [self appendPromptWithFirstLine:YES];
}

- (void)appendPromptWithFirstLine:(BOOL)firstline {
    NSRange range = [_text rangeOfString:@"> " options:NSBackwardsSearch];
    if (range.length + range.location == [_text length]) {
        [_text deleteCharactersInRange:range];
    }
    if ([_text characterAtIndex:[_text length]-1] != '\n') {
        [_text appendString:@"\n"];
    }
    if (firstline)
        [_text appendString:@"> "];
    else
        [_text appendString:@">>  "];
    _lastPosition = [_text length];
    _textView.text = _text;
}

- (void)appendError:(NSError *)error {
    if (!error) return;
    
    NSString *message = [NSString stringWithFormat:@"error: %@", [[error userInfo] objectForKey:NSLocalizedFailureReasonErrorKey]];
    [self appendMessage:message];
}

- (void)appendArray:(NSArray *)array {
    if (!array) return;
    
    NSMutableString *buff = [NSMutableString string];
    for (id obj in array) {
        if (obj == [NSNull null]) {
            [buff appendFormat:@"nil, \t"];
        } else
            [buff appendFormat:@"%@, \t", obj];
    }
    [buff deleteCharactersInRange:NSMakeRange([buff length] - 3, 3)];
    [self appendMessage:buff];
}

- (void)handleInputString:(NSString *)string {

    [_text appendString:string];
    
    [self handleString:string];
}

- (void)handleString:(NSString *)string {
    if ([string length] == 0)
        return;
    BOOL completed;
    LuaExecutor *executor = [LuaExecutor sharedExecutor];
    [_buffer appendString:string];
    if ([_buffer characterAtIndex:0] == '=') {
        [_buffer replaceCharactersInRange:NSMakeRange(0, 1) withString:@"return "];
    }
    [_buffer appendString:@"\n"];   // add new line
    NSError *error = [executor checkString:_buffer completed:&completed];
    if (error) {
        [self appendError:error];
        [_buffer setString:@""];    // clear buffer
    } else if (completed) {
        NSArray *result = [executor executeString:_buffer error:&error];
        if (error) {
            [self appendError:error];
        } else {
            [self appendArray:result];
        }
        [_buffer setString:@""];    // clear buffer
    }
    
    [self appendPromptWithFirstLine:completed];
}

#pragma mark - Keyboard Notification

- (void)keyboardWillShow:(NSNotification *)notification {
    NSDictionary* userInfo = [notification userInfo];
    NSTimeInterval duration = [[userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationCurve curve = [[userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey] intValue];
    
    CGRect keyboardFrame = [[userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    keyboardFrame = [self.superview convertRect:keyboardFrame fromView:nil];
    
    CGRect frame = self.frame;
    CGFloat buttom = CGRectGetMaxY(frame);;
    CGFloat keyboardTop = CGRectGetMinY(keyboardFrame);
    if (buttom > keyboardTop) {
        frame.origin.y += keyboardTop - buttom;
        if (frame.origin.y < 0) {
            frame.size.height += frame.origin.y;
            frame.origin.y = 0;
        }
        [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionBeginFromCurrentState | curve animations:^{
            self.frame = frame;
        } completion:nil];
    }
}

- (void)keyboardWillHide:(NSNotification *)notification {
    self.fullScreen = _fullScreen;  // reset the frame size
}

#pragma mark - UITextViewDelegate

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    _changeContainNewLine = NO;
    if (range.location < _lastPosition) { // not able to modify fixed text
        if ([text isEqualToString:@"\n"]) {
            [_textView setSelectedRange:NSMakeRange(_text.length, 0)];
        } else {
            [_text appendString:text];
            _textView.text = _text;
        }
        return NO;
    }
    if ([text isEqualToString:@"\n"] && range.location != [_text length]) {
        _textView.text = _text;
        _changeContainNewLine = YES;
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
    if (_changeContainNewLine) {
        NSString *scriptString = [_text substringFromIndex:_lastPosition];
        [self handleString:scriptString];
    }
}

@end
