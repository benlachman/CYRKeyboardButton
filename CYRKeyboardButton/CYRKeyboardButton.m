//
//  CYRKeyboardButton.m
//
//  Created by Illya Busigin on 7/19/14.
//  Copyright (c) 2014 Cyrillian, Inc.
//  Portions Copyright (c) 2013 Nigel Timothy Barber (TurtleBezierPath)
//
//  Distributed under MIT license.
//  Get the latest version from here:
//
//  https://github.com/illyabusigin/CYRKeyboardButton
//
// The MIT License (MIT)
//
// Copyright (c) 2014 Cyrillian, Inc.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of
// this software and associated documentation files (the "Software"), to deal in
// the Software without restriction, including without limitation the rights to
// use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
// the Software, and to permit persons to whom the Software is furnished to do so,
// subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import "CYRKeyboardButton.h"
#import "CYRKeyboardButtonView.h"

#define CYRKeyCapImageViewInset 5.0f

NSString *const CYRKeyboardButtonPressedNotification = @"CYRKeyboardButtonPressedNotification";
NSString *const CYRKeyboardButtonKeyPressedKey = @"CYRKeyboardButtonKeyPressedKey";


@interface CYRKeyboardButton () <UIGestureRecognizerDelegate>

@property (nonatomic, strong) UILabel *inputLabel;
@property (nonatomic, strong) UIImageView *keyCapImageView;
@property (nonatomic, strong) CYRKeyboardButtonView *buttonView;
@property (nonatomic, strong) CYRKeyboardButtonView *expandedButtonView;

@property (nonatomic, assign) CYRKeyboardButtonPosition position;

// Input options state
@property (nonatomic, strong) UILongPressGestureRecognizer *optionsViewRecognizer;
@property (nonatomic, strong) UIPanGestureRecognizer *panGestureRecognizer;

// Internal style
@property (nonatomic, assign) CGFloat keyCornerRadius UI_APPEARANCE_SELECTOR;

@end

@implementation CYRKeyboardButton

#pragma mark - UIView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        switch ([UIDevice currentDevice].userInterfaceIdiom) {
            case UIUserInterfaceIdiomPhone:
                _style = CYRKeyboardButtonStylePhone;
                break;
                
            case UIUserInterfaceIdiomPad:
                _style = CYRKeyboardButtonStyleTablet;
                break;
                
            default:
                break;
        }
        
        // Default appearance
        _font = [UIFont systemFontOfSize:22.f];
        _inputOptionsFont = [UIFont systemFontOfSize:24.f];
        _keyColor = [UIColor whiteColor];
        _keyTextColor = [UIColor blackColor];
        _keyShadowColor = [UIColor colorWithRed:136 / 255.f green:138 / 255.f blue:142 / 255.f alpha:1];
        _keyHighlightedColor = [UIColor colorWithRed:213/255.f green:214/255.f blue:216/255.f alpha:1];
        
        // Styling
        self.backgroundColor = [UIColor clearColor];
		self.drawsBackground = YES;
        self.clipsToBounds = NO;
        self.layer.masksToBounds = NO;
        self.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;

        // State handling
        [self addTarget:self action:@selector(handleTouchDown) forControlEvents:UIControlEventTouchDown];
        [self addTarget:self action:@selector(handleTouchUpInside) forControlEvents:UIControlEventTouchUpInside];
    
        // Input label
		_inputLabel = ({
			UILabel *inputLabel = [[UILabel alloc] initWithFrame:self.bounds];
			inputLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
			inputLabel.textAlignment = NSTextAlignmentCenter;
			inputLabel.backgroundColor = [UIColor clearColor];
			inputLabel.userInteractionEnabled = NO;
			inputLabel.textColor = _keyTextColor;
			inputLabel.font = _font;
			
			[self addSubview:inputLabel];
			inputLabel;
		});

		// Key Cap Image View
		_keyCapImageView = ({
			UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectInset(self.bounds, CYRKeyCapImageViewInset, CYRKeyCapImageViewInset)];

			imageView.contentMode = UIViewContentModeScaleAspectFit;
			imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;

			[self addSubview:imageView];
			imageView;
		});
        
        [self updateDisplayStyle];
		_expandsOnTouchDown = YES;
    }
    
    return self;
}

