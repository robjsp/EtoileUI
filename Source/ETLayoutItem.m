/*
	Copyright (C) 2007 Quentin Mathe

	Author:  Quentin Mathe <qmathe@club-internet.fr>
	Date:  May 2007
	License: Modified BSD (see COPYING)
 */

#import <EtoileFoundation/NSIndexPath+Etoile.h>
#import <EtoileFoundation/NSMapTable+Etoile.h>
#import <EtoileFoundation/NSObject+Etoile.h>
#import <EtoileFoundation/NSObject+HOM.h>
#import <EtoileFoundation/NSObject+Model.h>
#import <EtoileFoundation/ETUTI.h>
#import <EtoileFoundation/Macros.h>
#import <CoreObject/COObjectGraphContext.h>
#import "ETLayoutItem.h"
#import "ETActionHandler.h"
#import "ETBasicItemStyle.h"
#import "ETController.h"
#import "ETGeometry.h"
#import "ETItemValueTransformer.h"
#import "ETLayoutItemGroup.h"
#import "ETLayoutItemGroup+Private.h"
#import "ETLayoutItem+KVO.h"
#import "ETLayoutItem+Private.h"
#import "ETLayoutItem+Scrollable.h"
#import "ETLayoutExecutor.h"
#import "ETPositionalLayout.h"
#import "EtoileUIProperties.h"
#import "ETScrollableAreaItem.h"
#import "ETStyleGroup.h"
#import "ETView.h"
#import "ETUIObject.h"
#import "ETUIItemIntegration.h"
#import "ETWidget.h"
#import "ETWindowItem.h"
#import "ETUIItemCellIntegration.h"
#import "NSImage+Etoile.h"
#import "NSObject+EtoileUI.h"
#import "NSView+EtoileUI.h"
#import "ETCompatibility.h"

/* Notifications */
NSString *ETLayoutItemLayoutDidChangeNotification = @"ETLayoutItemLayoutDidChangeNotification";

#define DETAILED_DESCRIPTION

@interface NSView (NSControlSubclassNotifications)
- (void) setDelegate: (id)aDelegate;
@end

@interface ETLayoutItem (Private) <ETWidget>
- (void) setViewAndSync: (NSView *)newView;
@property (nonatomic, readonly) NSRect bounds;
- (void) setBoundsSize: (NSSize)size;
@property (nonatomic, readonly) NSPoint centeredAnchorPoint;
@end

@implementation ETLayoutItem

@dynamic boundingInsets, hostItem;

static BOOL showsViewItemMarker = NO;
static BOOL showsBoundingBox = NO;
static BOOL showsFrame = NO;

/** Returns whether the bounding box is drawn.

When YES, the receiver draws its bounding box as a red stroked rect. */
+ (BOOL) showsBoundingBox
{
	return showsBoundingBox;
}

/** Sets whether the bounding box is drawn.

See also -showsBoundingBox. */
+ (void) setShowsBoundingBox: (BOOL)shows
{
	showsBoundingBox = shows;
}

/** Returns whether the frame is drawn.

When YES, the receiver draws its frame as a blue stroked rect. */
+ (BOOL) showsFrame
{
	return showsFrame;
}

/** Sets whether the frame is drawn.

See also -showsFrame. */
+ (void) setShowsFrame: (BOOL)shows
{
	showsFrame = shows;
}

static NSInteger autolayoutEnabled = 0;

/** Returns whether automatic layout updates are enabled. 

If YES, items on which -setNeedsLayoutUpdate was invoked, will receive 
-updateLayoutRecursively: in the interval between the current event and the 
next event.<br />
	
By default, returns YES to eliminate the need to use -updateLayout. */
+ (BOOL) isAutolayoutEnabled;
{
	return (autolayoutEnabled == 0);
}

/** Enables automatic layout updates in the interval between the current event 
and the next event. 

See also +disablesAutolayout. */
+ (void) enablesAutolayout;
{
	autolayoutEnabled--;
}

/** Disables automatic layout updates in the interval between the current event 
and the next event.

EtoileUI also stops to track items that need a layout update. So 
-setNeedsLayoutUpdate does nothing then, the method returns immediately.

Before the next event, +enablesAutolayout can be called to entirely cancel 
+disablesAutolayoutIncludingNeedsUpdate:.<br />
You can nest these method invocations, but automatic layout won't be restored 
until +enablesAutolayout has been called the same number of times than 
+disablesAutolayoutIncludingNeedsUpdate:.

See also +enablesAutolayout. */
+ (void) disablesAutolayout
{
	autolayoutEnabled++;
}

/* Initialization */

/** You must use -[ETLayoutItemFactory item] or -[ETLayoutItemFactory itemGroup] 
rather than this method.

Initializes and returns a layout item.

The returned item will use +defaultItemRect as its frame. */
- (instancetype) initWithObjectGraphContext: (COObjectGraphContext *)aContext
{
	return [self initWithView: nil 
	               coverStyle: [ETBasicItemStyle sharedInstanceForObjectGraphContext: aContext]
	            actionHandler: [ETActionHandler sharedInstanceForObjectGraphContext: aContext]
	       objectGraphContext: aContext];
}

/* Falls back on a transient object graph context to support items as top-level 
objects in a Nib.

Beside this Nib support, this initializer must never be called directly. */
- (instancetype) init
{
	return [self initWithObjectGraphContext: [ETUIObject defaultTransientObjectGraphContext]];
}

- (void) prepareTransientState
{
	_defaultValues = [[NSMutableDictionary alloc] init];
}

/** <init />
You must use -[ETLayoutItemFactory itemXXX] or 
-[ETLayoutItemFactory itemGroupXXX] methods rather than this method.

Initializes and returns a layout item with the given view, cover style and 
action handler.

Any of the arguments can be nil.

When the given view is nil, the returned item will use +defaultItemRect as its 
frame.

See also -setView:, -setCoverStyle: and -setActionHandler:.  */
- (instancetype) initWithView: (NSView *)view 
         coverStyle: (ETStyle *)aStyle 
      actionHandler: (ETActionHandler *)aHandler
 objectGraphContext: (COObjectGraphContext *)aContext
{
    self = [super initWithObjectGraphContext: aContext];
	if (self == nil)
		return nil;

	[self prepareTransientState];

	// NOTE: -[COObject newVariableStorage] instantiates the value transformers
	_styleGroup = [[ETStyleGroup alloc] initWithObjectGraphContext: aContext];
	[self setCoverStyle: aStyle];
	[self setActionHandler: aHandler];

	_transform = [NSAffineTransform transform];
	 /* Will be overriden by -setView: when the view is not nil */
	_autoresizingMask = NSViewNotSizable;
	_contentAspect = ETContentAspectStretchToFill;
	_boundingInsetsRect = NSMakeRect(0, 0, 0, 0);
	_minSize = NSZeroSize;
	_maxSize = NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX);

	NSRect frame = (nil != view ? [view frame] : [[self class] defaultItemRect]);
	/* We must have a valid frame to use -setDefaultFrame:, otherwise this 
	   method will look up an invalid frame and try to restore it. */
	[self setFrame: frame];
	[self setDefaultFrame: frame];
	[self setViewAndSync: view];

	_selectable = YES;
	[self setFlipped: YES]; /* -setFlipped: must follow -setSupervisorView: */

    return self;
}

/** <override-dummy />
Removes the receiver as an observer on all objects that it was observing until 
now.

You must override this method when a subclass calls KVO methods such as 
-addObserver:XXX. In the overriden method, you must call the superclass 
implementation.<br />
You must never call this method in your own code.

In -dealloc, we must stop to be a KVO observer immediately, otherwise we may 
receive KVO notifications triggered by releasing objects we observe. In the 
worst case, we can be retained/released and thereby reenter -dealloc. */
- (void) stopKVOObservation
{
	[self endObserveObject: _representedObject];

	NSView *view = [self view];

	if (nil != view && [view isWidget])
	{
		[[(id <ETWidget>)view cell] removeObserver: self forKeyPath: @"objectValue"];
		[[(id <ETWidget>)view cell] removeObserver: self forKeyPath: @"state"];
	}
}

- (void)willDiscard
{
	ETAssert(_deserializationState == nil || [_deserializationState isEmpty]);

	/* Prevent adding the item back to the layout executor */
	_isDeallocating = YES;
	[self stopKVOObservation];

	[super willDiscard];
}

- (NSString *) description
{
	if ([self isZombie])
		return [super description];

	NSString *desc = [self primitiveDescription];

#ifdef DETAILED_DESCRIPTION	
	desc = [@"<" stringByAppendingFormat: @"%@ id: %@, "
		@"selected: %d, repobject: %@ view: %@ frame %@>", desc, 
		[self identifier], [self isSelected],
		[[self representedObject] primitiveDescription], [self view], 
		NSStringFromRect([self frame])];
#else
	desc = [@"<" stringByAppendingFormat: @"%@ id: %@, selected:%d>", 
		desc, [self identifier], [self isSelected]];
#endif
	
	return desc;
}

- (NSString *) shortDescription
{
	return [@"<" stringByAppendingFormat: @"%@ id: %@, selected: %d, repObject: %@ "
		@"view: %@ frame: %@>", [super description], [self identifier], [self isSelected],
		[[self representedObject] primitiveDescription], [[self view] primitiveDescription],
		NSStringFromRect([self frame])];
}

/** Returns the root item of the layout item tree to which the receiver belongs 
to. 

This method never returns nil. The returned value is equal to self when the 
receiver has no parent item. */
- (id) rootItem
{
	if ([self parentItem] != nil)
	{
		return [[self parentItem] rootItem];	
	}
	else
	{
		return self;
	}
}

/** Returns the first ancestor item group which is bound to a source object.

For the entire item subtree under its control (until a descendant becomes
another source item), the source item will drive the model access either through:

<list>
<item>each descendant item represented object with the collection protocols</item>
<item>the source protocol and the source object directly</item>
</list>

An item group is automatically turned into a source item, when you set a source, 
see -[ETLayoutItemGroup setSource:].

This method will return nil when the receiver isn't a source item or has no
ancestor which is a source item.
 
See also -source and -controllerItem. */
- (ETLayoutItemGroup *) sourceItem
{
	return [[self parentItem] sourceItem];
}

/** Returns the first ancestor item group which is bound to a controller.

For the entire item subtree under its control (until a descendant becomes
another source item), the controller will drive:
 
<list>
<item>pick and drop validation</item>
<item>sorting</item>
<item>filtering</item>
</list>

An item group is automatically turned into a controller item, when you set a
a controller, see -[ETLayoutItemGroup setController:].

This method will return nil when the receiver isn't a controller item or has no
ancestor which is a controller item.

See ETController and ETPickAndDropActionHandler. */
- (ETLayoutItemGroup *) controllerItem
{
	return [[self parentItem] controllerItem];
}

- (ETLayoutItemGroup *) parentItem
{
    ETLayoutItemGroup *parent = [self valueForVariableStorageKey: kETParentItemProperty];

    return (parent != nil ? parent : [self hostItem]);
}

/** Detaches the receiver from the item group it belongs to.

You are in charge of retaining the receiver, otherwise it could be deallocated 
if no other objects retains it. */
- (void) removeFromParent
{
	if ([self parentItem] != nil)
	{
		[[self parentItem] removeItem: self];
	}
}

/** Returns the first layout item bound to a view upwards in the layout item 
tree. 

The receiver itself can be returned. */
- (ETLayoutItem *) supervisorViewBackedAncestorItem
{
	if ([self displayView] != nil)
		return self;

	if ([self parentItem] != nil)
	{
		return [[self parentItem] supervisorViewBackedAncestorItem];
	}
	else
	{
		return nil;
	}
}

/** Returns the first display view bound to a layout item upwards in the layout 
item tree. This item is identical to the one returned by 
-supervisorViewBackedAncestorItem. 

The receiver display view itself can be returned. */
- (ETView *) enclosingDisplayView
{
	ETView *displayView = [self displayView];

	if (displayView != nil)
		return displayView;

	if ([self parentItem] != nil)
	{
		return [[self parentItem] enclosingDisplayView];
	}
	else
	{
		return nil;
	}
}

/** Returns the first layout item decorated by a window upwards in the layout 
item tree. 

The receiver itself can be returned. */
- (id) windowBackedAncestorItem
{
	NSWindow *window = [[[self supervisorViewBackedAncestorItem] supervisorView] window];

	if (nil == window)
		return nil;

	// FIXME: Should be ok to use (but not with ObjectManagerExample... we have 
	// need to turn the window into a window item sooner to eliminate the crash 
	//in -awakeFromNib)
	//NSParameterAssert([[window contentView] isSupervisorView]);
	if ([[window contentView] isSupervisorView] == NO)
		return nil;

	return [[[window contentView] layoutItem] firstDecoratedItem];
}

