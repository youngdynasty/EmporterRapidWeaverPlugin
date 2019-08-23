//
//  ERLinkButtonCell.m
//  EmporterRapidWeaverPlugin
//
//  Created by Mike Pulaski on 23/08/2019.
//  Copyright © 2019 Young Dynasty. All rights reserved.
//

#import "ERLinkButtonCell.h"

@implementation ERLinkButtonCell

- (void)resetCursorRect:(NSRect)cellFrame inView:(NSView *)controlView {
    [super resetCursorRect:cellFrame inView:controlView];
    [controlView addCursorRect:cellFrame cursor:[NSCursor pointingHandCursor]];
}

@end
