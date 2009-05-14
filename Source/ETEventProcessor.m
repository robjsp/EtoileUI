/*
	Copyright (C) 2008 Quentin Mathe

	Author:  Quentin Mathe <qmathe@club-internet.fr>
	Date:  February 2008
	License:  Modified BSD (see COPYING)
 */

#import <EtoileFoundation/Macros.h>
#import "ETEventProcessor.h"
#import "ETDecoratorItem.h"
#import "ETGeometry.h"
#import "ETInstrument.h"
#import "ETEvent.h"
#import "ETLayoutItem.h"
#import "ETApplication.h"
#import "ETView.h"
#import "ETCompatibility.h"

@implementation ETEventProcessor

static ETEventProcessor *sharedInstance = nil;

/** Returns the event processor that corresponds to the widget backend currently 
in use. */
+ (id) sharedInstance
{
	if (sharedInstance == nil)
	{
		// TODO: Rework to look up the class to instantiate based on the 
		// linked/configured widged backend.
		sharedInstance = [[ETAppKitEventProcessor alloc] init];
	}

	return sharedInstance; 
}

/** Implements in concrete subclasses to turn each raw event emitted by the run 
loop of the widget backend into an EtoileUI-native event, then invoke the 
related event method on the active instrument with the new ETEvent object in 
parameter.

The implementation is expected to return YES if anEvent should be dispatched by 
the widget backend itself, otherwise NO if only EtoileUI should be in charge of 
displatching the event. */
- (BOOL) processEvent: (void *)theEvent
{
	return NO;
}

- (BOOL) tryActivateItem: (ETLayoutItem *)item withEvent: (ETEvent *)anEvent
{
	return NO;
}

/** Implements in concrete subclasses to have backend widgets handle events 
directly as they would do when used outside of EtoileUI.

The implementation is expected to return YES if anEvent was properly dispatched 
and handled by a widget view associated with item, and NO otherwise. */
- (BOOL) trySendEvent: (ETEvent *)anEvent toWidgetViewOfItem: (ETLayoutItem *)item
{
	return NO;
}

@end

@interface NSWindow (GNUstepCocoaPrivate)
// NOTE: This method is implemented on NSWindow, although the public API 
// only exposes it at NSPanel level.
- (BOOL) becomesKeyOnlyIfNeeded;
@end


@implementation ETAppKitEventProcessor

/** Processes AppKit NSEvent objects handed by -[NSApplication sendEvent:].

Returns YES when the event has been handled by EtoileUI, otherwise returns NO 
when the event has to be handled by the widget backend. */
- (BOOL) processEvent: (void *)theEvent
{
	ETEvent *nativeEvent = ETEVENT((NSEvent *)theEvent, nil, ETNonePickingMask);

	switch ([(NSEvent *)theEvent type])
	{
		case NSMouseMoved:
		case NSLeftMouseDown:
		case NSLeftMouseUp:
		case NSLeftMouseDragged:
			return [self processMouseEvent: nativeEvent];
		case NSKeyDown:
		case NSKeyUp:
		case NSFlagsChanged:
			return [self processKeyEvent: nativeEvent];
		// FIXME: Handle more event types...
		default:
			return NO;
	}
}

- (BOOL) processKeyEvent: (ETEvent *)anEvent
{
	ETInstrument *activeInstrument = [ETInstrument activeInstrument];
	
	switch ([anEvent type])
	{
		case NSKeyDown:
			[activeInstrument keyDown: anEvent];
			break;
		case NSKeyUp:
			[activeInstrument keyUp: anEvent];
			break;
		case NSFlagsChanged:
			ETDebugLog(@"Modifiers changed to %d", [anEvent modifierFlags]);
			return NO;
		default:
			return NO;
	}

	return YES;
}

- (BOOL) isMovingOrResizingWindow
{
	return (_wasMouseDownProcessed == NO);
}