/** Returns receiver index path relative to the given item. 

The index path is computed by climbing up the layout item tree until we 
find the given item. At each level we traverse, the parent relative index is 
pushed into the index path to be returned. 

Passing nil is equivalent to passing the root item.<br />
If the given item is equal to self, the resulting index path is a blank one 
(relative to itself). */
- (NSIndexPath *) indexPathFromItem: (ETLayoutItem *)item
{
	NSIndexPath *indexPath = nil;
	BOOL baseItemReached = (self == item);

	/* Handle nil item case which implies root item is the base item */
	if (item == nil && self == [self rootItem])
		baseItemReached = YES;
	
	if ([self parentItem] != nil && item != self)
	{
		indexPath = [[self parentItem] indexPathFromItem: item];
		if (indexPath != nil)
		{
			indexPath = [indexPath indexPathByAddingIndex: 
				[(ETLayoutItemGroup *)[self parentItem] indexOfItem: (id)self]];
		}
	}
	else if (baseItemReached)
	{
		indexPath = [NSIndexPath indexPath];
	}

	/* We return a nil index path only if we haven't reached the base item */   	
	return indexPath;
}

/** Returns the given item index path relative to the receiver.

This method is equivalent to [item indexFromItem: self].

Returns nil when the given item isn't a receiver descendant.

Passing nil is equivalent to passing the root item. In this case, the returned 
value is nil because the root item can never be a receiver descendant.<br />
If the given item is equal to self, the resulting index path is an blank one 
(relative to itself). */
- (NSIndexPath *) indexPathForItem: (ETLayoutItem *)item
{
	return [item indexPathFromItem: self];
}

/** Returns the identifier associated with the layout item.

The returned value can be nil or an empty string. */
- (NSString *) identifier
{
	return [self valueForVariableStorageKey: kETIdentifierProperty];
}

/** Sets the identifier associated with the layout item. */
- (void) setIdentifier: (NSString *)anId
{
	[self willChangeValueForProperty: kETIdentifierProperty];	
	[self setValue: anId forVariableStorageKey: kETIdentifierProperty];
	[self didChangeValueForProperty: kETIdentifierProperty];	
}

/** Returns -name when a name is set, otherwise the display name of the
represented object, and in last resort a succinct description of the item.
 
See also NSObject(Model) in EtoileFoundation. */
- (NSString *) displayName
{
	id name = [self name];
	
	if (name != nil)
	{
		return name;
	}
	else if ([self representedObject] != nil)
	{
		/* Makes possible to keep an identical display name between an item and 
		   all derived meta items (independently of their meta levels). */
		return [[self representedObject] displayName];
	}
	else
	{
		return [self primitiveDescription];
	}
}

/** Sets the name associated with the receiver with -setName:. */
- (void) setDisplayName: (NSString *)aName
{
	[self setName: aName];
}

/** Returns the name associated with the layout item.
 
The returned value can be nil or an empty string. */
- (NSString *) name
{
	return [self valueForVariableStorageKey: kETNameProperty];
}

/** Sets the name associated with the layout item. */
- (void) setName: (NSString *)name
{
	[self willChangeValueForProperty: kETNameProperty];
	[self setValue: name forVariableStorageKey: kETNameProperty];
	[self didChangeValueForProperty: kETNameProperty];	
}

- (BOOL) isViewpoint: (id)anObject
{
	return [anObject conformsToProtocol: @protocol(ETViewpoint)];
}

- (BOOL) isPropertyViewpoint: (id)anObject
{
	return [anObject conformsToProtocol: @protocol(ETPropertyViewpoint)];
}

/** Sets a value key to describe which property of the represented object is 
exposed through -value and -setValue:. */
- (id) valueKey
{
	BOOL usesViewpoint = [self isPropertyViewpoint: [self representedObject]];
	return (usesViewpoint ? [[self representedObject] name] : nil);
}

- (Class) viewpointClassForProperty: (NSString *)aKey ofObject: (id)anObject
{
	Class viewpointClass = [[[anObject class] ifResponds] mutableViewpointClass];
	return (viewpointClass != Nil ? viewpointClass : [ETMutableObjectViewpoint class]);
}

/** Returns a value key to describe which property of the represented object is
exposed through -value and -setValue:. */
- (void) setValueKey: (NSString *)aKey
{
	[self willChangeValueForProperty: kETValueKeyProperty];

	id representedObject = nil;
	
	if (aKey != nil)
	{
		Class viewpointClass = [self viewpointClassForProperty: aKey
		                                              ofObject: [self representedObject]];
		representedObject = [viewpointClass viewpointWithName: aKey
		                                    representedObject: [self representedObject]];
	}
	else if ([self isViewpoint: [self representedObject]])
	{
		representedObject = [(id <ETViewpoint>)[self representedObject] representedObject];
	}
	
	[self setRepresentedObject: representedObject];

	[self didChangeValueForProperty: kETValueKeyProperty];
}

/** Returns a value object based on -valueKey.

The method returns the result of -valueForProperty: for the value key.
For a nil value key, the represented object is returned (without resorting to 
-valueForProperty:).
 
If the represented object is a viewpoint, then the viewpoint value is returned 
rather than returning the item represented object. See -[ETPropertyViewpoint value:].
 
For items that presents a single property in the UI, using -value and -valueKey 
is a good choice. For example, a text field or a slider presenting a 
common object value or a property belonging to the represent object.
 
See also -setValue:. */
- (id) value
{
	if ([self isViewpoint: [self representedObject]])
	{
		return [[self representedObject] value];
	}
	else
	{
		return [self representedObject];
	}
}

/** Sets a value object based on -valueKey.

The method uses -setValue:forProperty: to set the value object for the value key.
For a nil value key, the represented object is set (without resorting to 
-setValue:forProperty:). See -setRepresentedObject.
 
If the represented object is a viewpoint, then the viewpoint value is set rather 
than setting the item represented object. See -[ETPropertyViewpoint setValue:].
 
Styles or layouts can use it to show the receiver with a basic value 
representation or when they restrict their presentation to a single property.<br />
e.g. a table layout with a single column, or a positional layout letting items  
draw their value through ETBasicItemStyle. To know how the value can be presented, 
see ETLayout and ETStyle subclasses.

If -valueKey is not nil and the represented object declares a property 'value', 
both <code>[receiver valueForProperty: @"value"]</code> and 
<code>[receiver setValue: anObject forProperty: @"value"]</code> access the 
receiver value and not the one provided by the represented object, as usually 
expected for -valueForProperty: and -setValue:forProperty:.
 
See also -value. */
- (void) setValue: (id)value
{
	if ([self isViewpoint: [self representedObject]])
	{
		[[self representedObject] setValue: value];
	}
	else
	{
		[self setRepresentedObject: value];
	}
}

/** Returns the model object which embeds the data to be displayed and 
represented on screen by the receiver. See also -setRepresentedObject:. */
- (id) representedObject
{
	return _representedObject;
}

/** Returns the represented object when not nil, otherwise returns the receiver.

You shouldn't have to use this method a lot since -valueForProperty: and 
-setValue:forProperty: make the property access transparent. For example 
[self valueForProperty: kNameProperty] is equivalent to [[self subject] name].

-subject can be useful with KVC which only considers the layout item itself. e.g. 
[itemCollection valueForKey: @"subject.name"].  */
- (id) subject
{
	return (nil != _representedObject ? _representedObject : (id)self);
}

/** Returns whether the value is ETLayoutItem object or not.
 
See also -value, -valueKey and -representedObject. */
- (BOOL) isMetaItem
{
	return ([[self value] isKindOfClass: [ETLayoutItem class]]);
}

/* -value is not implemented by every object unlike -objectValue which is implemented
by NSObject+Model in EtoileFoundation. */
- (void) syncView: (NSView *)aView withValue: (id)newValue
{
	if ([self representedObject] == nil || aView == nil || [aView isWidget] == NO)
		return;

	NSCell *cell = [(id <ETWidget>)aView cell];

	/* For instance, -[NSScrollView cell] returns nil */
	if (cell == nil)
		return;

	//ETLog(@"Got object value %@ for %@", [[cell objectValueForObject: newValue] class], [newValue class]);
	
	[(id <ETWidget>)aView setObjectValue: [(id <ETWidget>)aView objectValueForCurrentValue: newValue]];
}

/** Sets the model object which embeds the data to be displayed and represented 
on screen by the receiver.

Take note modelObject can be any objects including an ETLayoutItem instance, in 
this case the receiver becomes a meta item and returns YES for -isMetaItem.

The item view is also synchronized with the object value of the given represented 
object when the view is a widget. */
- (void) setRepresentedObject: (id)modelObject
{
	id oldObject = _representedObject;

	_isSettingRepresentedObject = YES;
	[self endObserveObject: _representedObject];

	[self willChangeValueForProperty: kETRepresentedObjectProperty];
	NSSet *affectedKeys = [self willChangeRepresentedObjectFrom: oldObject 
	                                                         to: modelObject];
	_representedObject = modelObject;

	/* Affected keys contain represented object properties, and the Core object 
	   editing context must not be notified about these, otherwise identically 
	   named ETLayoutItem properties would uselessly persisted when they haven't 
	   changed (e.g. icon).
	   For these represented object properties and derived item properties 
	   (e.g. icon), we use -didChangeValuesForKeys: to post pure KVO 
	   notifications.   */
	[self didChangeValuesForKeys: affectedKeys];
	[self didChangeValueForProperty: kETRepresentedObjectProperty];

	/* Don't pass -value otherwise -[representedObject value] is not retrieved 
	   if -valueKey is nil (for example, ETPropertyViewpoint implements -value). */
	[self syncView: [self view] withValue: [self valueForProperty: kETValueProperty]];
	[self startObserveObject: modelObject];
	_isSettingRepresentedObject = NO;
}

/* This method is never called once a decorator is set (setting it triggers 
the supervisor view creation), except when an object graph loading is underway, 
see -[ETLayoutItem awakeFromDeserialization]. */
- (ETView *) setUpSupervisorView
{
	if (supervisorView != nil)
		return supervisorView;

	[self setSupervisorView: [ETView new]
	                   sync: ETSyncSupervisorViewFromItem];
	return supervisorView;
}

- (unsigned int) autoresizingMaskForContentAspect: (ETContentAspect)anAspect
{
	switch (anAspect)
	{
		case ETContentAspectNone:
		case ETContentAspectComputed:
		{
			return ETAutoresizingNone;
		}
		case ETContentAspectCentered:
		{
			return ETAutoresizingFlexibleLeftMargin | ETAutoresizingFlexibleRightMargin 
				| ETAutoresizingFlexibleBottomMargin | ETAutoresizingFlexibleTopMargin;
		}
		case ETContentAspectScaleToFill:
		case ETContentAspectScaleToFillHorizontally:
		case ETContentAspectScaleToFillVertically:
		case ETContentAspectScaleToFit:
		{
			// TODO: May be return ETAutoresizingCustom or ETAutoresizingProportional
			return ETAutoresizingNone;		
		}
		case ETContentAspectStretchToFill:
		{
			return ETAutoresizingFlexibleWidth | ETAutoresizingFlexibleHeight;
		}
		default:
		{
			ASSERT_INVALID_CASE;
			return ETAutoresizingNone;
		}
	}
}

- (NSRect) contentRectWithRect: (NSRect)aRect 
                 contentAspect: (ETContentAspect)anAspect 
                    boundsSize: (NSSize)maxSize
{
	switch (anAspect)
	{
		case ETContentAspectNone:
		{
			return aRect;
		}
		case ETContentAspectCentered:
		{
			return ETCenteredRect(aRect.size, ETMakeRect(NSZeroPoint, maxSize));
		}
		case ETContentAspectComputed:
		{
			return [[self coverStyle] rectForViewOfItem: self];
		}
		case ETContentAspectScaleToFill:
		case ETContentAspectScaleToFillHorizontally:
		case ETContentAspectScaleToFillVertically:
		case ETContentAspectScaleToFit:
		{
			return ETScaledRect(aRect.size, ETMakeRect(NSZeroPoint, maxSize), anAspect);	
		}
		case ETContentAspectStretchToFill:
		{
			return ETMakeRect(NSZeroPoint, maxSize);
		}
		default:
		{
			ASSERT_INVALID_CASE;
			return ETNullRect;
		}
	}
}

/** Tries to resize the item view with -sizeToFit, then adjusts the receiver 
content size to match the view size. */
- (void) sizeToFit
{
	ETContentAspect contentAspect = [self contentAspect];
	NSView *view = [self view];
	NSSize imgOrViewSize = NSZeroSize;

	if (view != nil)
	{
		/* To prevent -setContentSize: to resize the view when it resizes the 
		   supervisor view. */
		[self setContentAspect: ETContentAspectNone];
		[[[self view] ifResponds] sizeToFit];
		[self setContentSize: [view frame].size];
		[self setContentAspect: contentAspect];

		imgOrViewSize = [[self view] frame].size;
	}
	else if ([self icon] != nil)
	{
		imgOrViewSize = [[self icon] size];
	}
	else
	{
		return;
	}

	[self setWidth: [[self coverStyle] boundingSizeForItem: self
	                                       imageOrViewSize: imgOrViewSize].width];
}

/** Returns the view associated with the receiver.

The view is an NSView class or subclass instance. See -setView:. */
- (id) view
{
	return [[self supervisorView] wrappedView];
}

	/* When the view isn't an ETView instance, we wrap it inside a new ETView 
	   instance to have -drawRect: asking the layout item to render by itself.
	   Retrieving the display view automatically returns the innermost display
	   view in the decorator item chain. */