- (void)didMoveToSuperview
{
    [self updateButtonPosition];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    [self setNeedsDisplay];
    
    [self updateButtonPosition];

	self.keyCapImageView.frame = CGRectInset(self.bounds, CYRKeyCapImageViewInset, CYRKeyCapImageViewInset);
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    // Only allow simulateous recognition with our internal recognizers
    return (gestureRecognizer == _panGestureRecognizer || gestureRecognizer == _optionsViewRecognizer) &&
    (otherGestureRecognizer == _panGestureRecognizer || otherGestureRecognizer == _optionsViewRecognizer);
}

#pragma mark - Overrides

- (NSString *)description
{
    NSString *description = [NSString stringWithFormat:@"<%@ %p>; frame = %@; input = %@; inputOptions = %@",
                             NSStringFromClass([self class]),
                             self,
                             NSStringFromCGRect(self.frame),
                             self.input,
                             self.inputOptions];
    
    return description;
}

- (void)setInput:(NSString *)input
{
    [self willChangeValueForKey:NSStringFromSelector(@selector(input))];
    _input = input;
    [self didChangeValueForKey:NSStringFromSelector(@selector(input))];
    
	if (_keyDisplayText == nil) {
		_inputLabel.text = _input;
	}

	if( self.keyCapImageView.image == nil ) {
		self.inputLabel.hidden = NO;
		self.keyCapImageView.hidden = YES;
	}
}

- (void)setKeyDisplayText:(NSString *)keyDisplayText {
    _keyDisplayText = keyDisplayText;
    _inputLabel.text = keyDisplayText;
}

- (void)setInputOptions:(NSArray *)inputOptions
{
    [self willChangeValueForKey:NSStringFromSelector(@selector(inputOptions))];
    _inputOptions = inputOptions;
    [self didChangeValueForKey:NSStringFromSelector(@selector(inputOptions))];
    
    if (_inputOptions.count > 0) {
        [self setupInputOptionsConfiguration];
    } else {
        [self tearDownInputOptionsConfiguration];
    }
}

- (void)setStyle:(CYRKeyboardButtonStyle)style
{
    [self willChangeValueForKey:NSStringFromSelector(@selector(style))];
    _style = style;
    [self didChangeValueForKey:NSStringFromSelector(@selector(style))];
    
    [self updateDisplayStyle];
}

- (void)setKeyTextColor:(UIColor *)keyTextColor
{
    if (_keyTextColor != keyTextColor) {
        [self willChangeValueForKey:NSStringFromSelector(@selector(keyTextColor))];
        _keyTextColor = keyTextColor;
        [self didChangeValueForKey:NSStringFromSelector(@selector(keyTextColor))];
        
        _inputLabel.textColor = keyTextColor;
    }
}

- (void)setFont:(UIFont *)font
{
    if (_font != font) {
        [self willChangeValueForKey:NSStringFromSelector(@selector(font))];
        _font = font;
        [self didChangeValueForKey:NSStringFromSelector(@selector(font))];
        
        _inputLabel.font = font;
    }
}

- (void)setKeyInput:(id<UIKeyInput>)keyInput
{
    NSAssert([keyInput conformsToProtocol:@protocol(UIKeyInput)], @"<CYRKeyboardButton> The key input object must conform to the UIKeyInput protocol!");
    
    [self willChangeValueForKey:NSStringFromSelector(@selector(keyInput))];
    _keyInput = keyInput;
    [self didChangeValueForKey:NSStringFromSelector(@selector(keyInput))];
}

- (void)setKeyCapImage:(UIImage *)image {
	if( image != _keyCapImage ) {
		[self willChangeValueForKey:NSStringFromSelector(@selector(keyCapImage))];
		_keyCapImage = image;
		[self didChangeValueForKey:NSStringFromSelector(@selector(keyCapImage))];
	}

	_keyCapImageView.image = image;

	if( image != nil ) {
		self.inputLabel.hidden = YES;
		self.keyCapImageView.hidden = NO;

		self.keyCapImageView.frame = self.bounds;
	} else {
		self.inputLabel.hidden = NO;
		self.keyCapImageView.hidden = YES;
	}
}