/** Tests whether the event is located within the window content or rather on 
the window border/titlebar. In the latter case, the event is not pushed to the 
active instrumend and NO is returned.

Returns YES when the event has been handled by EtoileUI. */
- (BOOL) processMouseEvent: (ETEvent *)anEvent
{
	ETLog(@"Process mouse event %@", anEvent);

	if ([anEvent type] == NSLeftMouseUp)
	{
		ETLog(@"Blabla");
	}

	if ([anEvent isWindowDecorationEvent] || [anEvent contentItem] == nil)
		return NO;

	ETInstrument *activeInstrument = [ETInstrument activeInstrument];

	ASSIGN(_initialKeyWindow, [NSApp keyWindow]); /* Used by -wasKeyWindow: */

	switch ([anEvent type])
	{
		case NSMouseMoved:
			[self processMouseMovedEvent: anEvent];
			[ETInstrument updateCursorIfNeeded];
			break;
		case NSLeftMouseDown:
			_wasMouseDownProcessed = YES;
			[self processMouseMovedEvent: anEvent]; /* Emit enter/exit events in case the event window is a new one */
			[[ETInstrument updateActiveInstrumentWithEvent: anEvent] mouseDown: anEvent];
			break;
		case NSLeftMouseUp:
			_wasMouseDownProcessed = NO;
			[activeInstrument mouseUp: anEvent];
			break;
		case NSLeftMouseDragged:
			/* When the mouse moves or resizes a window not slowly, the pointer 
			   location is inside the window because the window geometry is 
			   yet to be updated to accomodate the move/resize delta. If we do 
			   not check that, a drag is initiated on the content item. */
			if ([self isMovingOrResizingWindow])
			{
				return NO;
			}
			[activeInstrument mouseDragged: anEvent];
			break;
		default:
			return NO;
	}

	return YES;
}


/** Synthetizes NSMouseEntered and NSMouseExited events when the mouse enters 
and exits layout items, and pushes them to the active instrument.

For each mouse moved event, the receiver will emit new events:
<enum>
<item>-mouseMoved:</item>
<item>-mouseExited: (only if needed)</item>
<item>-mouseEntered: (onlt if needed)</item>
</enum>

Here is an example that shows which events you should expect by moving the 
pointer along the bullet line from W to D. W, A, B, D are layout items and W 
is the root item which contains both A and D.
<deflist>
<term>W (lauch time)</term><desc>Enter W</desc>
<term>W to A</term><desc>Enter A</desc>
<term>A to B</term><desc>Enter B</desc>
<term>B to D</term><desc>Exit B, Exit A, Enter D</desc>
</deflist>
          -------------------
          |                 |    |---------|
          |        |--------|    |         |
   W •••••|•• A •••|••• B ••|••••|••• D    |
          |        |--------|    |         |
          |                 |    |---------|
          -------------------
*/
- (void) processMouseMovedEvent: (ETEvent *)anEvent
{
	ETInstrument *instrument = [ETInstrument activeInstrument];
	ETLayoutItem *hitItem = [[ETInstrument instrument] hitTestWithEvent: anEvent];

	//ETLog(@"Will process mouse move on %@ and hovered item stack\n %@", 
	//	hitItem, [instrument hoveredItemStack]);

	[anEvent setLayoutItem: hitItem];
	/* We send move event before enter and exit events as AppKit does, we could 
	   have choosen to do the reverse though. */
	if ([anEvent type] == NSMouseMoved)
		[instrument mouseMoved: anEvent];

	/* We call -synthetizeMouseExitedEvent: first because the exited item must 
	   be popped from the hovered item stack before a new one can be pushed. */
	ETEvent *exitEvent = [self synthetizeMouseExitedEvent: anEvent];
	ETEvent *enterEvent = [self synthetizeMouseEnteredEvent: anEvent];

	NSParameterAssert([[instrument hoveredItemStack] firstObject] == [instrument hitItemForNil]);

	/* Exit must be handled before enter because enter means the active 
	   instrument might change and the new one may have a very different
	   dispatch than the instrument attached to the area we exit. 
	   Different dispatch means the item on which the exit action will be 
	   invoked is unpredictable. */
	if (exitEvent != nil)
	{
		NSParameterAssert([exitEvent type] == NSMouseExited);

		/* We exit the area attached to the current active instrument, hence 
		   we hand the dispatch to the previously active one. */
		[instrument mouseExited: exitEvent];
	}
	if (enterEvent != nil)
	{
		NSParameterAssert([enterEvent type] == NSMouseEntered);

		/* The new active instrument is attached to the area we enter in, hence 
		   we hand the dispatch to it. */
		[(ETInstrument *)[ETInstrument activeInstrument] mouseEntered: enterEvent];
	}

	//ETLog(@"Did process mouse move and hovered item stack\n %@", [instrument hoveredItemStack]);
}