- (void) setView: (NSView *)newView autoresizingMask: (ETAutoresizing)autoresizing
{
	NSView *oldView = [supervisorView wrappedView];
	BOOL stopObservingOldView = (nil != oldView && [oldView isWidget]);
	BOOL startObservingNewView = (nil != newView && [newView isWidget]);

	[self willChangeValueForProperty: kETViewProperty];

	if (stopObservingOldView)
	{
		[[(id <ETWidget>)oldView cell] removeObserver: self forKeyPath: @"objectValue"];
		[[(id <ETWidget>)oldView cell] removeObserver: self forKeyPath: @"state"];
		[[oldView ifResponds] setDelegate: nil];
	}

	/* Insert a supervisor view if needed and adjust the new view autoresizing behavior */
	if (nil != newView)
	{
		[self setUpSupervisorView];
		NSParameterAssert(NSEqualSizes([self contentBounds].size, [supervisorView frame].size));

		[newView setAutoresizingMask: autoresizing];
		/* The view frame will be adjusted by -[ETView tileContentView:temporary:]
		   which invokes -contentRectWithRect:contentAspect:boundsSize:. */
	}

	[supervisorView setWrappedView: newView];
	[self syncView: newView withValue: [self valueForProperty: kETValueProperty]];

	if (startObservingNewView)
	{
		NSUInteger options = (NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew);
		[[(id <ETWidget>)newView cell] addObserver: self 
		                                forKeyPath: @"objectValue"
		                                   options: options
	                                       context: NULL];
		[[(id <ETWidget>)newView cell] addObserver: self 
		                                forKeyPath: @"state"
		                                   options: options
		                                   context: NULL];
        /* For text editing notifications posted by NSControl subclasses such as NSTextField */
		[(NSView *)[newView ifResponds] setDelegate: self];
	}

	[self didChangeValueForProperty: kETViewProperty];
}

/** Sets the view associated with the receiver. This view is commonly a widget 
provided by the widget backend. 

The receiver autoresizing mask will be updated to match the given view, and 
the default frame and frame to match this view frame. */
- (void) setViewAndSync: (NSView *)newView
{
	if (newView != nil)
	{
		// NOTE: Frame and autoresizing are lost when newView is inserted into the 
		// supervisor view.
		NSRect newViewFrame = [newView frame];

		[self setUpSupervisorView];
		NSParameterAssert(nil != [self supervisorView]);

		[self setContentAspect: ETContentAspectStretchToFill];
		[self setDefaultFrame: newViewFrame];
		[self setAutoresizingMask: [newView autoresizingMask]];
	}
	[self setView: newView autoresizingMask: [self autoresizingMaskForContentAspect: [self contentAspect]]];
}

/** Sets the view associated with the receiver. This view is commonly a widget 
provided by the widget backend.

If a view is set, the target and action set on the receiver are lost, see
-target and -action. */
- (void) setView: (NSView *)newView
{
	[self setView: newView autoresizingMask: [self autoresizingMaskForContentAspect: [self contentAspect]]];
}

/** Returns whether the view used by the receiver is a widget. 

Also returns YES when the receiver uses a layout view which is a widget 
provided by the widget backend. See -[ETLayout isWidget].

See also -[NSView(Etoile) isWidget]. */
- (BOOL) usesWidgetView
{
	// NOTE: The next line would work too...
	//return ([self view] != nil || [[[self layout] layoutView] isWidget]);
	return ([[self view] isWidget] || [[self layout] isWidget]);
}

/** Returns a widget proxy for target/action and value related settings.
 
You should use this proxy to control the widget settings rather than setting 
them directly on the view.

If -view is nil, the widget proxy holds the settings for the item. You can use 
-widget to access these settings in an action handler or a cover style (for 
example, if you are implementing a new widget using custom ETStyle and 
ETActionHandler objects without resorting to a widget from the backend). */
- (id <ETWidget>) widget
{
	return self;
}

/* Key Value Coding */

- (id) valueForUndefinedKey: (NSString *)key
{
	//ETLog(@"NOTE: -valueForUndefinedKey: %@ called in %@", key, self);
	return [self valueForVariableStorageKey: key]; /* May return nil */
}

- (void) setValue: (id)value forUndefinedKey: (NSString *)key
{
	//ETLog(@"NOTE: -setValue:forUndefinedKey: %@ called in %@", key, self);
	[self willChangeValueForProperty: key];
	[self setValue: value forVariableStorageKey: key];
	[self didChangeValueForProperty: key];
}

/* Property Value Coding */


/** Returns YES.
 
See -[ETPropertyValueCoding requiresKeyValueCodingForAccessingProperties]. */
- (BOOL) requiresKeyValueCodingForAccessingProperties
{
	return YES;
}

/** Returns a value of the model object -representedObject, usually by calling
-valueForProperty: on the represented object. If the represented object is a 
layout item, -valueForKey: will be  called instead of -valueForProperty:. 

-valueForProperty: is implemented by NSObject as part of the 
ETPropertyValueCoding informal protocol. When the represented object is a custom 
model object, it must override -valueForProperty: and -setValue:forProperty: or 
conform to NSKeyValueCoding protocol. See ETPropertyValueCoding to understand 
how to implement your model object.

When the represented object is a layout item, the receiver is a meta layout item 
(see -isMetaItem and -[NSObject(ETLayoutItem) isLayoutItem]). */
- (id) valueForProperty: (NSString *)key
{
	NILARG_EXCEPTION_TEST(key);
	id modelObject = [self representedObject];
	id value = nil;

	/* If the represented object declares no 'value' property, then the returned 
	   value is the represented object. For a string set as the value or 
	   represented object, -[ETLayoutItem valueForProperty: @"value"] 
	   evaluates to -[ETLayoutItem value]. */
	if ([[(id)modelObject propertyNames] containsObject: key])
	{
		if ([modelObject isLayoutItem])
		{
			value = [modelObject valueForKey: key];
		}
		else
		{
			/* We  cannot use -valueForKey here because many classes such as 
			   NSArray, NSDictionary etc. overrides KVC accessors with their own 
			   semantic. */
			value = [modelObject valueForProperty: key];
		}
	}
	else
	{
		value = [self valueForKey: key];
	}

	ETItemValueTransformer *transformer = [self valueTransformerForProperty: key];

	return (transformer == nil ? value : [transformer transformedValue: value
	                                                            forKey: key
	                                                            ofItem: self]);
}

/** Sets a value identified by key of the model object returned by 
-representedObject. 

See -valueForProperty: for more details. */
- (BOOL) setValue: (id)value forProperty: (NSString *)key
{
	NILARG_EXCEPTION_TEST(key);
	id modelObject = [self representedObject];
	id convertedValue = value;
	ETItemValueTransformer *transformer = [self valueTransformerForProperty: key];
	BOOL result = YES;

	/* If the key is 'value', the method is reentered through -setValue: so 
	   the value transformer will be look up for both 'value' and the value key. */
	if (transformer != nil)
	{
		NSString *editedKey = ([key isEqual: kETValueProperty] ? [self valueKey] : key);
		ETAssert(editedKey != nil);
		convertedValue = [transformer reverseTransformedValue: value
		                                               forKey: editedKey
	                                                   ofItem: self];
	}

	if ([[(NSObject *)modelObject propertyNames] containsObject: key])
	{
		if ([modelObject isLayoutItem])
		{
			[modelObject setValue: convertedValue forKey: key];
		}
		else
		{
			/* We  cannot use -setValue:forKey here because many classes such as 
			   NSArray, NSDictionary etc. overrides KVC accessors with their own 
			   semantic. */
			result = [modelObject setValue: convertedValue forProperty: key];
		}
	}
	else
	{
		[self setValue: convertedValue forKey: key];
	}

	return result;
}

/** Returns the value transformer registered for the given property. 

-valueForProperty: converts the value just before returning it by using 
-[ETItemValueTransformer transformValue:forKey:ofItem:] if a transformer is 
registered for the property.
 
-setValue:forProperty: converts the value just before returning it by using 
-[ETItemValueTransformer receverTransformValue:forKey:ofItem:] if a transformer 
is registered for the property.*/
- (ETItemValueTransformer *) valueTransformerForProperty: (NSString *)key
{
	ETItemValueTransformer *transformer = [self valueForVariableStorageKey: @"valueTransformers"][key];
	ETAssert(transformer == nil || [transformer isKindOfClass: [ETItemValueTransformer class]]);
	return transformer;
}

/** Registers the value transformer for the given property.

If the value transformer is nil, it is unregistered.

For a nil key, raises a NSInvalidArgumentException.

See also -valueTransformerForProperty:. */
- (void) setValueTransformer: (ETItemValueTransformer *)aValueTransformer
                 forProperty: (NSString *)key;
{
	NILARG_EXCEPTION_TEST(key);

	NSMutableDictionary *transformers = [self valueForVariableStorageKey: @"valueTransformers"];
	ETAssert([ETItemValueTransformer valueTransformerForName: [aValueTransformer name]] == aValueTransformer);
	
	[self willChangeValueForProperty: @"valueTransformers"
	                       atIndexes: [NSIndexSet indexSet]
	                     withObjects: @[aValueTransformer]
	                    mutationKind: ETCollectionMutationKindInsertion];

	transformers[key] = aValueTransformer;

	[self didChangeValueForProperty: @"valueTransformers"
	                      atIndexes: [NSIndexSet indexSet]
	                    withObjects: @[aValueTransformer]
	                   mutationKind: ETCollectionMutationKindInsertion];
}

/** Returns YES, see [NSObject(EtoileUI) -isLayoutItem] */
- (BOOL) isLayoutItem
{
	return YES;
}

/** Returns NO, see -[ETLayoutItemGroup isGroup] */
- (BOOL) isGroup
{
	return NO;
}

/** Sets the receiver selection state.

You rarely need to call this method. You should rather use -setSelectionIndex:, 
-setSelectionIndexes: or -setSelectionIndexPaths: on the parent item (see 
ETLayoutItemGroup).

This method doesn't post an ETItemGroupSelectionDidChangeNotification unlike 
the previously mentioned ETLayoutItemGroup methods.

The new selection state won't be apparent until a redisplay occurs.

If -isSelectable returns NO, the new selection state is not set. */
- (void) setSelected: (BOOL)selected
{
	if (selected == _selected || [self isSelectable] == NO)
		return;

	[self willChangeValueForKey: kETSelectedProperty];
	_selected = selected;
	ETDebugLog(@"Set layout item selection state %@", self);
	[self didChangeValueForKey: kETSelectedProperty];
}

/** Returns the receiver selection state. See also -setSelected:. */
- (BOOL) isSelected
{
	return _selected;
}

/** Sets whether the receiver can be selected.

If selectable is NO, resets the <em>selected</em> property to NO.

Layouts can customize the item appearance based on -isSelectable. For instance, 
ETTableLayout or ETOutlineLayout turn such items into group rows.

See also -setSelected, -isSelected and -isSelectable. */
- (void) setSelectable: (BOOL)selectable
{
	if (selectable == _selectable)
		return;

	[self willChangeValueForKey: kETSelectableProperty];
	_selectable = selectable;
	if (selectable == NO)
	{
		[self setSelected: NO];
	}
	[self didChangeValueForKey: kETSelectableProperty];
}

/** Returns whether the receiver can be selected. 

By default, returns YES.

See also -setSelectable:. */
- (BOOL) isSelectable
{
	return _selectable;
}

- (BOOL) canBecomeVisible
{
	return ([[self layout] isOpaque] == NO);
}

/** Sets whether the receiver should be displayed or not.
 
The new visibility state won't be apparent until a redisplay occurs.
 
This method marks the receiver as needing a redisplay.

When -isHidden returns YES, -isVisible returns YES. However -isVisible can
return YES, while -isHidden returns NO. */
- (void) setHidden: (BOOL)hidden
{
	if (_hidden == hidden)
		return;

	[self willChangeValueForProperty: kETHiddenProperty];
	_hidden = hidden;
	[self setNeedsDisplay: YES];
	[self willChangeValueForProperty: kETHiddenProperty];
}

/** Returns whether the receiver should be displayed or not. 
 
See also -setHidden: and -isVisible:. */
- (BOOL) isHidden
{
	return _hidden;
}

/** Sets whether the receiver should be displayed or not.

The new visibility state won't be apparent until a redisplay occurs.
 
This method doesn't mark the receiver as needing a redisplay.

You must never call this method, but use -[ETLayoutItemGroup setExposedItems:]
which updates the visibility of item views.
 
See also -exposed. */
- (void) setExposed: (BOOL)exposed
{
	if (_exposed == exposed)
		return;

	[self willChangeValueForProperty: kETExposedProperty];
	_exposed = exposed;
	[self willChangeValueForProperty: kETExposedProperty];
}

/** Returns whether the receiver should be displayed or not.
 
See also -setExposed: and -exposedItems. */
- (BOOL) isExposed
{
	return _exposed;
}

/** Returns whether the receiver is displayed or not.

For an invisible item, descendant items are invisible, whether or not they
return YES to -isVisible.

An invisible item doesn't participate in the responder chain, and is ignored by
the active tool during the event hit testing.

Layouts can change the visibility state with -[ETLayoutItemGroup setExposedItems:], 
whether or not the item is hidden.
 
See also -isHidden, -setHidden: and ETTool. */
- (BOOL) isVisible
{
	return (_exposed && _hidden == NO);
}

