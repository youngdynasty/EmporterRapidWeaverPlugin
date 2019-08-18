//
//  ERBigButtonCell.m
//  EmporterRapidWeaverPlugin
//
//  Created by Mike Pulaski on 15/08/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "ERBigButtonCell.h"

@implementation ERBigButtonCell

- (void)setBezelStyle:(NSBezelStyle)bezelStyle { }
- (NSBezelStyle)bezelStyle { return NSBezelStyleRoundRect; }

#pragma mark - Colors

- (NSColor *)_actionColor {
    if (@available(macOS 10.14, *)) {
        return [NSColor controlAccentColor];
    } else if ([NSColor currentControlTint] == NSBlueControlTint) {
        return [NSColor colorWithCalibratedRed:0.14 green:0.48 blue:0.99 alpha:1];
    } else {
        return [NSColor colorWithCalibratedRed:0.56 green:0.56 blue:0.58 alpha:1];
    }
}

- (NSColor *)_highlightedActionColorInView:(NSView *)view {
    if (@available(macOS 10.14, *)) {
        if (view.effectiveAppearance.name == NSAppearanceNameDarkAqua) {
            return [[self _actionColor] colorWithSystemEffect:NSColorSystemEffectPressed];
        }
    }
    
    return [[self _actionColor] blendedColorWithFraction:0.25 ofColor:[NSColor blackColor]];
}

- (NSColor *)_disabledActionColorInView:(NSView *)view {
    if (@available(macOS 10.14, *)) {
        if (view.effectiveAppearance.name == NSAppearanceNameDarkAqua) {
            return [[self _actionColor] colorWithSystemEffect:NSColorSystemEffectDisabled];
        }
    }
    
    return [[self _actionColor] colorWithAlphaComponent:0.55];
}

- (NSColor *)_backgroundColorInView:(NSView *)view {
    if (self.isHighlighted) {
        return [self _highlightedActionColorInView:view];
    } else if (self.isEnabled) {
        return [self _actionColor];
    } else {
        return [self _disabledActionColorInView:view];
    }
}

- (nullable NSColor *)_titleColorInView:(NSView *)view {
    if (@available(macOS 10.14, *)) {
        if (view.effectiveAppearance.name == NSAppearanceNameDarkAqua) {
            if (self.isHighlighted) {
                return [[NSColor controlTextColor] colorWithSystemEffect:NSColorSystemEffectPressed];
            } else if (!self.isEnabled) {
                return [[NSColor controlTextColor] colorWithSystemEffect:NSColorSystemEffectDisabled];
            } else {
                return [NSColor controlTextColor];
            }
        }
    }
    
    if (self.isEnabled) {
        return [NSColor whiteColor];
    } else if (self.isHighlighted) {
        return [NSColor blackColor];
    } else {
        return nil;
    }
}

#pragma mark - Layout

static CGFloat cornerRadius = 4;

- (CGFloat)_deltaHeightForBounds:(NSRect)rect {
    return MAX(0, NSHeight(rect) - 24);
}

- (NSRect)titleRectForBounds:(NSRect)rect {
    CGFloat dh = [self _deltaHeightForBounds:rect];
    return [super titleRectForBounds:NSInsetRect(rect, dh/4, 1)];
}

- (NSSize)cellSizeForBounds:(NSRect)rect {
    NSSize size = [super cellSizeForBounds:rect];
    CGFloat newHeight = MAX(size.height, 44);
    CGFloat deltaHeight = MAX(0, newHeight - size.height);
    
    return NSMakeSize(size.width + deltaHeight, newHeight);
}

#pragma mark -

- (NSRect)drawTitle:(NSAttributedString*)title withFrame:(NSRect)frame inView:(NSView*)view {
    NSColor *color = [self _titleColorInView:view];
    
    if (color != nil) {
        NSMutableAttributedString *t = [title mutableCopy];
        [t addAttribute:NSForegroundColorAttributeName value:color range:NSMakeRange(0, title.length)];
        title = [t copy];
    }
    
    return [super drawTitle:title withFrame:frame inView:view];
}

- (void)drawFocusRingMaskWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    [[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(cellFrame, 0, 1) xRadius:cornerRadius yRadius:cornerRadius] fill];
}

- (void)drawBezelWithFrame:(NSRect)frame inView:(NSView *)view {
    [[self _backgroundColorInView:view] setFill];
    [[NSBezierPath bezierPathWithRoundedRect:frame xRadius:cornerRadius yRadius:cornerRadius] fill];
}

@end
