//
//  ETTableLayout.m
//  FlowAutolayoutExample
//
//  Created by Quentin Mathé on 26/12/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "ETTableLayout.h"
#import "ETContainer.h"
#import "ETLayoutItem.h"
#import "ETViewLayoutLine.h"
#import "NSView+Etoile.h"
#import "GNUstep.h"

@interface ETContainer (PackageVisibility)
- (NSArray *) layoutItemCache;
@end

/* Private Extensions */

@interface NSDictionary (EtoileHorribleHack)
- (id) objectForUncopiedKey: (id)key;
- (void) setObject: (id)object forUncopiedKey: (id)key;
@end

/* Terribly unefficient but well will do the trick right now :-) */
@implementation NSMutableDictionary (EtoileHorribleHack)
- (id) objectForUncopiedKey: (id)key
{
	//NSLog(@"Returning object for hash %d of key %@", [key hash], key);
	return [self objectForKey: [NSNumber numberWithInt: [key hash]]];
}

- (void) setObject: (id)object forUncopiedKey: (id)key
{
	//NSLog(@"Setting object for hash %d of key %@", [key hash], key);
	[self setObject: object forKey: [NSNumber numberWithInt: [key hash]]];
}
@end

/* Private Interface */

@interface ETTableLayout (ETableLayoutDisplayViewGeneration)
- (NSScrollView *) scrollingTableView;
@end

#define DEFAULT_ROW_HEIGHT 16


@implementation ETTableLayout

- (id) init
{
	self = [super init];
    
	if (self != nil)
	{
		BOOL nibLoaded = [NSBundle loadNibNamed: @"TablePrototype" owner: self];
		
		if (nibLoaded == NO)
		{
			NSLog(@"Failed to load nib TablePrototype");
			RELEASE(self);
			return nil;
		}
    }
    
	return self;
}

- (void) dealloc
{
	DESTROY(_displayViewPrototype);
	
	[super dealloc];
}

- (void) awakeFromNib
{
	NSLog(@"Awaking from nib for %@", self);
	RETAIN(_displayViewPrototype);
	[_displayViewPrototype removeFromSuperview];
}

- (void) renderWithLayoutItems: (NSArray *)items inContainer: (ETContainer *)container
{
	NSScrollView *scrollView = nil;
	NSTableView *tv = nil;
	
	/* No display view proto available, a table view needs needs to be created 
	   in code */
	if ([self displayViewPrototype] == nil)
	{
		scrollView = [self scrollingTableView];
	}
	else
	{
		NSView *proto = [self displayViewPrototype];
		
		if ([proto isKindOfClass: [NSScrollView class]])
		{
			scrollView = (NSScrollView *)[self displayViewPrototype];
		}
		else
		{
			NSLog(@"WARNING: %@ display view prototype %@ isn't an NSScrollView instance", self, proto);
		}
	}
	
	NSLog(@"%@ scroll view has %@ as document view", self, [scrollView documentView]);
	tv = [scrollView documentView];
	
	if ([scrollView superview] == nil)
	{
		[container setDisplayView: scrollView];
	}
	else if ([[scrollView superview] isEqual: container] == NO)
	{
		NSLog(@"WARNING: Table view of table layout should never have another "
			  @"superview than container parameter or nil.");
	}
	
	[self resizeLayoutItems: items toScaleFactor: [container itemScaleFactor]];
	
	if ([tv dataSource] == nil)
		[tv setDataSource: self];
	if ([tv delegate] == nil)
		[tv setDelegate: self];
		
	[tv reloadData];
}

- (void) resizeLayoutItems: (NSArray *)items toScaleFactor: (float)factor
{
	NSTableView *tv = [(NSScrollView *)_displayViewPrototype documentView];
	// NOTE: Always recompute row height from the original one to avoid really
	// value shifting quickly because of rounding.
	float rowHeight = DEFAULT_ROW_HEIGHT * factor;
	
	/* Enforce a minimal row height to avoid redisplay crashes especially */
	if (rowHeight < 1.0)
		rowHeight = 1.0;
	[tv setRowHeight: rowHeight];
}

- (int) numberOfRowsInTableView: (NSTableView *)tv
{
	NSArray *layoutItems = [[self container] layoutItemCache];
	
	//NSLog(@"Returns %d as number of items in table view %@", [layoutItems count], tv);
	
	return [layoutItems count];
}

- (id) tableView: (NSTableView *)tv objectValueForTableColumn: (NSTableColumn *)column row: (int)rowIndex
{
	NSArray *layoutItems = [[self container] layoutItemCache];
	ETLayoutItem *item = [layoutItems objectAtIndex: rowIndex];
	
	//NSLog(@"Returns %@ as object value in table view %@", [item valueForProperty: [column identifier]], tv);
	
	return [item valueForProperty: [column identifier]];
}

- (ETLayoutItem *) clickedItem
{
	NSTableView *tv = [(NSScrollView *)_displayViewPrototype documentView];
	NSArray *layoutItems = [[self container] layoutItemCache];
	ETLayoutItem *item = [layoutItems objectAtIndex: [tv clickedRow]];
	
	return item;
}

@end

/* Private Helper Methods */

@implementation ETTableLayout (ETableLayoutDisplayViewGeneration)

/** Build a table view enclosed in a scroll view from scratch. */
- (NSScrollView *) scrollingTableView
{
	NSTableView *tv = nil;
	NSScrollView *prebuiltTableView = nil;
	NSRect rect = NSMakeRect(0, 0, 180, 100);
	
	prebuiltTableView = [[NSScrollView alloc] initWithFrame: rect];
	[prebuiltTableView setAutoresizingMask: NSViewHeightSizable];
	
	NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier: @"name"];
	
	[column setWidth: 180];
	[column setEditable: NO];
	
	rect = [[prebuiltTableView documentView] bounds];
	tv = [[NSTableView alloc] initWithFrame: rect];
	[tv setAutoresizingMask: NSViewHeightSizable];
	[tv addTableColumn: column];
	[prebuiltTableView setDocumentView: tv];
	DESTROY(column);
	RELEASE(tv);
	AUTORELEASE(prebuiltTableView);
	
	[tv setCornerView: nil];
	[tv setHeaderView: nil];
	
	return prebuiltTableView;
}

@end