/** Returns the receiver UTI type as -[NSObject UTI], but combines it with the
subtype and the represented object type when available.

When the receiver has a subtype, the returned type is a transient type whose 
supertypes are the class type and the subtype.<br />
When the receiver has a represented object, the returned type is a transient 
type whose supertypes are the class type and the represented object class type.<br />
In case, the receiver has both a represented object and a subtype, the 
returned type will combine both as supertypes. */
- (ETUTI *) UTI
{
	ETUTI *subtype = [self subtype];
	NSMutableArray *supertypes = [NSMutableArray arrayWithObject: [super UTI]];

	if (subtype != nil)
	{
		[supertypes addObject: subtype];
	}
	if (_representedObject != nil)
	{
		[supertypes addObject: [_representedObject UTI]];
	}

	return [ETUTI transientTypeWithSupertypes: supertypes];
}

/** Sets the receiver subtype.

This method can be used to subtype an object (without involving any subclassing).

You can use it to restrict pick and drop allowed types to the receiver type, 
when the receiver is a "pure UI object" without a represented object bound to it. */
- (void) setSubtype: (ETUTI *)aUTI
{
	/* Check type aggressively in case the user passes a string */
	NSParameterAssert([aUTI isKindOfClass: [ETUTI class]]);
	[self willChangeValueForProperty: kETSubtypeProperty];
	[self setValue: aUTI forVariableStorageKey: kETSubtypeProperty];
	[self didChangeValueForProperty: kETSubtypeProperty];
}

/** Returns the receiver subtype.

More explanations in -setSubtype. See also -type. */
- (ETUTI *) subtype
{
	return [self valueForVariableStorageKey: kETSubtypeProperty];
}

/* Returns the supervisor view associated with the receiver. The supervisor view 
is a wrapper view around the receiver view (see -view). 

You shouldn't use this method unless you write a subclass.

The supervisor view is used internally by EtoileUI to support views or widgets 
provided by the widget backend (e.g. AppKit) within a layout item tree. See 
also ETView. */
- (ETView *) supervisorView
{
	return supervisorView;
}

- (void) syncSupervisorViewGeometry: (ETSyncSupervisorView)syncDirection
{
	// TODO: Perhaps raise an exception
	if (supervisorView == nil)
		return;

	[super syncSupervisorViewGeometry: syncDirection];

	if (ETSyncSupervisorViewToItem == syncDirection)
	{
		[self setFrame: [supervisorView frame]];
		[self setAutoresizingMask: [supervisorView autoresizingMask]];
	}
	else /* ETSyncSupervisorViewFromItem */
	{
		[supervisorView setFrame: [self frame]];
		/* This autoresizing mask won't be used, see -[ETView initWithFrame:],
		   unless a decorator is set, that resizes the supervisor view to
		   resize the item. */
		[supervisorView setAutoresizingMask: [self autoresizingMask]];
	}
}

/** Sets the supervisor view associated with the receiver and marks it as 
needing a layout update.

Will set up a supervisor view for ancestor items recursively when they miss one.

You should never need to call this method.

On the next layout update, the view will be added as a subview to the supervisor
view bound to the parent item to which the given item belongs to. Which means, 
the view may move to a different place in the view hierarchy.

Throws an exception when item parameter is nil.

See also -supervisorView. */
- (void) setSupervisorView: (ETView *)aSupervisorView sync: (ETSyncSupervisorView)syncDirection
{
	if (self.parentItem.supervisorView == nil)
	{
		[self.parentItem setUpSupervisorView];
	}
	[super setSupervisorView: aSupervisorView sync: syncDirection];
	[self setNeedsLayoutUpdate];
}

/* Inserts a supervisor view that is required to be decorated. */
- (void) setDecoratorItem: (ETDecoratorItem *)decorator
{
	BOOL needsInsertSupervisorView = (decorator != nil);
	if (needsInsertSupervisorView)
	{
		[self setUpSupervisorView];
	}
	[super setDecoratorItem: decorator];
}

/* Called from -[ETUIItem setDecoratorItem:] */
- (void) setFirstDecoratedItemFrame: (NSRect)frame
{
	if (_isDeallocating)
		return;

	[self setFrame: frame];
}

/** When the receiver content is presented inside scrollers, returns the 
decorator item that owns the scrollers provided by the widget backend (e.g. 
AppKit), otherwise returns nil.

When multiple scrollable area items are present in the decorator chain, the 
first is returned.

Won't return an enclosing scrollable area item bound to an ancestor item. */
- (ETScrollableAreaItem *) scrollableAreaItem
{
	id decorator = self;
	
	while ((decorator = [decorator decoratorItem]) != nil)
	{
		if ([decorator isKindOfClass: [ETScrollableAreaItem class]])
			break;
	}
	
	return decorator;
}

/** When the receiver content is presented inside a window, returns the 
decorator item that owns the window provided by the widget backend (e.g. 
AppKit), otherwise returns nil.

Won't return an enclosing window item bound to an ancestor item.<br />
To retrieve the enclosing window item, use 
[[self windowBackedAncestorItem] windowItem]. */
- (ETWindowItem *) windowItem
{
	id lastDecorator = [self lastDecoratorItem];
	id windowDecorator = nil;
	
	if ([lastDecorator isKindOfClass: [ETWindowItem class]])
		windowDecorator = lastDecorator;
		
	return windowDecorator;
}

/** Returns the topmost ancestor layout item, including itself, whose layout 
returns YES to -isOpaque (see ETLayout). If none is found, returns self. */
- (ETLayoutItemGroup *) ancestorItemForOpaqueLayout
{
	ETLayoutItemGroup *parent = ([self isGroup] ? (ETLayoutItemGroup *)self : [self parentItem]);
	ETLayoutItemGroup *lastFoundOpaqueAncestor = parent;

	while (parent != nil)
	{
		if ([[parent layout] isOpaque])
			lastFoundOpaqueAncestor = parent;
		
		parent = [parent parentItem];
	}

	return lastFoundOpaqueAncestor;
}

static inline NSRect DrawingBoundsInWindowItem(ETWindowItem *windowItem)
{
	/* We exclude the window border and title bar because the display 
	   view is the window content view and never the window view. */
	return ETMakeRect(NSZeroPoint, [windowItem contentRect].size);
}

/* Returns the drawing bounds for the cover style.

You can draw outside of the drawing bounds in the limits of the drawing box.
The drawing box used a negative origin expressed relatively to the drawing 
bounds origin. */
- (NSRect) drawingBounds
{
	ETWindowItem *windowItem = [self windowItem];
	NSRect rect;

	if (nil != windowItem)
	{
		rect = DrawingBoundsInWindowItem(windowItem);
	}
	else
	{
		rect = [self bounds];
	}

	return rect;
}

/** Returns the bounds where the given style is expected to draw the item.

When the style is the cover style, the drawing area is enclosed in the item 
frame.<br />
When the style is a content style that belongs to -styleGroup, the drawing area 
is enclosed in the item content bounds (which might be partially clipped by 
a decorator).

When no decorator is set on the receiver, returns the same rect usually.

For example, we have an item with boundingBox = { -10, -10, 170, 220 } and 
frame = { 30, 40, 150, 200 }, then in an ETStyle subclass whose instances would 
receive this item through -render:layoutItem:dirtyRect:
<example>
// bounds.origin is the current drawing context origin
NSRect bounds = [item drawingBoundsForStyle: self]; 
NSRect box = [item boundingBox];

[NSBezierPath fillRect: bounds]; // bounds is { 0, 0, 150, 200 }
// With a custom bounding box, you can draw outside of the drawing bounds
[NSBezierPath strokeRect: box]; // box is { -10, -10, 170, 220 }
</example> 

See also -contentBounds, -frame, -boundingBox, -coverStyle, -styleGroup and 
-style. */
- (NSRect) drawingBoundsForStyle: (ETStyle *)aStyle
{
	BOOL isCoverStyle = (aStyle == _coverStyle);

	return (isCoverStyle ? [self drawingBounds] : _contentBounds);
}

/** This method is only exposed to be used internally by EtoileUI.

Returns the -coverStyle drawing area (i.e. the clipping rect).

The returned rect is the bouding box but adjusted to prevent drawing on the 
window decorations. */
- (NSRect) drawingBox
{
	ETWindowItem *windowItem = [self windowItem];
	NSRect rect;

	if (nil != windowItem)
	{
		rect = DrawingBoundsInWindowItem(windowItem);
	}
	else
	{
		rect = [self boundingBox];
	}

	return rect;
}

/** This method is only exposed to be used internally by EtoileUI.

Returns the -styleGroup visible drawing area (i.e. the clipping rect).

The returned rect is the visible content bounds. */
- (NSRect) contentDrawingBox
{
	return [self visibleContentBounds];
}

- (void) drawFrameWithRect: (NSRect)aRect
{
	[[NSColor blueColor] set];
	NSFrameRectWithWidth(aRect, 1.0);
}

- (void) drawBoundingBoxWithRect: (NSRect)aRect
{
	[[NSColor redColor] set];
	NSFrameRectWithWidth(aRect, 1.0);
}

/* For debugging */
- (void) drawViewItemMarker
{
	if ([self displayView] == nil)
		return;

	[[NSColor greenColor] set];
	NSFrameRectWithWidth([self bounds], 3.0);
}

/** <override-dummy />
Renders or draws the receiver in the given rendering context.

The coordinates matrix must be adjusted to the receiver coordinate space, before 
calling this method.

EtoileUI will lock and unlock the focus when needed around this method, unless
you call this method directly. In this case, you are responsible to lock/unlock 
the focus.

You are allowed to draw beyond the receiver frame (EtoileUI doesn't clip the 
drawing). In that case, you have to use -setBoundingBox to specify the area were 
the redisplay is now expected to occur, otherwise methods like -display and 
-setNeedsDisplay: won't work correctly.<br />
You should be careful and only use this possibility to draw visual 
embellishments strictly related to the receiver. e.g. borders, selection mark, 
icon badge, control points etc.

dirtyRect indicates the receiver portion that needs to be redrawn and is 
expressed in the receiver coordinate space. This rect is is usally equal to 
-drawingBox. But it can be smaller when the parent item doesn't need to be
entirely redrawn and the portion to redraw intersects the receiver area 
(without covering it).<br />
Warning: When -decoratorItem is not nil, the receiver coordinate space is not  
equal to the receiver content coordinate space.

inputValues is a key/value pair list that is initially passed to the ancestor 
item on which the rendering was started. You can add or remove key/value pairs  
to let styles know how they are expected to be rendered.<br />
This key/value pair list will be carried downwards until the rendering is finished.

ctxt represents the rendering context which encloses the drawing context. For 
now, the context is nil and must be ignored.  */
- (void) render: (NSMutableDictionary *)inputValues
      dirtyRect: (NSRect)dirtyRect 
      inContext: (id)ctxt 
{
	ETAssert(supervisorView == nil);

	//ETLog(@"Render frame %@ of %@ dirtyRect %@ in %@", 
	//	NSStringFromRect([self drawingFrame]), self, NSStringFromRect(dirtyRect), ctxt);

	/* To draw the background, we should adjust the coordinate matrix to the 
	   content bounds on the paper, but since the supervisor view won't call 
	   this method when the item is decorated, we can use the same coordinates 
	   matrix to draw both the foreground and background. */
	[self renderBackground: inputValues
	             dirtyRect: dirtyRect
	             inContext: nil];
	[self renderForeground: inputValues
	             dirtyRect: dirtyRect
	             inContext: nil];

}

/** Draws the background style.

The dirty rect is expressed in the receiver content coordinate space.

The coordinates matrix must be adjusted to the receiver content coordinate space, 
before calling this method.

See -render:dirtyRect:inContext: and -contentDrawingBox. */
- (void) renderBackground: (NSMutableDictionary *)inputValues
                dirtyRect: (NSRect)dirtyRect
                inContext: (id)ctxt
{
	[NSGraphicsContext saveGraphicsState];
	[[NSBezierPath bezierPathWithRect: dirtyRect] setClip];
	[_styleGroup render: inputValues
	         layoutItem: self
	          dirtyRect: dirtyRect];
	[NSGraphicsContext restoreGraphicsState];
}

/** Draws the foreground style.

The dirty rect is expressed in the receiver coordinate space.

The coordinates matrix must be adjusted to the receiver coordinate space, before 
calling this method.

See -render:dirtyRect:inContext: and -drawingBox. */
- (void) renderForeground: (NSMutableDictionary *)inputValues
                dirtyRect: (NSRect)dirtyRect
                inContext: (id)ctxt
{
	/* When we have no view, we render the cover style */
	[NSGraphicsContext saveGraphicsState];
	[[NSBezierPath bezierPathWithRect: dirtyRect] setClip];
	[_coverStyle render: inputValues
	         layoutItem: self
	          dirtyRect: dirtyRect];
	//[[NSColor yellowColor] set];
	//NSFrameRectWithWidth(dirtyRect, 4.0);
	[NSGraphicsContext restoreGraphicsState];

	if (showsViewItemMarker)
	{
		[self drawViewItemMarker];
	}
	if (showsBoundingBox)
	{
		[self drawBoundingBoxWithRect: [self boundingBox]];
	}
	if (showsFrame)
	{
		[self drawFrameWithRect: [self bounds]];
	}
}

