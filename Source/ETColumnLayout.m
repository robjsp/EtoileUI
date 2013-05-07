/*
	Copyright (C) 2007 Quentin Mathe
 
	Author:  Quentin Mathe <qmathe@club-internet.fr>
	Date:  May 2007
	License:  Modified BSD (see COPYING)
 */

#import <EtoileFoundation/Macros.h>
#import <EtoileFoundation/ETCollection.h>
#import "ETColumnLayout.h"
#import "ETGeometry.h"
#import "ETLayoutItem.h"
#import "ETLayoutItemFactory.h"
#import "ETLineFragment.h"
#import "ETCompatibility.h"
#include <float.h>


@implementation ETColumnLayout

- (NSImage *) icon
{
	return [NSImage imageNamed: @"ui-split-panel-vertical.png"];
}

/** Returns a line fragment filled with items to layout. */
- (ETLineFragment *) layoutFragmentWithSubsetOfItems: (NSArray *)unlayoutedItems
{
	float layoutHeight = [self layoutSize].height;

	if ([self isContentSizeLayout])
	{
		layoutHeight = FLT_MAX;
	}

	ETLineFragment *line = [ETLineFragment verticalLineWithOwner: self 
	                                                  itemMargin: [self itemMargin]
	                                                   maxHeight: layoutHeight 
	                                                   isFlipped: [_layoutContext isFlipped]];
	NSArray *acceptedItems = [line fillWithItems: unlayoutedItems];

	if ([acceptedItems isEmpty])
		return nil;

	return line;
}

- (NSSize) computeLocationsForFragments: (NSArray *)layoutModel
{
	if ([layoutModel isEmpty])
		return NSZeroSize;

	NSParameterAssert([layoutModel count] == 1);

	ETLineFragment *line = [layoutModel lastObject];
	float lineHeight = [line height];
	float totalMargin = ([self borderMargin] + [self itemMargin]) * 2;
	float contentHeight = lineHeight + totalMargin;

	/* Will compute and set the item locations */
	[line setOrigin: [self originOfFirstFragment: line
	                            forContentHeight: contentHeight]];

	ETDebugLog(@"Item locations computed by layout line :%@", line);

	/* lineHeight already includes itemMargin * 2 */
	return NSMakeSize([self horizontalAlignmentGuidePosition] + [line width] + totalMargin, contentHeight);
}

static const float undeterminedWidth = 10;

- (void) prepareSeparatorItem: (ETLayoutItem *)separator
{
	NSString *identifier = [separator identifier];
 
	if ([identifier isEqualToString: kETLineSeparatorItemIdentifier])
	{
		[separator setSize: NSMakeSize(undeterminedWidth, kETLineSeparatorMinimumSize)];
	}
	else if ([identifier isEqualToString: kETSpaceSeparatorItemIdentifier])
	{
		[separator setWidth: undeterminedWidth];
	}
	if ([identifier isEqualToString: kETFlexibleSpaceSeparatorItemIdentifier])
	{
		[separator setSize: NSZeroSize];
	}
}

- (void) prepareFlexibleItem: (ETLayoutItem *)anItem
{
	[anItem setHeight: 0];
}

/** Returns YES if the item autoresizing mask includes ETAutoresizingFlexibleHeight. */
- (BOOL) isFlexibleItem: (ETLayoutItem *)anItem
{
	return [anItem autoresizingMask] & ETAutoresizingFlexibleHeight;
}

- (NSSize) sizeOfFlexibleItem: (ETLayoutItem *)anItem
         forCurrentLayoutSize: (NSSize)aLayoutSize 
        numberOfFlexibleItems: (NSUInteger)nbOfFlexibleItems
                inMaxAreaSize: (NSSize)maxSize 
{
	return NSMakeSize([anItem width], (maxSize.height - aLayoutSize.height) / nbOfFlexibleItems);
}

- (void) adjustSeparatorItem: (ETLayoutItem *)separator 
               forLayoutSize: (NSSize)newLayoutSize
{
	float totalEndMargin = [self separatorItemEndMargin];

	[separator setX: totalEndMargin];
	[separator setWidth: (newLayoutSize.width - totalEndMargin * 2)];
}

- (void) resizeItems: (NSArray *)items
    forNewLayoutSize: (NSSize)newLayoutSize
             oldSize: (NSSize)oldLayoutSize
{
	if (NSEqualSizes(newLayoutSize, oldLayoutSize))
		return;

	for (ETLayoutItem *item in items)
	{
		ETAutoresizing autoresizing = [item autoresizingMask];
		NSRect frame = [item frame];

		ETAutoresize(&frame.origin.x, &frame.size.width,
					 NO,
					 (autoresizing & ETAutoresizingFlexibleWidth),
					 NO,
					 newLayoutSize.width, oldLayoutSize.width);
		
		[item setWidth: frame.size.width];
	}
}

@end