#pragma mark - Internal - UI

- (void)showInputView
{
    if (_style == CYRKeyboardButtonStylePhone) {
		if( self.expandsOnTouchDown == YES ) {
			[self hideInputView];
			
			self.buttonView = [[CYRKeyboardButtonView alloc] initWithKeyboardButton:self type:CYRKeyboardButtonViewTypeInput];
			
			[self.window addSubview:self.buttonView];
		}
    }
    
	[self setNeedsDisplay];
}

- (void)showExpandedInputView:(UILongPressGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        if (self.expandsOnTouchDown == YES && self.expandedButtonView == nil) {
            CYRKeyboardButtonView *expandedButtonView = [[CYRKeyboardButtonView alloc] initWithKeyboardButton:self type:CYRKeyboardButtonViewTypeExpanded];
            
            [self.window addSubview:expandedButtonView];
            self.expandedButtonView = expandedButtonView;
            
            [self hideInputView];
        }
    } else if (recognizer.state == UIGestureRecognizerStateCancelled || recognizer.state == UIGestureRecognizerStateEnded) {
        if (self.panGestureRecognizer.state != UIGestureRecognizerStateRecognized) {
            [self handleTouchUpInside];
        }
    }
}

- (void)hideInputView
{
    [self.buttonView removeFromSuperview];
    self.buttonView = nil;
    
    [self setNeedsDisplay];
}

- (void)hideExpandedInputView
{
	if( self.expandedButtonView != nil ) {
		[self.expandedButtonView removeFromSuperview];
		self.expandedButtonView = nil;
	}
}

- (void)updateDisplayStyle
{
    switch (_style) {
        case CYRKeyboardButtonStylePhone:
            _keyCornerRadius = 4.f;
            break;
            
        case CYRKeyboardButtonStyleTablet:
            _keyCornerRadius = 6.f;
            break;
            
        default:
            break;
    }
    
    [self setNeedsDisplay];
}

#pragma mark - Internal - Text Handling

- (void)insertText:(NSString *)text
{
    BOOL shouldInsertText = YES;
    
    if ([self.keyInput isKindOfClass:[UITextView class]]) {
        // Call UITextViewDelegate methods if necessary
        UITextView *textView = (UITextView *)self.keyInput;
        NSRange selectedRange = textView.selectedRange;
        
        if ([textView.delegate respondsToSelector:@selector(textView:shouldChangeTextInRange:replacementText:)]) {
            shouldInsertText = [textView.delegate textView:textView shouldChangeTextInRange:selectedRange replacementText:text];
        }
    } else if ([self.keyInput isKindOfClass:[UITextField class]]) {
        // Call UITextFieldDelgate methods if necessary
        UITextField *textField = (UITextField *)self.keyInput;
        NSRange selectedRange = [self textInputSelectedRange];
        
        if ([textField.delegate respondsToSelector:@selector(textField:shouldChangeCharactersInRange:replacementString:)]) {
            shouldInsertText = [textField.delegate textField:textField shouldChangeCharactersInRange:selectedRange replacementString:text];
        }
    }
    
    if (shouldInsertText == YES) {
        [self.keyInput insertText:text];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:CYRKeyboardButtonPressedNotification object:self
                                                          userInfo:@{CYRKeyboardButtonKeyPressedKey : text}];
    }
}

- (NSRange)textInputSelectedRange
{
	if( [self.keyInput conformsToProtocol:@protocol(UITextInput)]) {
		id<UITextInput> textInput = (id<UITextInput>)self.keyInput;

		UITextPosition *beginning = textInput.beginningOfDocument;
		
		UITextRange *selectedRange = textInput.selectedTextRange;
		UITextPosition *selectionStart = selectedRange.start;
		UITextPosition *selectionEnd = selectedRange.end;
		
		const NSInteger location = [textInput offsetFromPosition:beginning toPosition:selectionStart];
		const NSInteger length = [textInput offsetFromPosition:selectionStart toPosition:selectionEnd];
		
		return NSMakeRange(location, length);
	} else {
		return NSMakeRange(NSNotFound, 0);
	}
}