/** Marks the receiver and the entire layout item tree owned by it to be 
redisplayed the next time an ancestor view receives a display if needed 
request (see -[NSView displayIfNeededXXX] methods). 

More explanations in -display. */
- (void) setNeedsDisplay: (BOOL)flag
{
	[self setNeedsDisplayInRect: [self convertRectToContent: [self boundingBox]]];
}

/** Marks the given receiver area and the entire layout item subtree that 
intersects it, to be redisplayed the next time an ancestor view receives a 
display if needed request (see -[NSView displayIfNeededXXX] methods). 

More explanations in -display. */
- (void) setNeedsDisplayInRect: (NSRect)dirtyRect
{
	NSView *displayView = nil;
	NSRect displayRect = [[self firstDecoratedItem] convertDisplayRect: dirtyRect 
	                        toAncestorDisplayView: &displayView
							rootView: [[[self enclosingDisplayView] window] contentView]
							parentItem: [self parentItem]];

	[displayView setNeedsDisplayInRect: displayRect];
}

/** Triggers the redisplay of the receiver and the entire layout item tree 
owned by it. 

To handle the display, an ancestor view is looked up and the rect to refresh is 
converted into this ancestor coordinate space. Precisely both the lookup and the 
conversion are handled by 
-convertDisplayRect:toAncestorDisplayView:rootView:parentItem:.

If the receiver has a display view, this view will be asked to draw by itself.  */
- (void) display
{
	 /* Redisplay the content bounds unless a custom bouding box is set */
	[self displayRect: [self convertRectToContent: [self boundingBox]]];
}

/** Triggers the redisplay of the given receiver area and the entire layout item 
subtree that intersects it. 

More explanations in -display. */
- (void) displayRect: (NSRect)dirtyRect
{
	// NOTE: We could also use the next two lines to redisplay, but 
	// -convertDisplayRect:toAncestorDisplayView: is more optimized.
	//ETLayoutItem *ancestor = [self supervisorViewBackedAncestorItem];
	//[[ancestor displayView] displayRect: [self convertRect: [self boundingBox] toItem: ancestor]];

	NSView *displayView = nil;
	NSRect displayRect = [[self firstDecoratedItem] convertDisplayRect: dirtyRect
	                        toAncestorDisplayView: &displayView
							rootView: [[[self enclosingDisplayView] window] contentView]
							parentItem: [self parentItem]];
	[displayView displayRect: displayRect];
}

/** Redisplays the areas marked as invalid in the receiver and all its descendant 
items.

Areas can be marked as invalid with -setNeedsDisplay: and -setNeedsDisplayInRect:. */
- (void) displayIfNeeded
{
	[[self enclosingDisplayView] displayIfNeeded];
}

/** When the receiver is visible in an opaque layout and won't redraw by itself, 
marks the ancestor item to redisplay the area that corresponds to the receiver 
in this layout. Else marks the receiver to be redisplayed exactly as 
-setNeedsDisplay: with YES. 

See also -ancestorItemForOpaqueLayout. */
- (void) refreshIfNeeded
{
	ETLayoutItem *opaqueAncestor = [self ancestorItemForOpaqueLayout];

	if (opaqueAncestor != self)
	{
		[[opaqueAncestor layout] setNeedsDisplayForItem: self];
	}
	else
	{
		[self setNeedsDisplay: YES];
	}
}

/** Returns the style group associated with the receiver. By default, 
returns a style group whose only style element is an ETBasicItemStyle object. */    
- (ETStyleGroup *) styleGroup
{
	return _styleGroup;
}

/** Sets the style group associated with the receiver.

The styles inside the style group control the drawing of the receiver.<br />
See ETStyle to understand how to customize the layout item look. */
- (void) setStyleGroup: (ETStyleGroup *)aStyle
{
	[self willChangeValueForProperty: kETStyleGroupProperty];
	_styleGroup = aStyle;
	[self didChangeValueForProperty: kETStyleGroupProperty];
}

/** Returns the first style inside the style group. */
- (id) style
{
	return [[self styleGroup] firstStyle];
}

/** Removes all styles inside the style group, then adds the given style to the 
style group. 

If the given style is nil, the style group becomes empty. */
- (void) setStyle: (ETStyle *)aStyle
{
	[[self styleGroup] removeAllStyles];
	if (aStyle != nil)
	{
		[[self styleGroup] addStyle: aStyle];
	}
}

- (id) coverStyle
{
	return _coverStyle;
}

- (void) setCoverStyle: (ETStyle *)aStyle
{
	[self willChangeValueForProperty: kETCoverStyleProperty];
	_coverStyle = aStyle;
	[self didChangeValueForProperty: kETCoverStyleProperty];
}

- (void) setDefaultValue: (id)aValue forProperty: (NSString *)key
{
	if (aValue == nil)
	{
	
		[_defaultValues removeObjectForKey: key];
	}
	else
	{
		_defaultValues[key] = aValue;
	}
}

- (id) defaultValueForProperty: (NSString *)key
{
	return _defaultValues[key];
}

- (void) setInitialValue: (id)aValue forProperty: (NSString *)key
{
	_defaultValues[key] = (aValue != nil ? aValue : [NSNull null]);
}

- (id) initialValueForProperty: (NSString *)key
{
	id value = _defaultValues[key];
	return ([value isEqual: [NSNull null]] ? nil : value);
}

- (id) removeInitialValueForProperty: (NSString *)key
{
	id value = _defaultValues[key];
	[_defaultValues removeObjectForKey: key];
	return value;
}

/* Geometry */

/** Returns a rect expressed in the parent item content coordinate space 
equivalent to rect parameter expressed in the receiver coordinate space. */
- (NSRect) convertRectToParent: (NSRect)rect
{
	NSRect rectToTranslate = rect;
	NSRect rectInParent = rect;

	if ([self isFlipped] != [[self parentItem] isFlipped])
	{
		rectToTranslate.origin.y = [self height] - rect.origin.y - rect.size.height;
	}

	// NOTE: See -convertRectFromParent:...
	// NSAffineTransform *transform = [NSAffineTransform transform];
	// [transform translateXBy: [self x] yBy: [self y]];
	// rectInParent.origin = [transform transformPoint: rect.origin];
	rectInParent.origin.x = rectToTranslate.origin.x + [self x];
	rectInParent.origin.y = rectToTranslate.origin.y + [self y];
	
	return rectInParent;
}

/** Returns a rect expressed in the receiver coordinate space equivalent to
rect parameter expressed in the parent item content coordinate space. */
- (NSRect) convertRectFromParent: (NSRect)rect
{
	NSRect rectInReceiver = rect; /* Keep the size as is */

	// NOTE: If we want to handle bounds transformations (rotation, translation,  
	// and scaling), we should switch to NSAffineTransform, the current code 
	// would be...
	// NSAffineTransform *transform = [NSAffineTransform transform];
	// [transform translateXBy: -([self x]) yBy: -([self y])];
	// rectInChild.origin = [transform transformPoint: rect.origin];
	rectInReceiver.origin.x = rect.origin.x - [self x];
	rectInReceiver.origin.y = rect.origin.y - [self y];

	if ([self isFlipped] != [[self parentItem] isFlipped])
	{
		rectInReceiver.origin.y = [self height] - rectInReceiver.origin.y - rectInReceiver.size.height;
	}

	return rectInReceiver;
}

/** Returns a point expressed in the parent item content coordinate space 
equivalent to point parameter expressed in the receiver coordinate space. */
- (NSPoint) convertPointToParent: (NSPoint)point
{
	return [self convertRectToParent: ETMakeRect(point, NSZeroSize)].origin;
}

/** Returns a rect expressed in the receiver coordinate space equivalent to rect 
parameter expressed in ancestor coordinate space.

In case the receiver is not a descendent or ancestor is nil, returns a null rect. */
- (NSRect) convertRect: (NSRect)rect fromItem: (ETLayoutItemGroup *)ancestor
{
	if (self == ancestor)
		return rect;

	if (ETIsNullRect(rect) || ancestor == nil || [self parentItem] == nil)
		return ETNullRect;

	NSRect newRect = rect;

	if ([self parentItem] != ancestor)
	{
		newRect = [[self parentItem] convertRect: rect fromItem: ancestor];
	}

	return [self convertRectFromParent: [[self parentItem] convertRectToContent: newRect]];
}

/** Returns a rect expressed in ancestor coordinate space equivalent to rect 
parameter expressed in the receiver coordinate space.

In case the receiver is not a descendent or ancestor is nil, returns a null rect. */
- (NSRect) convertRect: (NSRect)rect toItem: (ETLayoutItemGroup *)ancestor
{
	if (ETIsNullRect(rect) || [self parentItem] == nil || ancestor == nil)
		return ETNullRect;

	NSRect newRect = rect;
	ETLayoutItem *parent = self;

	while (parent != ancestor)
	{
		newRect = [parent convertRectToParent: [parent convertRectFromContent: newRect]];
		parent = [parent parentItem];
	}

	return newRect;
}

/** Returns whether the receiver uses flipped coordinates to position its 
content. 
 
The returned value will be taken in account in methods related to geometry, 
event handling and drawing. */
- (BOOL) isFlipped
{
	return _flipped;
}

/** Sets whether the receiver uses flipped coordinates to position its content. 

This method updates the supervisor view and the decorator chain to match the 
flipping of the receiver.

You must never alter the supervisor view directly with -[ETView setFlipped:].

Marks the receiver as needing a layout update. */
- (void) setFlipped: (BOOL)flip
{
	if (flip == _flipped)
		return;

	[self willChangeValueForProperty: kETFlippedProperty];
	_flipped = flip;
	[[self supervisorView] setFlipped: flip];
	[[self decoratorItem] setFlipped: flip];
	[self setNeedsLayoutUpdate];
	[self didChangeValueForProperty: kETFlippedProperty];
}

/** Returns a point expressed in the receiver coordinate space equivalent to
point parameter expressed in the parent item content coordinate space. */
- (NSPoint) convertPointFromParent: (NSPoint)point
{
	return [self convertRectFromParent: ETMakeRect(point, NSZeroSize)].origin;
}

/** Returns whether a point expressed in the parent item content coordinate 
space is within the receiver frame. The item frame is also expressed in the 
parent item content coordinate space.
 
This method checks whether the parent item is flipped or not. */
- (BOOL) containsPoint: (NSPoint)point
{
	return NSMouseInRect(point, [self frame], [[self parentItem] isFlipped]);
}

/** Returns whether a point expressed in the receiver coordinate space is inside 
the receiver frame.

If the bounding box is used to test the point location, YES can be returned with 
a point whose y or x values are negative.  */
- (BOOL) pointInside: (NSPoint)point useBoundingBox: (BOOL)extended
{
	if (extended)
	{
		return NSMouseInRect(point, [self boundingBox], [self isFlipped]);	
	}
	else
	{
		return NSMouseInRect(point, [self bounds], [self isFlipped]);
	}
}

- (NSRect) bounds
{
	BOOL hasDecorator = (_decoratorItem != nil);
	NSRect rect = NSZeroRect;

	if (hasDecorator)
	{
		rect.size = [[self lastDecoratorItem] decorationRect].size;
	}
	else
	{
		rect.size = [self contentBounds].size;
	}

	return rect;
}

- (void) setBoundsSize: (NSSize)size
{
	BOOL hasDecorator = (_decoratorItem != nil);

	if (hasDecorator)
	{
		/* Will indirectly resize the supervisor view with -setFrameSize: that 
		   will in turn call back -setContentSize:. */
		[[self lastDecoratorItem] setDecorationRect: ETMakeRect([self origin], size)];
	}
	else
	{
		[self setContentSize: size];
	}
}

/** Returns the persistent frame associated with the receiver. 

This custom frame is used by ETFreeLayout. This property keeps track of the 
fixed location and size that are used for the receiver in the free layout, even 
if you switch to another layout that alters the receiver frame. The current 
frame is returned by -frame in all cases, hence when ETFreeLayout is in use, 
-frame is equal to -persistentFrame. */
- (NSRect) persistentFrame
{
	// TODO: Find the best way to eventually allow the represented object to 
	// provide and store the persistent frame.
	NSValue *value = [self valueForVariableStorageKey: kETPersistentFrameProperty];
	
	/* -rectValue wrongly returns random rect values when value is nil */
	if (value == nil)
		return ETNullRect;

	return [value rectValue];
}

/** Sets the persistent frame associated with the receiver. See -persistentFrame. */
- (void) setPersistentFrame: (NSRect) frame
{
	[self willChangeValueForProperty: kETPersistentFrameProperty];
	[self setValue: [NSValue valueWithRect: frame] forVariableStorageKey: kETPersistentFrameProperty];
	[self didChangeValueForProperty: kETPersistentFrameProperty];
}

- (void) updatePersistentGeometryIfNeeded
{
	ETLayout *parentLayout = [[self parentItem] layout];

	if ([parentLayout isPositional] && [parentLayout isComputedLayout] == NO)
		[self setPersistentFrame: [self frame]];
}