/** Always calls -synthetizeMouseExitedEvent: first because the exited item 
must be popped from the hovered item stack before a new one can be pushed. It 
also ensures the hovered item stack is valid. */
- (ETEvent *) synthetizeMouseEnteredEvent: (ETEvent *)anEvent
{
	// TODO: Evaluate whether we should rather do...
	//if (_lastWindowNumber != [anEvent windowNumber])
	//	return anEvent;
	if (nil == [anEvent window])
		return nil;

	NSMutableArray *hoveredItemStack = [[ETInstrument activeInstrument] hoveredItemStack];

	NSAssert([hoveredItemStack count] > 0, @"Hovered item stack must never be empty");

	/* The previously hovered item will have already been popped by
	   -synthetizeMouseExitedEvent: when an item is exited. Which means 
	   lastHoveredItem is usually not the previously hovered item but its parent. */
	ETLayoutItem *hoveredItem = [anEvent layoutItem];
	ETLayoutItem *lastHoveredItem = [hoveredItemStack lastObject];
	/* See -processMouseMovedEvent: illustation example in the method doc. */
	BOOL onlyExit = (hoveredItem == lastHoveredItem);
	BOOL noEnter = onlyExit;
	
	if (noEnter)
		return nil;

	[hoveredItemStack addObject: hoveredItem];
	
	ETDebugLog(@"Synthetize mouse enters item %@", hoveredItem);

	return [ETEvent enterEventWithEvent: anEvent];
}

/** See -synthetizeMouseEnteredEvent:. */
- (ETEvent *) synthetizeMouseExitedEvent: (ETEvent *)anEvent
{
	// TODO: See -synthetizeMouseEnteredEvent:
	if (nil == [anEvent window])
		return nil;
	
	ETInstrument *instrument = [ETInstrument activeInstrument];
	NSMutableArray *hoveredItemStack = [instrument hoveredItemStack];

	NSAssert([hoveredItemStack count] > 0, @"Hovered item stack must never be empty");

	/* On an exit event, the hovered item is not the same than the last time
	   this method was called. At code level...
	   hoveredItem != [_hoveredItemStack lastObject] */
	ETLayoutItem *hoveredItem = [anEvent layoutItem];
	ETLayoutItem *lastHoveredItem = [hoveredItemStack lastObject];
	/* See -processMouseMovedEvent: illustation example in the method doc. */
	BOOL noExit = (lastHoveredItem == hoveredItem || lastHoveredItem == (id)[hoveredItem parentItem]);
	
	if (noExit)
		return nil;

	ETDebugLog(@"Synthetize mouse exits item %@", lastHoveredItem);
	
	/* Synthetize the event now, because lastHoveredItem might become invalid 
	   with -removeLastObject:. */
	ETEvent *exitEvent =  [ETEvent exitEventWithEvent: anEvent layoutItem: lastHoveredItem];

	// NOTE: Equivalent to hoveredItem != [ETLayoutItem windowGroup]
	BOOL notInsideRootItem = ([hoveredItemStack count] > 1);
	if (notInsideRootItem)
		[hoveredItemStack removeLastObject];

	/* We have to cope with various border cases or lost events */
	[instrument rebuildHoveredItemStackIfNeededForEvent: anEvent];

	return exitEvent;
}