#pragma mark - Internal - Configuration

- (void)updateButtonPosition
{
    // Determine the button position state based on the superview padding
    CGFloat leftPadding = CGRectGetMinX(self.frame);
    CGFloat rightPadding = CGRectGetMaxX(self.superview.frame) - CGRectGetMaxX(self.frame);
    CGFloat minimumClearance = CGRectGetWidth(self.frame) / 2 + 8;
    
    if (leftPadding >= minimumClearance && rightPadding >= minimumClearance) {
        self.position = CYRKeyboardButtonPositionInner;
    } else if (leftPadding > rightPadding) {
        self.position = CYRKeyboardButtonPositionLeft;
    } else {
        self.position = CYRKeyboardButtonPositionRight;
    }
}

- (void)setupInputOptionsConfiguration
{
    [self tearDownInputOptionsConfiguration];
    
    if (self.inputOptions.count > 0) {
        UILongPressGestureRecognizer *longPressGestureRecognizer =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(showExpandedInputView:)];
        longPressGestureRecognizer.minimumPressDuration = 0.3;
        longPressGestureRecognizer.delegate = self;
        
        [self addGestureRecognizer:longPressGestureRecognizer];
        self.optionsViewRecognizer = longPressGestureRecognizer;
        
        UIPanGestureRecognizer *panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(_handlePanning:)];
        panGestureRecognizer.delegate = self;
        
        [self addGestureRecognizer:panGestureRecognizer];
        self.panGestureRecognizer = panGestureRecognizer;
    }
}

- (void)tearDownInputOptionsConfiguration
{
    [self removeGestureRecognizer:self.optionsViewRecognizer];
    [self removeGestureRecognizer:self.panGestureRecognizer];
}

#pragma mark - Touch Actions

- (void)handleTouchDown
{
    [[UIDevice currentDevice] playInputClick];

    [self showInputView];
}

- (void)handleTouchUpInside
{
#warning this is janky, fix me.
	if( [[self allTargets] count] == 0 || ([[self allTargets] count] == 1 && [[[self actionsForTarget:self forControlEvent:UIControlEventTouchUpInside] firstObject] isEqualToString:@"handleTouchUpInside"]) ) {
		[self insertText:self.input];
	}

    [self hideInputView];
    [self hideExpandedInputView];
}

- (void)_handlePanning:(UIPanGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateEnded || recognizer.state == UIGestureRecognizerStateCancelled) {
        if (self.expandedButtonView.selectedInputIndex != NSNotFound) {
            NSString *inputOption = self.inputOptions[self.expandedButtonView.selectedInputIndex];
            
            [self insertText:inputOption];
        }
        
        [self hideExpandedInputView];
    } else {
        CGPoint location = [recognizer locationInView:self.superview];
        [self.expandedButtonView updateSelectedInputIndexForPoint:location];
    }
}

#pragma mark - Touch Handling

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesEnded:touches withEvent:event];
    
    [self hideInputView];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesCancelled:touches withEvent:event];
    
    [self hideInputView];
}

#pragma mark - Drawing

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    UIColor *color = self.keyColor;
    
    if ( self.state == UIControlStateHighlighted ) {
        color = self.keyHighlightedColor;
    }

	if( self.drawsBackground == YES ) {
		UIColor *shadow = self.keyShadowColor;
		CGSize shadowOffset = CGSizeMake(0.1, 1.1);
		CGFloat shadowBlurRadius = 0;
		
		UIBezierPath *roundedRectanglePath =
		[UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height - 1) cornerRadius:self.keyCornerRadius];
		CGContextSaveGState(context);
		CGContextSetShadowWithColor(context, shadowOffset, shadowBlurRadius, shadow.CGColor);
		[color setFill];
		[roundedRectanglePath fill];
		CGContextRestoreGState(context);
	}
}

@end