/** Returns the current frame. If the receiver has a view attached to it, the 
returned frame is equivalent to the display view frame.  

This value is always in sync with the persistent frame in a positional and 
non-computed layout such as ETFreeLayout, but is usually different when the 
layout is computed.<br />
See also -setPersistentFrame: */
- (NSRect) frame
{
	BOOL hasDecorator = (_decoratorItem != nil);

	if (hasDecorator)
	{
		return [[self lastDecoratorItem] decorationRect];
	}
	else
	{
		return ETMakeRect([self origin], [self contentBounds].size);
	}
}

/** Sets the current frame and also the persistent frame if the layout of the 
parent item is positional and non-computed such as ETFreeLayout.

Marks the receiver as needing a layout update. Marks the parent item too, when 
the receiver has no decorator.

See also -[ETLayout isPositional] and -[ETLayout isComputedLayout]. */
- (void) setFrame: (NSRect)rect
{
	NSParameterAssert(_isSyncingSupervisorViewGeometry == NO);
	NSParameterAssert(rect.size.width >= 0 && rect.size.height >= 0);

	ETDebugLog(@"-setFrame: %@ on %@", NSStringFromRect(rect), self); 

	BOOL hasDecorator = (_decoratorItem != nil);

	if (hasDecorator)
	{
		/* Will indirectly resize the supervisor view with -setFrameSize: that 
		   will in turn call back -setContentSize:. */
		[[self lastDecoratorItem] setDecorationRect: rect];
		[[self coverStyle] didChangeItemBounds: ETMakeRect(NSZeroPoint, rect.size)];
	}
	else
	{
		[self setContentSize: rect.size];
	}
	/* Must follow -setContentSize: to allow the anchor point to be computed */
	 // TODO: When the receiver is decorated, will invoke -setDecorationRect: 
	 // one more time. We should eliminate this extra call.
	[self setOrigin: rect.origin];
}

/** <override-dummy />
This method is only exposed to be used internally by EtoileUI.

Returns NO.
 
See -[ETLayoutItemGroup usesFlexibleLayoutFrame]. */
- (BOOL) usesFlexibleLayoutFrame
{
	return NO;
}

/** <override-dummy />
Returns nil.
 
See -[ETLayoutItemGroup layout]. */
- (id) layout
{
	return nil;
}

/** <override-dummy />
This method is only exposed to be used internally by EtoileUI.
 
Does nothing.
 
See -[ETLayoutItemGroup updateLayoutRecursively:]. */
- (void) updateLayoutRecursively: (BOOL)recursively
{
	[[ETLayoutExecutor sharedInstance] removeItem: (id)self];
}

/** <override-dummy />
This method is only exposed to be used internally by EtoileUI.
 
Marks the receiver to be redisplayed in the interval between the current and
the next event.

See -[ETLayoutItemGroup setNeedsLayoutUpdate]. */
- (void) setNeedsLayoutUpdate
{
	[self setNeedsDisplay: YES];
}

/** Returns the current origin associated with the receiver frame. See also -frame. */
- (NSPoint) origin
{
	NSPoint anchorPoint = [self anchorPoint];
	NSPoint origin = [self position];

	origin.x -= anchorPoint.x;
	origin.y -= anchorPoint.y;

	return origin;
}

/** Sets the current origin associated with the receiver frame. See also -setFrame:. */   
- (void) setOrigin: (NSPoint)origin
{
	NSPoint anchorPoint = [self anchorPoint];
	NSPoint position = origin ;

	position.x += anchorPoint.x;
	position.y += anchorPoint.y;

	[self setPosition: position];
}

/** Returns the current anchor point associated with the receiver content bounds. 
The anchor point is expressed in the receiver content coordinate space.

By default, the anchor point is centered in the content bounds rectangle. See 
-contentBounds.

The item position is relative to the anchor point. See -position. */
- (NSPoint) anchorPoint
{
	if ([self valueForVariableStorageKey: kETAnchorPointProperty] == nil)
	{
		NSPoint anchor = [self centeredAnchorPoint];
		[self setValue: [NSValue valueWithPoint: anchor] forVariableStorageKey: kETAnchorPointProperty];
		return anchor;
	}
	return [[self valueForVariableStorageKey: kETAnchorPointProperty] pointValue];
}

/* Returns the center of the bounds rectangle in the receiver content coordinate 
space. */
- (NSPoint) centeredAnchorPoint
{
	NSSize boundsSize = [self contentBounds].size;	
	NSPoint anchorPoint = NSZeroPoint;
	
	anchorPoint.x = boundsSize.width / 2.0;
	anchorPoint.y = boundsSize.height / 2.0;
	
	return anchorPoint;
}

/** Sets the current anchor point associated with the receiver content bounds. 
anchor must be expressed in the receiver content coordinate space. */  
- (void) setAnchorPoint: (NSPoint)anchor
{
	ETDebugLog(@"Set anchor point to %@ - %@", NSStringFromPoint(anchor), self);
	[self willChangeValueForProperty: kETAnchorPointProperty];
	[self setValue: [NSValue valueWithPoint: anchor] forVariableStorageKey: kETAnchorPointProperty];
	[self didChangeValueForProperty: kETAnchorPointProperty];
}

/** Returns the current position associated with the receiver frame. The 
position is expressed in the parent item coordinate space. See also 
-setPosition:. */
- (NSPoint) position
{
	return _position;
}

- (BOOL) shouldSyncSupervisorViewGeometry
{
	return (_isSyncingSupervisorViewGeometry == NO && [self supervisorView] != nil);
}

/** Sets the current position associated with the receiver frame.

When -setPosition: is called, the position is applied relative to -anchorPoint. 
position must be expressed in the parent item coordinate space (exactly as the 
frame). When the position is set, the frame is moved to have the anchor point 
location in the parent item coordinate space equal to the new position value.

Marks the parent item as needing a layout update. */  
- (void) setPosition: (NSPoint)position
{
	/* Prevent damage notifications for CoreObject during object loading */
	if (NSEqualPoints(_position, position))
		return;

	[self willChangeValueForEmbeddingProperty: kETPositionProperty];
	_position = position;

	// NOTE: Will probably be reworked once layout item views are drawn directly by EtoileUI.
	if ([self shouldSyncSupervisorViewGeometry])
	{
		BOOL hasDecorator = (_decoratorItem != nil);
		
		_isSyncingSupervisorViewGeometry = YES;
		if (hasDecorator)
		{
			ETDecoratorItem *lastDecoratorItem = [self lastDecoratorItem];
			NSSize size = [lastDecoratorItem decorationRect].size;
			NSRect movedFrame = ETMakeRect([self origin], size);
			/* Will indirectly move the supervisor view with -setFrameOrigin: that 
			   will in turn call back -setOrigin:. */
			[lastDecoratorItem setDecorationRect: movedFrame];
		}
		else
		{
			[[self displayView] setFrameOrigin: [self origin]];
		}
		_isSyncingSupervisorViewGeometry = NO;
	}

	[self updatePersistentGeometryIfNeeded];
	[[self parentItem] setNeedsLayoutUpdate];
	[self didChangeValueForEmbeddingProperty: kETPositionProperty];
}

/** Returns the current size associated with the receiver frame. See also -frame. */       
- (NSSize) size
{
	return [self bounds].size;
}

/** Sets the current size associated with the receiver frame. See also -setFrame:. */           
- (void) setSize: (NSSize)size
{
	[self setBoundsSize: size];
}

/** Returns the current x coordinate associated with the receiver frame origin. 
See also -frame. */       
- (CGFloat) x
{
	return [self origin].x;
}

/** Sets the current x coordinate associated with the receiver frame origin. 
See also -setFrame:. */
- (void) setX: (CGFloat)x
{
	[self setOrigin: NSMakePoint(x, [self y])];
}

/** Returns the current y coordinate associated with the receiver frame origin. 
See also -frame. */
- (CGFloat) y
{
	return [self origin].y;
}

/** Sets the current y coordinate associated with the receiver frame origin. 
See also -setFrame:. */
- (void) setY: (CGFloat)y
{
	[self setOrigin: NSMakePoint([self x], y)];
}

/** Returns the current height associated with the receiver frame size. See also 
-frame. */
- (CGFloat) height
{
	return [self size].height;
}

/** Sets the current height associated with the receiver frame size. See also 
-setFrame:. */
- (void) setHeight: (CGFloat)height
{
	[self setSize: NSMakeSize([self width], height)];
}

/** Returns the current width associated with the receiver frame size. See also 
-frame. */
- (CGFloat) width
{
	return [self size].width;
}

/** Sets the current width associated with the receiver frame size. See also 
-setFrame:. */
- (void) setWidth: (CGFloat)width
{
	[self setSize: NSMakeSize(width, [self height])];
}

- (NSSize)minSize
{
	return _minSize;
}

- (void) setMinSize: (NSSize)size
{
	[self willChangeValueForProperty: @"minSize"];
	_minSize = size;
	[self didChangeGeometryConstraints];
	[self didChangeValueForProperty: @"minSize"];
}

- (NSSize)maxSize
{
	return _maxSize;
}

- (void) setMaxSize: (NSSize)size
{
	[self willChangeValueForProperty: @"maxSize"];
	_maxSize = size;
	[self didChangeGeometryConstraints];
	[self didChangeValueForProperty: @"maxSize"];
}

- (void) didChangeGeometryConstraints
{
	ETUIItem *item = self;
	
	// Apply constraints to the last decorator and reset other item constraints
	while (item != nil)
	{
		[item didChangeGeometryConstraintsOfItem: self];
		item = item.decoratorItem;
	}
	// Update content bounds when min or max sizes are set without any decorators
	self.contentBounds = _contentBounds;

	// For outermost decoration rect udpates, when content bounds are untouched
	[self setNeedsLayoutUpdate];
	if (_decoratorItem == nil)
	{
		[self.parentItem setNeedsLayoutUpdate];
	}
}

/** Returns the content bounds associated with the receiver. */
- (NSRect) contentBounds
{
	return _contentBounds;
}

/** Returns the content bounds expressed in the decorator item coordinate space. 
When no decorator is set, the parent item coordinate space is used.

Both decoration rect and content bounds have the same size, because the first 
decorated item is never a decorator and thereby has no decoration. */ 
- (NSRect) decorationRectForContentBounds: (NSRect)bounds
{
	BOOL hasDecorator = (_decoratorItem != nil);

	if (hasDecorator)
	{
		return ETMakeRect([_decoratorItem contentRect].origin, bounds.size);
	}
	else
	{
		return ETMakeRect([self origin], bounds.size);
	}
}

/* Used by ETDecoratorItem */
- (NSRect) decorationRect
{
	return [self decorationRectForContentBounds: [self contentBounds]];
}

/** Sets the content bounds associated with the receiver.

By default, the origin of the content bounds is (0.0, 0.0). You can customize it 
to translate the coordinate system used to draw the receiver. The receiver 
transform, which might include a translation too, won't be altered. Both 
translations are cumulative.

If the flipped property is modified, the content bounds remains identical.

Marks the receiver as needing a layout update. Marks the parent item too, when 
the receiver has no decorator.  */
- (void) setContentBounds: (NSRect)rect
{
	NSParameterAssert(rect.size.width >= 0 && rect.size.height >= 0);
	
	BOOL hasDecorator = (_decoratorItem != nil);
	NSRect constrainedRect = (hasDecorator ? rect :
		ETMakeRect(rect.origin, ETConstrainedSizeFromSize(rect.size, _minSize, _maxSize)));

	/* Prevent damage notifications for CoreObject during object loading */
	if (NSEqualRects(_contentBounds, constrainedRect))
		return;

	[self willChangeValueForEmbeddingProperty: kETContentBoundsProperty];
	_contentBounds = constrainedRect;

	if ([self shouldSyncSupervisorViewGeometry])
	{
		_isSyncingSupervisorViewGeometry = YES;
		if (hasDecorator)
		{
			NSRect decorationRect = [self decorationRectForContentBounds: [self contentBounds]];
			_contentBounds.size = [_decoratorItem decoratedItemRectChanged: decorationRect];
		}
		else
		{
			[[self displayView] setFrameSize: _contentBounds.size];
		}
		_isSyncingSupervisorViewGeometry = NO;
	}

	[self updatePersistentGeometryIfNeeded];
	[[self styleGroup] didChangeItemBounds: _contentBounds];
	[self setNeedsLayoutUpdate];
	if (_decoratorItem == nil)
	{
		[[self parentItem] setNeedsLayoutUpdate];
	}
	[self didChangeValueForEmbeddingProperty: kETContentBoundsProperty];
}

/** Sets the content size associated with the receiver. */
- (void) setContentSize: (NSSize)size
{
	[self setContentBounds: ETMakeRect([self contentBounds].origin, size)];
}

/** Returns a rect expressed in the receiver coordinate space equivalent 
to rect parameter expressed in the receiver content coordinate space.

The content coordinate space is located inside -contentBounds. */
- (NSRect) convertRectFromContent: (NSRect)rect
{
	id decorator = [self decoratorItem];
	NSRect rectInFrame = rect;

	while (decorator != nil)
	{
		rectInFrame = [decorator convertDecoratorRectFromContent: rectInFrame];
		decorator = [decorator decoratorItem];
	} 

	return rectInFrame;
}