/** Unlike other -processXXX methods, this one is called back by 
-[ETInstrument mouseDown:] where the active instrument is responsible to choose 
the responder (layout item or widget view) on which the event is expected to be 
dispatched. */
- (BOOL) tryActivateItem: (ETLayoutItem *)item withEvent: (ETEvent *)anEvent
{
	NSEvent *evt = [anEvent backendEvent];
	NSWindow *window = [evt window]; // FIXME: When item is not nil, should be [item window]...

	if (window == nil)
		return NO;

#ifdef GNUSTEP
	BOOL refusesKey = ([window level] == NSDesktopWindowLevel);
	BOOL refusesActivate = ([window styleMask] & (NSIconWindowMask | NSMiniWindowMask));
#else
	BOOL refusesKey = NO;
	BOOL refusesActivate = NO;
#endif

	/* Key window update */
	BOOL needsBecomeKey = ([window becomesKeyOnlyIfNeeded] == NO
		|| [[item view] needsPanelToBecomeKey]);

	if (refusesKey || needsBecomeKey == NO)
		return NO;

	[window makeKeyWindow];
	[window makeKeyAndOrderFront: self];
	/*if ([NSApp isActive])
		NSParameterAssert([NSApp keyWindow] == window);*/

	/* Active application update */
	if (refusesActivate || [NSApp isActive])
		return NO;
	
	[NSApp activateIgnoringOtherApps: YES];

	return YES;
}

- (BOOL) wasKeyWindow: (NSWindow *)aWindow
{
	return [aWindow isEqual: _initialKeyWindow];
}

- (void) sendMouseDown: (NSEvent *)evt toView: (NSView *)aView
{
	NSAssert([[evt window] isEqual: [aView window]], @"");

	/* First responder update
	   TODO: Try to remove, on Mac OS X, each control is responsible to decide 
	   whether it becomes first responder or not on mouse down */
#ifdef GNUSTEP
	if ([aView acceptsFirstResponder] == NO)
	{
		return;
	}
	if ([[evt window] makeFirstResponder: aView] == NO)
	{
		return;
	}
#endif

	/* Click-through support */
	if ([self wasKeyWindow: [evt window]] || [aView acceptsFirstMouse: evt])
	{
		[aView mouseDown: evt];
	}
}

/* This is similar to the logic implemented by -[NSWindow sendEvent:]. */
- (void) sendEvent: (NSEvent *)evt toView: (NSView *)aView
{
	switch ([evt type])
	{
		case NSLeftMouseDown:
			[self sendMouseDown: evt toView: aView];
			break;
		case NSLeftMouseUp:
			[aView mouseUp: evt];
			break;
		case NSLeftMouseDragged:
			[aView mouseDragged: evt];
			break;
		default:
			break;
	}
}

/** Tries to send an event to a view bound to the given item and returns whether 
the event was sent. The item view must returns YES to -isWidgetView, otherwise 
the event won't be sent.

If the event is located on a decorator item bound to the item, this method will 
try to send it to the widget view that makes up the decorator.

If item is nil, returns NO immediately. */
- (BOOL) trySendEvent: (ETEvent *)anEvent toWidgetViewOfItem: (ETLayoutItem *)item
{
	if (item == nil)
		return NO;

	NSPoint eventLoc = [anEvent locationInLayoutItem]; /* In the item coordinate space */
	ETUIItem *hitItem = [item decoratorItemAtPoint: eventLoc];

	NSParameterAssert([anEvent layoutItem] == item);
	NSParameterAssert(hitItem != nil);

	/* Convert eventLoc to hitItem coordinate space */
	id decorator = [item lastDecoratorItem];
	NSPoint relativeLoc = eventLoc;

	while (decorator != hitItem)
	{
		relativeLoc = [decorator convertDecoratorPointToContent: relativeLoc];
		decorator = [decorator decoratedItem];
	}

	/* Try to send the event */
	if ([hitItem usesWidgetView])
	{
		NSView *hitTestView = [hitItem displayView];
		// FIXME: Should be [item convertPointToParent: [anEvent locationInLayoutItem]];
		
		NSPoint parentRelativePoint = relativeLoc;
		
		//if ([hitTestView isEqual: [[hitTestView window] contentView]] == NO)
		{
			parentRelativePoint = [hitTestView convertPoint: relativeLoc 
		                                                 toView: [hitTestView superview]];
		}
		NSView *widgetSubview = [hitTestView hitTest: parentRelativePoint];

		ETDebugLog(@"Hit test widget subview %@ at %@", widgetSubview, NSStringFromPoint(relativeLoc));

		BOOL isVisibleSubview = ([widgetSubview window] != nil);
		if (isVisibleSubview) /* For opaque layout that cover item views */
		{
			[self sendEvent: [anEvent backendEvent] toView: widgetSubview];
			return YES;
		}
	}

	return NO;
}


@end