/** Returns a rect expressed in the receiver content coordinate space 
equivalent to rect parameter expressed in the receiver coordinate space.

The content coordinate space is located inside -contentBounds. */
- (NSRect) convertRectToContent: (NSRect)rect
{
	id decorator = [self lastDecoratorItem];
	NSRect rectInContent = rect;

	while (decorator != self)
	{
		rectInContent = [decorator convertDecoratorRectToContent: rectInContent];
		decorator = [decorator decoratedItem];
	} 

	return rectInContent;
}

/** Returns a point expressed in the receiver content coordinate space 
equivalent to point parameter expressed in the receiver coordinate space.

The content coordinate space is located inside -contentBounds. */
- (NSPoint) convertPointToContent: (NSPoint)aPoint
{
	return [self convertRectToContent: ETMakeRect(aPoint, NSZeroSize)].origin;
}

/** Sets the transform applied within the content bounds.

Marks the receiver as needing a layout update. Marks the parent item too, when 
the receiver has no decorator. */
- (void) setTransform: (NSAffineTransform *)aTransform
{
	[self willChangeValueForProperty: kETTransformProperty];
	_transform = aTransform;
	[self setNeedsLayoutUpdate];
	if (_decoratorItem == nil)
	{
		[[self parentItem] setNeedsLayoutUpdate];
	}
	[self didChangeValueForProperty: kETTransformProperty];
}

/** Returns the transform applied within the content bounds. */
- (NSAffineTransform *) transform
{
	return _transform;
}

/** This method is only exposed to be used internally by EtoileUI.

Returns the visible portion of the content bounds when the receiver content is 
clipped by a decorator, otherwise the same than -contentBounds.

The returned rect is expressed in the receiver content coordinate space. */
- (NSRect) visibleContentBounds
{
	NSRect visibleContentBounds = [self contentBounds];

	if (nil != _decoratorItem)
	{
		visibleContentBounds = [_decoratorItem visibleRect];
	}
	else
	{
		visibleContentBounds.origin = NSZeroPoint;
	}

	return visibleContentBounds;
}

- (ETEdgeInsets) boundingInsets
{
	return ETEdgeInsetsMake(_boundingInsetsRect.origin.x, _boundingInsetsRect.origin.y,
	                        _boundingInsetsRect.size.width, _boundingInsetsRect.size.height);
}

- (void) setBoundingInsets: (ETEdgeInsets)insets
{
	NSRect rectInsets = NSMakeRect(insets.left, insets.top, insets.right, insets.bottom);

	/* Prevent damage notifications for CoreObject during object loading.
	   For -[ETFreeLayout didLoadObjectGraph], -[ETHandleGroup setBoundingBox:]  
	   will call -setBoundingBox: on manipulated persistent items. */
	if (NSEqualRects(_boundingInsetsRect, rectInsets))
		return;

	[self willChangeValueForProperty: @"boundingInsets"];
	[self willChangeValueForProperty: @"boundingInsetsRect"];

	_boundingInsetsRect = rectInsets;

	[self setNeedsLayoutUpdate];
	if (_decoratorItem == nil)
	{
		[[self parentItem] setNeedsLayoutUpdate];
	}

	[self didChangeValueForProperty: @"boundingInsetsRect"];
	[self didChangeValueForProperty: @"boundingInsets"];
}
/** Returns the rect that fully encloses the receiver and represents the maximal 
extent on which hit test is done and redisplay requested. This rect is expressed 
in the receiver content coordinate space. */
- (NSRect) boundingBox
{
	return ETRectInset(self.bounds, self.boundingInsets);
}

/** Sets the rect that fully encloses the receiver and represents the maximal 
extent on which hit test is done and redisplay requested. This rect must be 
expressed in the receiver coordinate space.

The bounding box is used by ETTool in the hit test phase. It is also used 
by -display and -setNeedsDisplay: methods to compute the dirty area that needs 
to be refreshed. Hence it can be used by ETLayout subclasses related code to 
increase the area which requires to be redisplayed. For example, ETHandleGroup 
calls -setBoundingBox: on its manipulated object, because its handles are not 
fully enclosed in the receiver frame.

The bounding box must be always be greater or equal to the receiver frame.

Marks the receiver as needing a layout update. Marks the parent item too, when 
the receiver has no decorator. */
- (void) setBoundingBox: (NSRect)extent
{
	NSRect bounds = [self bounds];
	// NOTE: NSContainsRect returns NO if the width or height are 0
	NSParameterAssert(NSContainsRect(extent, bounds) || bounds.size.width == 0 || bounds.size.height == 0);

	[self willChangeValueForProperty: kETBoundingBoxProperty];
	self.boundingInsets = ETEdgeInsetsFromRectDifference(bounds, extent);
	[self didChangeValueForProperty: kETBoundingBoxProperty];
}

/** Returns the default frame associated with the receiver. See -setDefaultFrame:. */
- (NSRect) defaultFrame 
{
	NSValue *value = [self valueForVariableStorageKey: kETDefaultFrameProperty];
	
	/* -rectValue wrongly returns random rect values when value is nil */
	if (value == nil)
		return ETNullRect;

	return [value rectValue]; 
}

/** Sets the default frame associated with the receiver and updates the item 
frame to match. The default frame is not touched by layout-related transforms 
(such as item scaling) unlike the item frame returned by -frame. 

When the layout item gets instantiated, the value is set to the initial item 
frame. */
- (void) setDefaultFrame: (NSRect)frame
{
	[self willChangeValueForProperty: kETDefaultFrameProperty];
	[self setValue: [NSValue valueWithRect: frame] forVariableStorageKey: kETDefaultFrameProperty];
	/* Update display view frame only if needed */
	if (NSEqualRects(frame, [self frame]) == NO)
	{
		[self restoreDefaultFrame];
	}
	[self didChangeValueForProperty: kETDefaultFrameProperty];
}

/** Modifies the frame associated with the receiver to match the current default 
frame. */
- (void) restoreDefaultFrame
{ 
	[self setFrame: [self defaultFrame]]; 
}

/** Returns the autoresizing mask that applies to the layout item as whole. 

See also -setAutoresizingMask:.   */
- (ETAutoresizing) autoresizingMask
{
	return _autoresizingMask;
}

/** Sets the autoresizing mask that applies to the layout item as whole. 

The autoresizing mask only applies to the last decorator item (which might be 
the receiver itself).<br />
When the receiver has a decorator, the content autoresizing is controlled by the 
decorator and not by the receiver autoresizing mask directly.

Marks the receiver as needing a layout update. Marks the parent item too, when 
the receiver has no decorator.

TODO: Autoresizing mask isn't yet supported when the receiver has no view. */
- (void) setAutoresizingMask: (ETAutoresizing)aMask
{
	// TODO: Add the same check to -[ETPositionalLayout setIsContentSizeLayout] and
	// possibly an extra check in -resizeItems:forNewLayoutSize:newLayoutSize:oldSize:
	if ([[(ETLayout *)[self layout] positionalLayout] isContentSizeLayout]
	 && (aMask & (ETAutoresizingFlexibleWidth | ETAutoresizingFlexibleHeight)))
	{
		ETLog(@" === WARNING: ETAutoresizingFlexibleWidth or ETAutoresizingFlexibleHeight "
			   "are not supported for %@ if %@ controls the content size (see "
			   "-isContentSizeLayout) === ", self, [self layout]);
	}
	[self willChangeValueForProperty: kETAutoresizingMaskProperty];

	_autoresizingMask = aMask;

	if ([self shouldSyncSupervisorViewGeometry] == NO)
		return;
	
	_isSyncingSupervisorViewGeometry = YES;
	// TODO: Might be reduce to a single line with [super setAutoresizingMask: aMask];
	if (nil != _decoratorItem)
	{
		[(ETDecoratorItem *)[self lastDecoratorItem] setAutoresizingMask: aMask];
	}
	else
	{
		[[self supervisorView] setAutoresizingMask: aMask];
	}
	_isSyncingSupervisorViewGeometry = NO;

	[self setNeedsLayoutUpdate];
	if (_decoratorItem == nil)
	{
		[[self parentItem] setNeedsLayoutUpdate];
	}

	[self didChangeValueForProperty: kETAutoresizingMaskProperty];
}

/** Returns that the content aspect that describes how the content looks when 
the receiver is resized.

See ETContentAspect enum. */
- (ETContentAspect) contentAspect
{
	return _contentAspect;
}

/** Sets the content aspect that describes how the content looks when the 
receiver is resized.

When the item has a view, the view autoresizing mask and frame are altered to 
match the new content aspect.

See ETContentAspect enum. */
- (void) setContentAspect: (ETContentAspect)anAspect
{
	[self willChangeValueForProperty: kETContentAspectProperty];

	_contentAspect = anAspect;

	if ([self view] != nil)
	{
		[(NSView *)[self view] setAutoresizingMask: [self autoresizingMaskForContentAspect: anAspect]];
		[[self view] setFrame: [self contentRectWithRect: [[self view] frame] 
		                                   contentAspect: anAspect 
		                                      boundsSize: _contentBounds.size]];
	}

	[self didChangeValueForProperty: kETContentAspectProperty];
}

/** Returns the image representation associated with the receiver.

By default this method, returns by decreasing order of priority:
<enum>
<item>the receiver image (aka ETImageProperty), if -setImage: was called previously</item>
<item>the receiver value, if -value returns an NSImage object</item>
<item>nil, if none of the above conditions are met</item>
</enum>.
The returned image can be overriden by calling -setImage:. 
 
See also -icon. */
- (NSImage *) image
{
	NSImage *img = [self valueForVariableStorageKey: kETImageProperty];
	
	if (img == nil && [[self value] isKindOfClass: [NSImage class]])
		img = [self value];
		
	return img;
}

/** Sets the image representation associated with the receiver.

The image is drawn by the styles based on the content aspect. See 
ETBasicItemStyle as an example.<br />
You can adjust the image size by altering the receiver size combined with a 
content aspect such as ETContentAspectScaleXXX or ETContentAspectStretchXXX. 

If img is nil, then the default behavior of -image is restored and the returned 
image should not be expected to be nil. */
- (void) setImage: (NSImage *)img
{
	[self willChangeValueForProperty: kETImageProperty];
	[self setValue: img forVariableStorageKey: kETImageProperty];
	[self didChangeValueForProperty: kETImageProperty];
}

// NOTE: May be we should have -displayIcon (or -customIcon, -setCustomIcon:) to 
// eliminate the lack of symetry between -icon and -setIcon:.
/** Returns the image to be displayed when the receiver must be represented in a 
symbolic style. This icon is commonly used by some layouts and also if the 
receiver represents another layout item (when -isMetaItem returns YES).

By default, this method returns by decreasing order of priority:
<enum>
<item>the receiver icon (aka kETIconProperty), if -setIcon: was called previously</item>
<item>the receiver image (aka kETImageProperty), if -image doesn't return nil</item>
<item>the represented object icon, if the represented object and the icon 
associated with it are not nil</item>
<item>a receiver snapshot, if the item can be snapshotted</item>
<item>nil, if none of the above conditions are met</item>
</enum>. 
The returned image can be overriden by calling -setIcon:.

-image and -icon can be considered as symetric equivalents of -name and 
-displayName methods. */
- (NSImage *) icon
{
	NSImage *icon = [self valueForVariableStorageKey: kETIconProperty];
	
	if (icon == nil)
		icon = [self image];

	if (icon == nil && [self representedObject] != nil)
		icon = [[self representedObject] icon];

	if (icon == nil)
		icon = [self snapshotFromRect: [self bounds]];
		
	if (icon == nil)
	{
		ETDebugLog(@"Icon missing for %@", self);
	}
	
	return icon;
}

/** Sets the image to be displayed when the receiver must be represented in a 
symbolic style. See also -icon.

If img is nil, then the default behavior of -icon is restored and the icon image 
should not be expected to be nil. */
- (void) setIcon: (NSImage *)img
{
	[self willChangeValueForProperty: kETIconProperty];
	[self setValue: img forVariableStorageKey: kETIconProperty];
	[self didChangeValueForProperty: kETIconProperty];
}

/** Returns an image snapshot of the receiver. The snapshot is taken at the time 
this method is called.

The given rect must be expressed in the receiver coordinate space.

When the receiver isn't backed by a window and has no window-backed ancestor 
item backed either, returns nil. */
- (NSImage *) snapshotFromRect: (NSRect)aRect
{
	id viewBackedItem = [self supervisorViewBackedAncestorItem];

	if (nil == viewBackedItem || nil == [[viewBackedItem supervisorView] window])
		return nil;

	NSRect rectInView = [self convertRect: aRect toItem: viewBackedItem];
	ETWindowItem *windowItem = [viewBackedItem windowItem];

	if (nil != windowItem)
	{
		/* We exclude the window border and title bar because the display 
		   view is the window content view and never the window view. */
		rectInView = [windowItem convertDecoratorRectToContent: rectInView];
	}

	return [[NSImage alloc] initWithView: [viewBackedItem displayView] fromRect: rectInView];
}

- (NSAffineTransform *) boundsTransform
{
	NSAffineTransform *transform = [NSAffineTransform transform];

	if ([self isFlipped])
	{
		[transform translateXBy: 0.0 yBy: [self height]];
		[transform scaleXBy: 1.0 yBy: -1.0];
	}

	return transform;
}

- (void) drawRect: (NSRect)aRect
{
	if ([self supervisorView] != nil)
	{
		[[self displayView] displayRectIgnoringOpacity: aRect 
		                                     inContext: [NSGraphicsContext currentContext]];
	}
	else
	{
		NSAffineTransform *transform = [self boundsTransform];
		[transform concat];

		[self render: nil dirtyRect: aRect inContext: nil];

		[transform invert];
		[transform concat];
	}
}

/* Filtering */

- (BOOL) matchesPredicate: (NSPredicate *)aPredicate
{
	id subject = [self subject];
	BOOL isValidMatch = NO;

	@try
	{
		// TODO: Better custom evaluation with a wrapper object that 
		// redirects -valueForKeyPath: use to -valueForProperty: on the 
		// common object value or dev collection (such as NSArray, NSSet etc.). 
		// Add -propertyAccessingProxy to NSObject to return this wrapper object.
		// Take note that NSPredicate cannot be told to use -valueForProperty:.
		if ([subject isCommonObjectValue])
		{
			isValidMatch = [aPredicate evaluateWithObject: self];
		}
		else
		{
			isValidMatch = [aPredicate evaluateWithObject: subject];
		}
	}
	@catch (NSException *exception)
	{
		if ([[exception name] isEqualToString: NSUndefinedKeyException])
		{
			return NO;
		}
		@throw;
	}

	return isValidMatch;
}

/* Events & Actions */

/** Returns the action handler associated with the receiver. See ETTool to 
know more about event handling in the layout item tree. */
- (id) actionHandler
{
	return [self valueForVariableStorageKey: kETActionHandlerProperty];
}

/** Sets the action handler associated with the receiver. */
- (void) setActionHandler: (id)anHandler
{
	[self willChangeValueForProperty: kETActionHandlerProperty];
	[self setValue: anHandler forVariableStorageKey: kETActionHandlerProperty];
	[self didChangeValueForProperty: kETActionHandlerProperty];
}

/** Returns NO when the receiver should be ignored by the tools for both 
hit tests and action dispatch. By default, returns YES, otherwise NO when 
-actionsHandler returns nil. */
- (BOOL) acceptsActions
{
	return ([self valueForVariableStorageKey: kETActionHandlerProperty] != nil);
}

/** Controls the automatic enabling/disabling of UI elements (such as menu 
items) that uses the responder chain to validate themselves, based on whether 
the receiver or its action handler can respond to the selector action that would 
be sent by the UI element in the EtoileUI responder chain. */
- (BOOL) validateUserInterfaceItem: (id <NSValidatedUserInterfaceItem>)anItem
{
// TODO: Remove when validation works correctly on GNUstep
#ifndef GNUSTEP
	SEL action = [anItem action];
	SEL twoParamSelector = NSSelectorFromString([NSStringFromSelector(action) 
		stringByAppendingString: @"onItem:"]);

	if ([self respondsToSelector: action])
		return YES;

	if ([[self actionHandler] respondsToSelector: twoParamSelector])
		return YES;

	return NO;
#endif
	return YES;
}

- (BOOL) respondsToSelector: (SEL)aSelector
{
	if ([super respondsToSelector: aSelector])
		return YES;

	SEL twoParamSelector = NSSelectorFromString([NSStringFromSelector(aSelector) 
		stringByAppendingString: @"onItem:"]);
	if ([[self actionHandler] respondsToSelector: twoParamSelector])
		return YES;

	if ([[self actionHandler] respondsToSelector: aSelector])
		return YES;

	return NO;
}

- (NSMethodSignature *) methodSignatureForSelector: (SEL)aSelector
{
	NSMethodSignature *sig = [super methodSignatureForSelector: aSelector];

	if (sig == nil)
	{
		SEL twoParamSelector = NSSelectorFromString([NSStringFromSelector(aSelector) 
		stringByAppendingString: @"onItem:"]);

		sig = [[self actionHandler] methodSignatureForSelector: twoParamSelector];
	}

	if (sig == nil)
	{
		sig = [[self actionHandler] methodSignatureForSelector: aSelector];
	}

	return sig;
}

- (void) forwardInvocation: (NSInvocation *)inv
{
	SEL selector = [inv selector];
	SEL twoParamSelector = NSSelectorFromString([NSStringFromSelector(selector) 
		stringByAppendingString: @"onItem:"]);
	id actionHandler = [self valueForVariableStorageKey: kETActionHandlerProperty];

	if ([actionHandler respondsToSelector: twoParamSelector])
	{
		id sender = nil;
		ETLayoutItem *item = self;

		[inv getArgument: &sender atIndex: 2];
		NSInvocation *twoParamInv = [NSInvocation invocationWithMethodSignature:
			[actionHandler methodSignatureForSelector: twoParamSelector]];
		[twoParamInv setSelector: twoParamSelector];
		[twoParamInv setArgument: &sender atIndex: 2];
		[twoParamInv setArgument: &item atIndex: 3];

		[twoParamInv invokeWithTarget: actionHandler];
	}
	else if ([actionHandler respondsToSelector: selector])
	{
		[inv invokeWithTarget: actionHandler];
	}
	else
	{
		[self doesNotRecognizeSelector: selector];
	}
}
/** Sets the target to which actions should be sent.

The target is retained and potential cycles are managed by COObjectGraphContext.
 
If a view that conforms to ETWidget protocol is set, updates the target set on 
the view.
 
The target must be a COObject or a view returned by -[ETLayoutItem view],
otherwise an NSInvalidArgumentException is raised.

See also -target and -setView:. */
- (void) setTarget: (id)aTarget
{
	INVALIDARG_EXCEPTION_TEST(aTarget, [aTarget isKindOfClass: [COObject class]]
		|| ([aTarget isView] && [aTarget owningItem] != nil));
	// NOTE: For missing value transformation
	NSParameterAssert([aTarget isKindOfClass: [NSString class]] == NO);

	/* When the target is not a COObject, persistentTargetOwner	tracks the item
	   that owns this target. */

	[self willChangeValueForProperty: kETTargetProperty];
	[self willChangeValueForProperty: @"persistentTarget"];
	[self willChangeValueForProperty: @"persistentTargetOwner"];

	[self setValue: aTarget forVariableStorageKey: kETTargetProperty];
	if ([[self view] isWidget])
	{
		
		[(id <ETWidget>)[self view] setTarget: aTarget];

	}
	[[self layout] syncLayoutViewWithItem: self];

	[self didChangeValueForProperty: @"persistentTargetOwner"];
	[self didChangeValueForProperty: @"persistentTarget"];
	[self didChangeValueForProperty: kETTargetProperty];
}

/** Returns the target to which actions should be sent.
 
If a view that conforms to ETWidget protocol is set, returns the target set on 
the view.
 
See also -setTarget:. */
- (id) target
{
	if ([[self view] isWidget])
		return [(id <ETWidget>)[self view] target];

	return [self valueForVariableStorageKey: kETTargetProperty];
}

/** Sets the action that can be sent by the action handler associated with 
the receiver.

If a view that conforms to ETWidget protocol is set, updates the action set on
the view.
 
See also -action and -setView:. */
- (void) setAction: (SEL)aSelector
{
	[self willChangeValueForProperty: kETActionProperty];
	[self willChangeValueForProperty: @"UIBuilderAction"];

	/* NULL and nil are the same, so a NULL selector removes any existing entry */
	[self setValue: NSStringFromSelector(aSelector) forVariableStorageKey: kETActionProperty];

	if ([[self view] isWidget])
	{
		[(id <ETWidget>)[self view] setAction: aSelector];
	}
	[[self layout] syncLayoutViewWithItem: self];

	[self didChangeValueForProperty: @"UIBuilderAction"];
	[self didChangeValueForProperty: kETActionProperty];
}

/** Returns the action that can be sent by the action handler associated with 
the receiver. 

If a view that conforms to ETWidget protocol is set, returns the action set on
the view.

See also -setAction:. */
- (SEL) action
{
	if ([[self view] isWidget])
		return [(id <ETWidget>)[self view] action];

	NSString *selString = [self valueForVariableStorageKey: kETActionProperty];

	if (selString == nil)
		return NULL;

	return NSSelectorFromString(selString);
}

/** Updates the subject 'value' property when the widget view value changed.

See also -subject. */
- (void) didChangeViewValue: (id)newValue
{
	//ETLog(@"Did Change view value to %@", newValue);

	/* Don't update the represented object while setting it or updating it */
	if (_isSettingRepresentedObject || _isSyncingViewValue || [self representedObject] == nil)
		return;

	[self setValue: newValue forProperty: kETValueProperty];
}

/** Updates the view 'object value' property when the represented object value changed. */
- (void) didChangeRepresentedObjectValue: (id)newValue
{
	//ETLog(@"Did Change represented object value to %@", newValue);
	_isSyncingViewValue = YES;
	[self syncView: [self view] withValue: newValue];
	_isSyncingViewValue = NO;
}

/* Editing */

/** Invokes -beginEditingForItem: on the action handler which makes the item view 
the first responder or the item when there is no view. */
- (void) beginEditing
{
	[[self actionHandler] beginEditingForItem: self];
}

/** Invokes -discardEditingForItem: on the action handler which in turn invokes 
-discardEditing on the item view when possible. */
- (void) discardEditing
{
	[[self actionHandler] discardEditingForItem: self];
}

/** Invokes -commitEditingForItem: on the action handler which in turn invokes 
-commitEditing on the item view when possible. */
- (BOOL) commitEditing
{
	return [[self actionHandler] commitEditingForItem: self];
}

/** Notifies the item it has begun to be edited.

This method is usually invoked by the item view or the action handler to allow  
the item to notify the controller item controller about the editing.

You can invoke it in an action handler method when you want the possibility  
to react with -commitEditingForItem: or -discardEditingForItem: to an early 
editing termination by the controller.<br />

See also -objectDidEndEditing:. */
- (void) subjectDidBeginEditingForProperty: (NSString *)aKey
                           fieldEditorItem: (ETLayoutItem *)aFieldEditorItem
{
	[[self firstResponderSharingArea] setActiveFieldEditorItem: aFieldEditorItem
													editedItem: self];
	// NOTE: We implement NSEditorRegistration to allow the view which are 
	// bound to an item with -bind:toObject:XXX to notify the controller transparently.
	[[[self controllerItem] controller] subjectDidBeginEditingForItem: self property: aKey];
}

/** Notifies the item the editing underway ended.

This method is usually invoked by the item view or the action handler to allow  
the item to notify the controller item controller about the editing.

You must invoke it in an action handler method when you have previously call 
-objectDidBeginEditing and your editor has finished to edit a property.<br />

See also -objectDidBeginEditing:. */
- (void) subjectDidEndEditingForProperty: (NSString *)aKey
{
	[[self firstResponderSharingArea] removeActiveFieldEditorItem];
	[[[self controllerItem] controller] subjectDidEndEditingForItem: self property: aKey];
	
}

- (NSString *) editedProperty
{
	return ([self valueKey] != nil ? [self valueKey] : kETValueProperty);
}

/** Returns the item, or a responder view inside it in case the item uses a 
widget view (either provided by the layout or as a simple widget view).

Used by -[ETFirstResponderSharingArea makeFirstResponder:] to determine the real 
responder.

If the receiver is returned, then first responder and focused item are one and 
the same.

See also -usesWidgetView, -[ETLayout responder] and -[NSView responder]. */
- (id) responder
{
	id responder = self;
	
	if ([self layout] != nil)
	{
		responder = [[self layout] responder];
	}
	else if ([self view] != nil)
	{
		responder = [[self view] responder];
	}
	ETAssert(responder != nil);
	ETAssert([responder isLayoutItem] || [responder isTool] || ([responder isView] && [self usesWidgetView]));
	return responder;
}

/** Returns self.
 
See -[ETResponder focusedItem]. */
- (ETLayoutItem *) candidateFocusedItem
{
	return self;
}

/** Returns a basic window item. */
- (ETWindowItem *) provideWindowItem
{
	return [ETWindowItem itemWithObjectGraphContext: [ETUIObject defaultTransientObjectGraphContext]];
}

- (BOOL) isLayerItem
{
    return NO;
}

- (void) setHostItem: (ETLayoutItemGroup *)host
{
    INVALIDARG_EXCEPTION_TEST(host, host != self);
    if ([self valueForVariableStorageKey: kETParentItemProperty] != nil)
    {
        [NSException raise: NSInternalInconsistencyException
                    format: @"The receiver must have no parent to set a host item."];
    }
    
    [self willChangeValueForProperty: @"hostItem"];
    [self setValue: host forVariableStorageKey: @"hostItem"];
    [self didChangeValueForProperty: @"hostItem"];
}

- (void) willChangeValueForEmbeddingProperty: (NSString *)aKey
{
	if ([self isRoot] && _isEditingUI == NO)
	{
		[self willChangeValueForKey: aKey];
	}
	else
	{
		[self willChangeValueForProperty: aKey];
	}
}

- (void) didChangeValueForEmbeddingProperty: (NSString *)aKey
{
	if ([self isRoot] && _isEditingUI == NO)
	{
		[self didChangeValueForKey: aKey];
	}
	else
	{
		[self didChangeValueForProperty: aKey];
	}
}

@end
