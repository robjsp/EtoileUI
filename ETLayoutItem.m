/*  <title>ETLayoutItem</title>

	ETLayoutItem.m
	
	<abstract>Description forthcoming.</abstract>
 
	Copyright (C) 2007 Quentin Mathe
 
	Author:  Quentin Mathe <qmathe@club-internet.fr>
	Date:  May 2007
 
	Redistribution and use in source and binary forms, with or without
	modification, are permitted provided that the following conditions are met:

	* Redistributions of source code must retain the above copyright notice,
	  this list of conditions and the following disclaimer.
	* Redistributions in binary form must reproduce the above copyright notice,
	  this list of conditions and the following disclaimer in the documentation
	  and/or other materials provided with the distribution.
	* Neither the name of the Etoile project nor the names of its contributors
	  may be used to endorse or promote products derived from this software
	  without specific prior written permission.

	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
	AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
	IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
	ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
	LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
	CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
	SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
	INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
	CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
	ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
	THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <EtoileFoundation/NSIndexPath+Etoile.h>
#import <EtoileFoundation/NSObject+Model.h>
#import <EtoileUI/ETLayoutItem.h>
#import <EtoileUI/ETLayoutItem+Events.h>
#import <EtoileUI/ETLayoutItemGroup.h>
#import <EtoileUI/ETWindowItem.h>
#import <EtoileUI/ETStyleRenderer.h>
#import <EtoileUI/ETView.h>
#import <EtoileUI/ETContainer.h>
#import <EtoileUI/ETInspector.h>
#import <EtoileUI/NSView+Etoile.h>
#import <EtoileUI/ETCompatibility.h>

#define DETAILED_DESCRIPTION
#define PROVIDER_CONTAINER [[self baseItem] container]
#define PROVIDER_SOURCE [PROVIDER_CONTAINER source]
/* Don't forget that -variableProperties creates the property dictionary */
#define VARIABLE_PROPERTIES ((NSMutableDictionary *)[self variableProperties])

#define ETUTIAttribute @"uti"

@interface ETLayoutItem (Private)
- (void) setImage: (NSImage *)img;
- (void) setIcon: (NSImage *)img;
- (void) layoutItemViewFrameDidChange: (NSNotification *)notif;
- (void) checkDecoration;
- (void) checkDecorator;
@end

@interface ETLayoutItem (SubclassVisibility)
- (void) setDisplayView: (ETView *)view;
@end

/** Various approaches exists to customize layout items look rendering. 

	If you don't plan to rely on your object model, you can simply add to each 
	layout item a custom view  that already knows how to render/display itself.
	Usually you want something which allows to uses the object model properties
	and enables less crude or low-level rendering than an NSView subclass.
	
	If you want to render a layout item in a specific way, you can subclass
	ETLayoutItem and override -render method. This works pretty well if you are
	for example creating a photo collection display system. By combining 
	ETPhotoLayoutItem and ETFlowLayout plugged in a container, you can get a 
	full-featured photo view very easily. By subclassing ETFlowLayout in a new
	ETPhotoLayout class you would even gain more finer control on the layout 
	process itself if you think it's necessary.
	
	If you want to share the look of the rendering between several layout item
	kinds and desires the possibility to save it as a style or edit this render 
	process in a textual/script form, the best solution is to implement a 
	distinct ETRendererStyle sublass.
	
	Most of time, you want a quick yet quite flexible solution without any 
	subclassing, that's why the common solution is to implemente ETLayout
	delegate method called -layout:renderLayoutItem:. With this method you will
	be able to customize the rendering of layout items on the fly depending on
	the layout settings which may change between each rendering. */


@implementation ETLayoutItem

+ (ETLayoutItem *) layoutItem
{
	return (ETLayoutItem *)AUTORELEASE([[self alloc] init]);
}

+ (ETLayoutItem *) layoutItemWithView: (NSView *)view
{
	return (ETLayoutItem *)AUTORELEASE([[self alloc] initWithView: view]);
}

+ (ETLayoutItem *) layoutItemWithValue: (id)value
{
	return (ETLayoutItem *)AUTORELEASE([[self alloc] initWithValue: value]);
}

+ (ETLayoutItem *) layoutItemWithRepresentedObject: (id)object
{
	return (ETLayoutItem *)AUTORELEASE([[self alloc] initWithRepresentedObject: object]);
}

- (id) init
{
	return [self initWithView: nil value: nil representedObject: nil];
}

- (id) initWithValue: (id)value
{
	return [self initWithView: nil value: value representedObject: nil];
}

- (id) initWithRepresentedObject: (id)object
{
	return [self initWithView: nil value: nil representedObject: object];
}

- (id) initWithView: (NSView *)view
{
	return [self initWithView: view value: nil representedObject: nil];
}

- (id) initWithView: (NSView *)view value: (id)value representedObject: (id)repObject
{
    self = [super init];
    
    if (self != nil)
    {
		_variableProperties = nil; /* Lazy init in -variableProperties */
		_parentLayoutItem = nil;
		//_decoratorItem = nil;
		[self setDecoratedItem: nil];
		[self setView: view];
		[self setVisible: NO];
		[self setStyleRenderer: AUTORELEASE([[ETSelection alloc] init])];
		[self setValue: value];
		[self setRepresentedObject: repObject];
    }
    
    return self;
}

- (oneway void) release
{
	/* Note whether the next release call will deallocate the receiver, because 
	   once the receiver is deallocated you have no way to safely learn if self
	   is still valid or not.
	   Take note the retain count is NSExtraRefCount plus one. */
	BOOL isDeallocated = (NSExtraRefCount(self) == 0);
	BOOL hasRetainCycle = (_view != nil);

	[super release];

	/* Tear down the retain cycle owned by the receiver.
	   By releasing us, we release _view.
	   If we got deallocated by [super release], self and _view are now
	   invalid and we must never use them (by sending a message for example).  */
	if (hasRetainCycle && isDeallocated == NO
	  && NSExtraRefCount(self) == 0 && NSExtraRefCount(_view) == 0)
	{
		DESTROY(self);
	}
}

- (void) dealloc
{
	DESTROY(_variableProperties);
	/* Don't release decorated item (weak reference) */
	if (_decoratorItem != self)
		DESTROY(_decoratorItem);
    DESTROY(_view);
	DESTROY(_value);
	DESTROY(_modelObject);
	_parentLayoutItem = nil; /* weak reference */
    
    [super dealloc];
}

/** Returns a shallow copy of the receiver without copying the view, the styles, 
	the represented object and the children items if the receiver is an 
	ETLayoutItemGroup related classes. 
	Take note that a deep copy of the decorators is created and no view 
	reference is kept, -view will return nil for the copied item.
	TODO: Implement decorators copying that is currently missing.*/
- (id) copyWithZone: (NSZone *)zone
{
	ETLayoutItem *item = [[[self class] alloc] initWithView: nil 
	                                                  value: [self value] 
	                                      representedObject: [self representedObject]];

	[item setName: [self name]];
	[item setStyleRenderer: [self renderer]];
	[item setFrame: [self frame]];
	[item setAppliesResizingToBounds: [self appliesResizingToBounds]];
	
	return item;
}

/** Returns a deep copy of the receiver by copying the view and all its 
	subview hierarchy, the styles, the decorators, the represented object and 
	all the descendant children items if the receiver is an ETLayoutItemGroup r
	elated classes. 
	All copied collections are mutable (styles, decorators, representedObject, 
	children items). 
	TODO: Implement styles copying that is currently missing (decorators too in 
	-copyWithZone:). */
- (id) deepCopy
{
	ETLayoutItem *item = [self copyWithZone: NULL];
	id repObjectCopy = nil;

	// TODO: We probably want to handle different kind of copies on the model. 
	// For example, with values objects a shallow copy of an array is a bad 
	// idea, so would be a deep copy for an array of entity objects.
	// A good solution may be to override -copyWithZone: and/or 
	// -mutableCopyWithZone: in collection classes to map each 
	// element based on its model description to a particular copy operation:
	// - value object -> copy
	// - entity object -> don't copy 
	// In this way, we could handle copy in a more meaningful way without having 
	// to decide between only the two crude copy styles deep and shallow. To 
	// achieve we need a model description (metamodel) framework like Magritte.
	// We still need to decide what should the default between shallow and deep 
	// for the represented object (model) when no model description is available.
	if ([[self representedObject] conformsToProtocol: @protocol(NSMutableCopying)])
	{
		repObjectCopy = [[self representedObject] mutableCopy];
	}
	else if ([[self representedObject] conformsToProtocol: @protocol(NSCopying)])
	{
		repObjectCopy = [[self representedObject] copy];
	}
	[item setRepresentedObject: AUTORELEASE(repObjectCopy)];

	// NOTE: When a  view like a slider is used, it is interesting to support
	// true copy in order to clone existing layout items. An example could be
	// picking a layout item from an UI object palette (in Gorm-like style 
	// development).
	if ([[self view] respondsToSelector: @selector(copyWithZone:)])
	{
		[item setView: [[self view] copy]];
	}

	return item;
}

- (NSString *) description
{
	NSString *desc = [super description];

#ifdef DETAILED_DESCRIPTION	
	desc = [@"<" stringByAppendingFormat: @"%@ meta: %d id: %@, ipath: %@, "
		@"selected: %d, repobject: %@ view: %@>", desc, [self UIMetalevel], 
		[self identifier], [[self indexPath] keyPath], [self isSelected], 
		[[self representedObject] primitiveDescription], [self view]];
#else
	desc = [@"<" stringByAppendingFormat: @"%@ id: %@, selected:%d>", 
		desc, [self identifier], [self isSelected]];
#endif
	
	return desc;
}

/** Returns the root item of the layout item tree to which the receiver
	belongs to. 
	This method never returns nil because the returned value is equal to self
	when the receiver has no parent item. */
- (id) rootItem
{
	if ([self parentLayoutItem] != nil)
	{
		return [[self parentLayoutItem] rootItem];	
	}
	else
	{
		return self;
	}
}

/** Returns the layout item group which controls the receiver. An item group
	is said to control descendant items when -representedPathBase returns a non
	nil or blank value.
	A base item usually handles events and data source mutation for all 
	descendant items belonging to it. All child items are controlled by a common 
	base item until a descendant item is declared as a new base item (by 
	providing a represented path base). See also -representedPathBase, 
	-[ETContainer representedPath], -[ETContainer source], -[ETLayoutItemGroup 
	baseContainer].
	If an item group uses a source, it is automatically bound to a represented 
	path base.
	This method will return nil when the receiver isn't a base item, hasn't yet 
	been added as a descendant of a base item or has just been removed as a 
	descendant of a base item. */
- (id) baseItem
{
	if ([self hasValidRepresentedPathBase])
	{
		return self;
	}
	else
	{
		return [[self parentLayoutItem] baseItem];
	}
}

- (BOOL) hasValidRepresentedPathBase
{
	return ([self representedPathBase] != nil 
		&& [[self representedPathBase] isEqual: @""] == NO);
}

/** Returns the layout item group to which the receiver belongs to. 
	For the root item as returned by -rootItem, the returned value is always 
	nil. 
	This method will return nil when the receiver hasn't yet been added to an
	item group or has just been removed from an item group. */
- (ETLayoutItemGroup *) parentLayoutItem
{
	return _parentLayoutItem;
}

/** Returns the layout item group to which the receiver belongs to. 
	If parent parameter is nil, the receiver becomes a root item. 
	You must never call this method directly unless your code belongs to a 
	subclass. If you need to change the parent of a layout item, use -addItem:, 
	-removeFromParent and other similar methods provided to manipulate item 
	collection owned by an item group. */
- (void) setParentLayoutItem: (ETLayoutItemGroup *)parent
{
	//ETLog(@"For item %@ with supervisor view %@, modify the parent item from "
	//	"%@ to %@", self, [self supervisorView], _parentLayoutItem, parent, self);

	_parentLayoutItem = parent;
}

/** Detaches the receiver from the layout item group it belongs to.
	You are in charge of retaining the receiver, otherwise it could be 
	deallocated if no other objects retains it. */
- (void ) removeFromParent
{
	if ([self parentLayoutItem] != nil)
	{
		/* -removeItem: will release us, so to be sure we won't deallocated 
		   right now we use retain/autorelease */
		RETAIN(self);
		[[self parentLayoutItem] removeItem: self];
		AUTORELEASE(self);
	}
}

- (ETContainer *) closestAncestorContainer
{
	if ([[self displayView] isKindOfClass: [ETContainer class]])
		return (ETContainer *)[self displayView];
		
	if ([self parentLayoutItem] != nil)
	{
		return [[self parentLayoutItem] closestAncestorContainer];
	}
	else
	{
		ETLog(@"WARNING: Found no ancestor container by ending lookup on %@", self);
		return nil;
	}
}

- (ETView *) closestAncestorDisplayView
{
	if ([self displayView] != nil)
		return [self displayView];

	if ([self parentLayoutItem] != nil)
	{
		return [[self parentLayoutItem] closestAncestorDisplayView];
	}
	else
	{
		ETLog(@"WARNING: Found no ancestor display view by ending lookup on %@", self);
		return nil;
	}
}

/** Returns receiver index path relative to item parameter. 
	The index path is computed by climbing up the layout item tree until we 
	find item parameter and pushing parent relative index of each layout item 
	sequentially into an index path. 
	Passing nil is equivalent to passing the root item as returned by 
	-rootItem. If item is equal to self, the resulting index path is an blank 
	one (relative to itself). */
- (NSIndexPath *) indexPathFromItem: (ETLayoutItem *)item
{
	NSIndexPath *indexPath = nil;
	BOOL baseItemReached = (self == item);

	/* Handle nil item case which implies root item is the base item */
	if (item == nil && self == [self rootItem])
		baseItemReached = YES;
	
	if ([self parentLayoutItem] != nil && item != self)
	{
		indexPath = [[self parentLayoutItem] indexPathFromItem: item];
		if (indexPath != nil)
		{
			indexPath = [indexPath indexPathByAddingIndex: 
				[(ETLayoutItemGroup *)[self parentLayoutItem] indexOfItem: (id)self]];
		}
	}
	else if (baseItemReached)
	{
		indexPath = [NSIndexPath indexPath];
	}

	/* We return a nil index path only if we haven't reached the base item */   	
	return indexPath;
}

/** Returns item index path relative to the receiver.
	This method is equivalent to [item indexFromItem: self].
	If item doesn't belong to the layout item subtree of the receiver, nil is
	returned.
	Passing nil is equivalent to passing the root item as returned by 
	-rootItem, the returned value is always nil because the root item can never
	be a child of the receiver. If item is equal to self, the resulting index 
	path is an blank one (relative to itself). */
- (NSIndexPath *) indexPathForItem: (ETLayoutItem *)item
{
	return [item indexPathFromItem: self];
}

/** Returns absolute index path of the receiver by collecting index of each
	parent layout item until the root layout item is reached (when -parentItem
	returns nil). 
	This method is equivalent to [[self rootItem] indexPathForItem: self]. */
- (NSIndexPath *) indexPath
{
	// TODO: Test whether it is worth to optimize or not
	return [[self rootItem] indexPathForItem: self];
}

/** Returns absolute path of the receiver by collecting the name of each
	parent layout item until the root layout item is reached (when -parentItem
	returns nil). 
	This method is equivalent to [[self rootItem] pathForIndexPath: 
	[[self rootItem] indexPathForItem: self]]. */
- (NSString *) path
{
	/* We rebuild the path by chaining names of the layout item tree to which 
	   we belong. */
	NSString *path = @"/";
	
	if ([self parentLayoutItem] != nil)
	{
		path = [[[self parentLayoutItem] path] 
			stringByAppendingPathComponent: [self identifier]];
	}
	
	return path;
}

/** Returns the represented path. */
- (NSString *) representedPath
{
	NSString *path = [self representedPathBase];
	
	if (path == nil)
	{
		if ([self parentLayoutItem] != nil)
		{
			path = [[self parentLayoutItem] representedPath];
			path = [path stringByAppendingPathComponent: [self identifier]];
		}
		else
		{
			path = [self identifier];
		}
	}
	
	return path;
}

/** Returns the represented path base which is nil by default. This represented
	path base can be provided by a container, then allowing to build 
	represented paths for every descendant layout items which don't specify 
	their own custom represented path base (in other words when this method 
	returns nil). 
	By setting the represented path of a container, the related layout item 
	group is able to provide a represented path base automatically used by 
	descendant items. This represented path base is valid until a descendant 
	provides a new represented path base. */
- (NSString *) representedPathBase
{
	return nil;
}

/** Returns the identifier associated with the layout item. By default, the
	returned value is the name. If -name returns nil or an empty string, the
	identifier is a string made of the index used by the parent item to 
	reference the receiver. */
- (NSString *) identifier
{
	NSString *identifier = [self name];
	
	if (identifier == nil || [identifier isEqual: @""])
	{
		id parentRepObject = [[self parentLayoutItem] representedObject];
		
		// TODO: Should try to retrieve -UniqueID, -UUID and -UUIDString
		/* -identifierAtIndex: is implemented by some classes like NSDictionary */
		if ([parentRepObject isCollection] && [parentRepObject isEmpty] == NO
		 && [parentRepObject respondsToSelector: @selector(identifierAtIndex:)]
		 && [PROVIDER_CONTAINER checkSourceProtocolConformance] == 3)
		{
			unsigned int index = [[self parentLayoutItem] indexOfItem: self];
			identifier = [parentRepObject identifierAtIndex: index];
		}
	}

	/*if (identifier == nil || [identifier isEqual: @""])	
		identifier = [self name];*/

	
	if (identifier == nil || [identifier isEqual: @""])
	{
		identifier = [NSString stringWithFormat: @"%d", 
			[(ETLayoutItemGroup *)[self parentLayoutItem] indexOfItem: (id)self]];
	}
	
	return identifier;
}

// FIXME: we should probably define -displayName and may be -name on NSObject
- (NSString *) displayName
{
	id name = [self name];
	
	if (name == nil)
	{
		if ([self view] != nil)
		{
			name = [[self view] description];
		}
		else if ([self value] != nil)
		{
			name = [[self value] stringValue];
		}
		else if ([self representedObject] != nil)
		{
			/* Makes possible to keep an identical display name between an 
			   item and all derived meta items (independently of their meta 
			   levels). */
			name = [[self representedObject] displayName];
		}
		else
		{
			name = [super displayName];
		}
	}
		
	return name;
}

/** Returns the name associated with the layout item.
	Take note the returned value can be nil or an empty string. */
- (NSString *) name
{
	return _name;
}

/** Sets the name associated with the layout item.
	Take note the returned value can be nil or an empty string. */
- (void) setName: (NSString *)name
{
	ASSIGN(_name, name);
}

/** Returns a value which is used when only one value can be displayed like in
	a table view with a single column or an icon view with a rudimentary icon 
	unit cell. */
- (id) value
{
	return _value;
}

/** Sets a value to be used when only one value can be displayed like in
	a table view with a single column or an icon view with a rudimentary icon 
	unit cell.
	Most of time this method can be used as a conveniency which allows to 
	bypass -valueForProperty: and -setValue:forProperty: when the layout item
	is used by combox box, single column table view, line view made of simple
	images etc. */
- (void) setValue: (id)value
{
	/*if ([value isCommonObjectValue] == NO)
	{
		[NSException raise: NSInvalidArgumentException format: @"Value %@ must "
			@"be a common object value to be set in %@", value, self];
		return;
	}*/
	
	ASSIGN(_value, value);
	
#if 0
	if ([_value isKindOfClass: [NSImage class]])
	{
		/*ETImageStyle *imgStyle = [ETImageStyle styleWithImage: (NSImage *)_value];
		
		[self setDefaultFrame: ETMakeRect(NSZeroPoint, [_value size])];
		[self setStyleRenderer: imgStyle];*/
	}
	else if ([_value isKindOfClass: [NSString class]])
	{
	
	}
	else if ([_value isKindOfClass: [NSAttributedString class]])
	{
	
	}
#endif
}

/** Returns model object which embeds the representation of what the layout 
	item displays. When a new layout item is created, by default it uses a
	dictionary as a rudimentary model object. */
- (id) representedObject
{
	return _modelObject;
}

/** Sets model object which embeds the representation of what the layout 
	item displays. 
	If you want to restore default model object initally set, pass a mutable 
	dictionary instance as parameter to this method.
	See -representedObject for more details. */
- (void) setRepresentedObject: (id)modelObject
{
	ASSIGN(_modelObject, modelObject);
}

- (NSView *) view
{
	id wrappedView = [[self supervisorView] wrappedView];
	
	if (wrappedView != nil)
	{
		// FIXME: Simplify by hiding these details, the next two branches could
		// be removed now I think...
		if ([wrappedView isKindOfClass: [NSScrollView class]])
		{
			return [wrappedView documentView];
		}
		else if ([wrappedView isKindOfClass: [NSBox class]])
		{
			return [wrappedView contentView];
		}
		else
		{
			return wrappedView;
		}
	}
	else
	{
		return [self supervisorView];
	}
}

- (void) setView: (NSView *)newView
{
	BOOL resizeBoundsActive = [self appliesResizingToBounds];
	id view = [[self supervisorView] wrappedView];
	// NOTE: Frame is lost when newView becomes a subview of an ETView instance
	NSRect newViewFrame = [newView frame];
	
	/* Tear down the current view */
	if (view != nil)
	{
		/* Restore view initial state */
		[view setFrame: [self defaultFrame]];
		//[view setRenderer: nil];
		/* Stop to observe notifications on current view and reset bounds size */
		[self setAppliesResizingToBounds: NO];
	}
	_defaultFrame = NSZeroRect;
	
	/* Inserts the new view */
	
	/* When the view isn't an ETView instance, we wrap it inside a new ETView 
	   instance to have -drawRect: asking the layout item to render by itself.
	   Retrieving the display view automatically returns the innermost display
	   view in the decorator item chain. */
	if ([newView isKindOfClass: [ETView class]])
	{
		[self setSupervisorView: (ETView *)newView];
	}
	else if ([newView isKindOfClass: [NSView class]])
	{
		if ([self supervisorView] == nil)
		{
			ETView *wrapperView = [[ETView alloc] initWithFrame: [newView frame] 
													 layoutItem: self];
			[self setSupervisorView: wrapperView];
			RELEASE(wrapperView);
		}
		[[self supervisorView] setWrappedView: newView];
	}
	
	/* Set up the new view */
	if (newView != nil)
	{
		//[newView setRenderer: self];
		[self setDefaultFrame: newViewFrame];
		if (resizeBoundsActive)
			[self setAppliesResizingToBounds: YES];
	}
}

- (void) setDecoratedView: (NSView *)newView
{
	id view = [[self supervisorView] wrappedView];
	// NOTE: Frame is lost when newView becomes a subview of an ETView instance
	NSRect newViewFrame = [newView frame];
	
	/* Tear down the current view */
	if (view != nil)
	{
		/* Restore view initial state */
		[view setFrame: [self defaultFrame]];  /* -defaultFrame returns display view frame */
	}
	
	/* Inserts the new view */
	
	if ([self supervisorView] == nil)
	{
		ETView *wrapperView = [[ETView alloc] initWithFrame: [newView frame] 
												 layoutItem: self];
		[self setSupervisorView: wrapperView];
		RELEASE(wrapperView);
	}
	[[self supervisorView] setWrappedView: newView];
	
	/* Set up the new view */
	if (newView != nil)
	{
		[self setDefaultFrame: newViewFrame];
	}
}

/* Key Value Coding */

- (id) valueForUndefinedKey: (NSString *)key
{
	//ETLog(@"WARNING: -valueForUndefinedKey: %@ called in %@", key, self);
	return [VARIABLE_PROPERTIES objectForKey: key]; /* May return nil */
}

- (void) setValue: (id)value forUndefinedKey: (NSString *)key
{
	//ETLog(@"WARNING: -setValue:forUndefinedKey: %@ called in %@", key, self);
	[VARIABLE_PROPERTIES setObject: value forKey: key];
}

/* Property Value Coding */

/** Returns a value of the model object -representedObject, usually by 
	calling -valueForProperty: else -valueForKey: with key parameter. By default 
	the model object is a simple dictionary which gets returned by both this 
	method and -representedObject method.
	When the model object is a custom one, it must implement -valueForProperty:
	and -setValue:forProperty: or conform to NSKeyValueCoding protocol. */
- (id) valueForProperty: (NSString *)key
{
	id modelObject = [self representedObject];
	id value = nil;

	/* Basic version which doesn't fetch property value beyond the represented 
	   object, even if this represented object represents another object too. */
	if (modelObject != nil && [[modelObject properties] containsObject: key])
	{
		if ([modelObject isLayoutItem])
		{
			value = [modelObject valueForKey: key];
		}
		else
		{
			value = [modelObject valueForProperty: key];
		}
		//value = [modelObject valueForKey: key];
	}
	else
	{
		value = [self valueForKey: key];
	}	
	
	return value;
}

/** Sets a value identified by key of the model object returned by 
	-representedObject. 
	See -valueForProperty: for more details. */
- (BOOL) setValue: (id)value forProperty: (NSString *)key
{
	id modelObject = [self representedObject];
	BOOL result = YES;

	/* Basic version which doesn't propagate property editing beyond the represented 
	   object, even if this represented object represents another object too. */
	if (modelObject != nil && [[modelObject properties] containsObject: key])
	{
		if ([modelObject isLayoutItem])
		{
			[modelObject setValue: value forKey: key];
		}
		else
		{
			result = [modelObject setValue: value forProperty: key];
		}
		//[modelObject setValue: value forKey: key];
	}
	else
	{
		[self setValue: value forKey: key];
	}
	
	// FIXME: Implement
	//[self didChangeValueForKey: key];
	
	return result;
}

- (NSArray *) properties
{
	NSArray *properties = [NSArray arrayWithObjects: @"identifier", @"name", 
		@"x", @"y", @"width", @"height", @"view", @"selected", 
		@"visible", @"image", @"frame", @"representedObject", 
		@"parentLayoutItem", @"UIMetalevel", @"UIMetalayer", nil];

	properties = [[VARIABLE_PROPERTIES allKeys] arrayByAddingObjectsFromArray: properties];
		
	return [[super properties] arrayByAddingObjectsFromArray: properties];
}

- (NSDictionary *) variableProperties
{
	if (_variableProperties == nil)
		ASSIGN(_variableProperties, [NSMutableDictionary dictionary]);
		
	return _variableProperties;
}

/** Returns the metalevel in the UI domain.
	Three metamodel variants exist in Etoile:
	- Object
	- Model
	- UI
	Each metamodel domain is bound to an arbitrary number of metalevels (0, 1, 
	3, etc.). Metalevels are expressed as positive integers and are usually 
	not limited to a max value.
	A new metalevel is entered, each time -setRepresentedObject: is called with 
	an object of the same type than the receiver. The type interpretation of 
	both the receiver and the paremeter varies with the metamodel domain. For UI
	domain, both must include ETLayoutItem type or subtype in their type.
	For example:
	
	id item1 = [ETLayoutItem layoutItem];
	
	item2 = [ETLayoutItem layoutItemWithRepresentedObject: item1];
	item3 = [ETLayoutItem layoutItemWithRepresentedObject: [NSImage image]];
	item4 = [ETLayoutItem layoutItemWithRepresentedObject: item2];
	
	If we call -metalevel method on each item, the output is the following:
	- item1 will return 0
	- item2 will return 1
	- item3 will return 0
	- item4 will return 2 */
- (unsigned int) UIMetalevel
{
	if ([self isMetaLayoutItem])
	{
		unsigned int metalevel = 0;
		id repObject = [self representedObject];
		
		/* An item can be a meta layout item by using a view as represented object */
		if ([repObject respondsToSelector: @selector(UIMetalevel)] )
			metalevel = [repObject UIMetalevel];
		
		return ++metalevel;
	}
	else
	{
		return 0;
	}
}

/** Returns the UI metalayer the receiver belongs to.
	The metalayer is the metalevel which owns the receiver. For UI metamodel 
	domain, the ownership to a metalayer results of existing parent/child 
	relationships in the layout item tree.
	An item has equal UIMetalevel and UIMetalayer when no parent with superior
	UIMetalevel value can be found by climbing up the layout item tree until the
	root item is reached. The root item UI metalevel is 0, thus all descendant
	items can create metalayers by having a superior UI metalevel. 
	A child item can introduce a new metalayer by having a UI metalevel 
	superior to the last parent item defining a UI metalayer. 
	Finally in a metalayer, objects can have arbitrary metalevel. 
	For example:
	
		Item Tree		Metalevel
	
	- root item	0			(0)
	- item 1				(2)
		- child item 11		(1)
			- item 111		(4)
				- item 1111	(4)
				- item 1112	(0)
		- child item 12		(2)
	- item 2				(0)
		- item 21			(0)
		
	Available metalayers:
	- (0) item 0, 2, 21
	- (2) item 1, 11, 12
	- (4) item 1111, 1111, 1112
	
	No metalayer (1) exists with this layout item tree, because the only item
	bound to this metalevel is preempted by the metalayer (2) introduced with 
	'item 1'. */
- (unsigned int) UIMetalayer
{
	int metalayer = [self UIMetalevel];
	id parent = self;
	
	while ((parent = [parent parentLayoutItem]) != nil)
	{
		if ([parent UIMetalevel] > metalayer)
			metalayer = [parent UIMetalevel];
	}
	
	return metalayer;
}

// TODO: Rename -isMetalevelItem
- (BOOL) isMetaLayoutItem
{
	// NOTE: Defining the item as a meta item when a view is the represented 
	// object allows to read and write view values when the item is modified
	// with PVC. If the item is declared as a normal item, PVC will apply to
	// the item itself for all properties common to NSView and ETLayoutItem 
	// (mostly frame related properties).
	// See also -valueForProperty and -setValue:forProperty:
	return ([[self representedObject] isKindOfClass: [ETLayoutItem class]]
		|| [[self representedObject] isKindOfClass: [NSView class]]);
}

#if 0
- (BOOL) isPropertyItem
{
	return [[self representedObject] isKindOfClass: [ETProperty class]];
}
#endif

- (BOOL) isGroup
{
	return NO;
}

- (void) didChangeValueForKey: (NSString *)key
{

}

/** Returns the display view of the receiver. The display view is the last
	supervisor view of the decorator item chain. Display view is an instance of 
	ETView class or subclasses.
	You can retrieve the outermost decorator of decorator item chain by calling
	-lastDecoratorItem.
	Take note there is usually only one decorator which is commonly used to 
	support scroll view. 
	See -setDecoratorItem: to know more. */
- (ETView *) displayView
{
	return [[self lastDecoratorItem] supervisorView];
}

/** Sets the display view of the receiver. Never calls this method directly 
	unless you write an ETLayoutItem subclass. 
	You must use -setDecoratorItem: if you want to modify the display view of 
	the receiver. */
- (void) setDisplayView: (ETView *)view
{
	if ([self decoratorItem] == nil)
		[view setLayoutItemWithoutInsertingView: self];
	ASSIGN(_view, view);
}

- (void) setSelected: (BOOL)selected
{
	//ETLog(@"Set layout item selection state %@", self);
	_selected = selected;
}

- (BOOL) isSelected
{
	return _selected;
}

- (void) setVisible: (BOOL)visible
{
	_visible = visible;
}

- (BOOL) isVisible
{
	return _visible;
}

/** Commonly used to select items which can be dragged or dropped in a dragging operation */
- (ETUTI *) type
{
	if ([self representedObject] == nil
	 && [[self representedObject] isKindOfClass: [NSDictionary class]] == NO)
	{
		// FIXME: Replace by [ETUTI typeForClass: [self class]]
		return NSStringFromClass([self class]);
	}	
	else if ([[self representedObject] valueForProperty: ETUTIAttribute] != nil)
	{
		return [[self representedObject] valueForProperty: ETUTIAttribute];
	}
	else
	{
		// FIXME: Replace by [ETUTI typeForClass: [self class]]
		return NSStringFromClass([[self representedObject] class]);
	}
}

/** Returns the decorator item when the receiver uses a view. The decorator 
	item is the receiver itself by default. 
	The decorator item is in charge of managing the item view and must not 
	break the following rules:
	- [self displayView] must return [[self decoratorItem] view]
	- [self view] must return [[[self decoratorItem] view] wrappedView] */
- (ETLayoutItem *) decoratorItem
{
	return _decoratorItem;
}

- (void) checkDecoration
{
	id decorator = [self decoratorItem];
	
	if (decorator == nil)
		return;

	/* Verify the proper set up of the current decorator */
	[decorator checkDecorator];

	// NOTE: Next assertion would fail if -[NSWindowItem supervisorView] is 
	// modified to return nil.
	NSAssert1([self displayView] != nil, @"Display view must no be nil when a "
		@"decorator is set on item %@", self);
	NSAssert2([[decorator displayView] isEqual: [self displayView]], 
		@"Decorator display view %@ must be decorated item display view %@", 
		[decorator displayView], [self displayView]);

}

- (void) checkDecorator
{
	NSAssert2([self parentLayoutItem] == nil, @"Decorator %@ "
		@"must have no parent %@ set", self, [self parentLayoutItem]);

	// TODO: If there is a window item in the decorator chain, the receiver 
	// supervisor view or the outermost supervisor view (display view) don't 
	// match the expectation of the following assertions. Find a way to get rid 
	// of this special case. See -[ETWindowItem superisorView] too..
	if ([self isMemberOfClass: [ETLayoutItem class]])
	{
		NSAssert2([[self supervisorView] isKindOfClass: [ETView class]], 
			@"Decorator %@ must have a supervisor view %@ of type ETView", 
			self, [self supervisorView]);
	}
	if ([[self lastDecoratorItem] isMemberOfClass: [ETLayoutItem class]])
	{
		NSAssert2([[self displayView] isKindOfClass: [ETView class]], 
			@"Decorator %@ must have display view %@ of type ETView", 
			self, [self displayView]);
	}
}

/** Sets the decorator item in order to customize the item view border. The 
	decorator item is typically used to display a title bar making possible to
	manipulate the item directly (by drag and drop). The other common use is 
	putting the item view inside a scroll view. 
	By default, the decorator item is nil. */
- (void) setDecoratorItem: (ETLayoutItem *)decorator
{
	[self checkDecoration]; /* Ensure existing decorator is valid */

	if ([decorator isEqual: [self decoratorItem]])
		return;

	if ([decorator canDecorateItem: self] || decorator == nil)
	{
		/* Memorize our decorator to let the new decorator inserts itself into it */
		id existingDecorator = [self decoratorItem];
		/* Item could have a decorator, so [[item supervisorView] superview] would
	       not give the parent view in this case but the decorator view. */
		id parentView = [[self displayView] superview];
		NSRect frame = [[self displayView] frame];
		// parentView isEqual: [[item parentLayoutItem] view]
		
		[[self displayView] removeFromSuperview];

		// NOTE: Important to retain decorator before calling 
		// -setDecoratedItem: which is going to decrease its retain count
		// by removing it from its parent
		RETAIN(existingDecorator);
		RETAIN(decorator);
		
		/* Must be done before dismantling the existing decorator, otherwise 
		   -handleDecorateItem: nil inView: parentView doesn't remove the 
		   existing decorator view. More precisely, it doesn't reinserts the
		   receiver supervisor view but the one currently in use. */
		ASSIGN(_decoratorItem, decorator),

		/* Dismantle existing decorator */
		[existingDecorator setDecoratedItem: nil];
		[existingDecorator handleDecorateItem: nil inView: nil];
		
		/* Set up new decorator */
		[decorator setDecoratedItem: self];
		[decorator handleDecorateItem: self inView: parentView];

		if ([self respondsToSelector: @selector(container)])
		{
			[[self container] didChangeDecoratorOfItem: self];
		}
		else
		{
			ETLog(@"WARNING: Item %@ doesn't use a container", self);
		}
		
		/* Restore supervisor view as display view if no decorator is set */
		if (decorator == nil) // && [self view] != nil
		{
			NSAssert2([[self displayView] superview] == nil, @"If %@ decorator "
				@"was just removed without being replaced, the display view of "
				@"%@ must have no superview", existingDecorator, self);
			[parentView addSubview: [self displayView]];
			/* When a decorator view has been resized and/moved, we must reflect 
			   it on the embedded view which may not have been resized.
			   Not updating the frame is especially visible when the view is 
			   used as a document view within a scroll view and this scroll view 
			   frame is modified. Switching to a layout view reveals the issue
			   even more clearly. */
			[self setFrame: frame];
		}
		else
		{
				/* Verify new decorator has been correctly inserted */
		/* Tested by -checkDecoration...
		NSAssert3([[self displayView] isEqual: [decorator displayView]], @"New "
			@"display view %@ of item %@ must be the display view of the new "
			@"decorator %@", [self displayView], self, [decorator displayView]);*/
		
		// If window is bound directly to a layout item with a window item, this 
		// assertion fails because existingDecorator is nil and 
		// [existingDecorator handleDecorateItem: nil inView: nil]; won't 
		// dismantle the window
		/*NSAssert3([[[self supervisorView] superview] isEqual: parentView] == NO,
			@"New parent view %@ of item %@ must not be its old parent view %@", 
			[[self supervisorView] superview], self, parentView);*/
		}
		
		RELEASE(existingDecorator);
		RELEASE(decorator);
		
		[self checkDecoration];
	}
}

- (ETLayoutItem *) decoratedItem
{
	return _decoratedItem;
}

- (void) setDecoratedItem: (ETLayoutItem *)item
{
	/* Weak reference because decorator retains us */
	_decoratedItem = item;
	[self removeFromParent]; /* Just to be sure the decorator has no parent */
}

- (ETLayoutItem *) lastDecoratorItem
{
	id decorator = [self decoratorItem];
	
	if (decorator != nil)
	{
		return [decorator lastDecoratorItem];
	}
	else
	{
		return self;
	}
}

- (ETLayoutItem *) firstDecoratedItem
{
	id decorator = [self decoratedItem];
	
	if (decorator != nil)
	{
		return [decorator firstDecoratedItem];
	}
	else
	{
		return self;
	}
}

/** <override /> */
- (BOOL) canDecorateItem: (ETLayoutItem *)item
{
	return [item acceptsDecoratorItem: self];
}

/** <override />
	ETLayoutItem instances accept all decorator kinds.
	You can override this method to decide otherwise in your subclasses. For 
	example, ETWindowItem returns NO because a window unlike a view cannot 
	be decorated. */
- (BOOL) acceptsDecoratorItem: (ETLayoutItem *)item
{
	return YES;
}

/** <override-dummy /> 
    You can manipulate the receiver decorator chain in this method and access 
	both view and supervisor view of the decorated item, but you must not 
	manipulate item related decorator chain (by calling -[item displayView], 
	-[item decoratorItem] etc.) 
	Take in account that parentView and item can be nil. */
- (void) handleDecorateItem: (ETLayoutItem *)item inView: (ETView *)parentView 
//	oldDecorator: (ETLayoutItem *)existingDecorator
{
	/* Inserts decorated view */
	[self setDecoratedView: [item supervisorView]];
	
	/* If the decorated item display view was part of view tree, inserts the 
	   new display view into the existing parent view.
	   We don't insert the decorator supervisor view because this decorator 
	   could be a decorator chain (by being decorated itself too). The new 
	   display view is thus the supervisor view of the last decorator item. */
	if (parentView != nil)
	{
		/* No need to update the layout since the new display view will have 
		   the size and location of the previous one. Unlike when you add or
		   or remove an item which involves to recompute the layout. */
		//[self handleAttachViewOfItem: item];
		//NSLog(@"parent %@ parent view %@ item display view %@", [item parentLayoutItem],
		//	parentView, [item displayView]);
		[parentView addSubview: [self displayView]]; // More sure than [item displayView]
	}
	/*else
	{
		[[self displayView] removeFromSuperview];
	}*/

// -setDecoratorItem: isn't -insertDecoratorItem: so disabled the code below
#if 0	
	/* Inserts decorator view (as decorated view into the old item decorator) */
	if (existingDecorator != nil) // [[item displayView] isEqual: [item supervisorView]]
	{
		[self setDecoratorItem: existingDecorator];
	}
#endif
}

- (id) supervisorView
{
	return _view;
}

- (void) setSupervisorView: (ETView *)supervisorView
{
	id parent = [self parentLayoutItem];

	//if ([self decoratorItem] == nil)
		[supervisorView setLayoutItemWithoutInsertingView: self];
	ASSIGN(_view, supervisorView);
	
	if ([self decoratorItem] != nil)
	{
		id parentView = [[self displayView] superview];
		/* Usually results in [[self decoratorItem] setView: supervisorView] */
		[[self decoratorItem] handleDecorateItem: self inView: parentView];
	}
	else if (parent != nil)
	{
		[parent handleAttachViewOfItem: self];
	}
}

- (ETLayoutItem *) firstScrollViewDecoratorItem
{
	id decorator = self;
	
	while ((decorator = [decorator decoratorItem]) != nil)
	{
		if ([[decorator supervisorView] isKindOfClass: [ETScrollView class]])
			break;
	}
	
	return decorator;
}

- (ETWindowItem *) windowDecoratorItem
{
	id lastDecorator = [self lastDecoratorItem];
	id windowDecorator = nil;
	
	if ([lastDecorator isKindOfClass: [ETWindowItem class]])
		windowDecorator = lastDecorator;
		
	return windowDecorator;
}

- (void) updateLayout
{
	/* See -apply: */
}

/** Allows to compute the layout of the whole layout item tree without any 
	rendering/drawing. The layout begins with layout item leaves which can 
	simply returns their size, then moves up to layout item node which can 
	compute their layout and by side-effect their size. The process is 
	continued until the root layout item associated with a container is 
	reached.
	inputValues is usually nil. */
- (void) apply: (NSMutableDictionary *)inputValues
{
	[self updateLayout];
}

/** Propagates rendering/drawing in the layout item tree.
	This method doesn't involve any layout and size computation of the layout 
	items. If you need to do layout or size computation, implement the method
	-apply: in addition to this one.
    Override */
- (void) render: (NSMutableDictionary *)inputValues
{
	/* When we have a view, we wait to be asked to draw directly by our view 
	   before rendering anything. If a parent layout item asks us to draw, we
	   decline and wait the control return to the view who initiated the 
	   drawing and this view asks our view to draw itself as a subview. */
	//if ([self view] == nil) // || [[NSView focusView] isEqual: [[self displayView] superview]]
	{
		[_renderer renderLayoutItem: self];
	}
}

- (void) render: (NSMutableDictionary *)inputValues dirtyRect: (NSRect)dirtyRect inView: (NSView *)view 
{
	if (NSIntersectsRect(dirtyRect, [self frame]))
	{
		if ([[NSView focusView] isEqual: view] == NO)
			[view lockFocus];
			
		NSAffineTransform *transform = [NSAffineTransform transform];
		
		/* Modify coordinate matrix when the layout item doesn't use a view for 
		   drawing. */
		if ([self displayView] == nil)
		{
			[transform translateXBy: [self x] yBy: [self y]];
			[transform concat];
		}
		
		[[self renderer] renderLayoutItem: self];
		
		[transform invert];
		[transform concat];
			
		[view unlockFocus];
	}
}

- (void) render
{
	[self render: nil];
}

- (void) setNeedsDisplay: (BOOL)now
{
	NSRect displayRect = [self frame];
	
	/* If the layout item has a display view, this view will be asked to draw
	   by itself, so the rect to refresh must be expressed in display view
	   coordinates system and not the one of its superview. */
	if ([self displayView] != nil)
		displayRect.origin = NSZeroPoint;
		
	[[self closestAncestorDisplayView] setNeedsDisplayInRect: displayRect];
}

- (void) lockFocus
{
	// FIXME: Finds the first layout item ancestor with a view and asks it to
	// redraw itself at our rect location, this will flow back to us.
}

- (void) unlockFocus
{

}

// NOTE: Will probably become - (ETService *) renderer;
- (ETStyleRenderer *) renderer
{
	return _renderer;
}

- (void) setStyleRenderer: (ETStyleRenderer *)renderer
{
	ASSIGN(_renderer, renderer);
}


/** Returns a rect expressed in parent layout item coordinate space equivalent 
	to rect parameter expressed in the receiver coordinate space. */
- (NSRect) convertRectToParent: (NSRect)rect
{
	NSAffineTransform *transform = [NSAffineTransform transform];
	NSRect rectInParent = rect;
	
	[transform translateXBy: [self x] yBy: [self y]];
	rectInParent.origin = [transform transformPoint: rect.origin];
	
	return rectInParent;
}

/** Returns a rect expressed in the receiver coordinate space equivalent to
	rect parameter expressed in the parent layout item coordinate space. */
- (NSRect) convertRectFromParent: (NSRect)rect
{
	NSAffineTransform *transform = [NSAffineTransform transform];
	NSRect rectInChild = rect;
	
	[transform translateXBy: -([self x]) yBy: -([self y])];
	rectInChild.origin = [transform transformPoint: rect.origin];
	
	return rectInChild;
}

- (NSRect) persistentFrame
{
	// TODO: Find the best way to allow the represented object to provide and 
	// store the persistent frame.
	//[[[self representedObject] valueForProperty: @"kPersistentFrame"] rectValue];
	return [[VARIABLE_PROPERTIES objectForKey: @"kPersistentFrame"] rectValue];
}

- (void) setPersistentFrame: (NSRect) frame
{
	//[[self representedObject] setValue: [NSValue valueWithRect: frame] forProperty: @"kPersistentFrame"];
	[VARIABLE_PROPERTIES setObject: [NSValue valueWithRect: frame] forKey: @"kPersistentFrame"];
}

- (NSRect) frame
{
	if ([self displayView] != nil)
	{
		return [[self displayView] frame];
	}
	else
	{
		return _frame;
	}
}

- (void) setFrame: (NSRect)rect
{
	//ETLog(@"-setFrame: %@ on %@", NSStringFromRect(rect), self);
	if ([self displayView] != nil)
	{
		[[self displayView] setFrame: rect];
	}
	else
	{
		_frame = rect;
	}
	// NOTE: the next line introduces ETLayoutItemGroup import 
	if ([[[self parentLayoutItem] layout] isComputedLayout] == NO)
		[self setPersistentFrame: rect];
}

- (NSPoint) origin
{
	return [self frame].origin;
}

- (void) setOrigin: (NSPoint)origin
{
	NSRect newFrame = [self frame];
	
	newFrame.origin = origin;
	[self setFrame: newFrame];
}

- (NSSize) size
{
	return [self frame].size;
}

- (void) setSize: (NSSize)size
{
	NSRect newFrame = [self frame];
	
	newFrame.size = size;
	[self setFrame: newFrame];
}

- (float) x
{
	return [self frame].origin.x;
}

- (void) setX: (float)x
{
	[self setOrigin: NSMakePoint(x, [self y])];
}

- (float) y
{
	return [self frame].origin.y;
}

- (void) setY: (float)y
{
	[self setOrigin: NSMakePoint([self x], y)];
}

- (float) height
{
	return [self size].height;
}

- (void) setHeight: (float)height
{
	[self setSize: NSMakeSize([self width], height)];
}

- (float) width
{
	return [self size].width;
}

- (void) setWidth: (float)width
{
	[self setSize: NSMakeSize(width, [self height])];
}

- (NSRect) defaultFrame 
{ 
	return _defaultFrame; 
}

/** Modifies the item view frame when the item has a view. Default frame won't
	be touched by container transforms (like item scaling) unlike frame value
	returned by NSView. 
	Initiliazed with view frame passed in argument on ETLayoutItem instance
	initialization, else set to NSZeroRet. */
- (void) setDefaultFrame: (NSRect)frame
{ 
	_defaultFrame = frame;
	/* Update display view frame only if needed */
	if (NSEqualRects(_defaultFrame, [[self displayView] frame]) == NO)
		[self restoreDefaultFrame];
}

- (void) restoreDefaultFrame
{ 
	[self setFrame: [self defaultFrame]]; 
}

/** When the layout item uses a view, pass YES to this method to have the 
	content resize when the view itself is resized (by modifying frame).
	Resizing content in a view is possible by simply updating bounds size to 
	match the view frame. 
	Presently uses in ETPaneSwitcherLayout. */
- (void) setAppliesResizingToBounds: (BOOL)flag
{
	_resizeBounds = flag;
	
	if ([self displayView] == nil)
	{
		NSLog(@"WARNING: -setAppliesResizingToBounds: called with no view for %@", self);
		return;
	}
	
	if (_resizeBounds && [self displayView] != nil)
	{
		[[NSNotificationCenter defaultCenter] addObserver: self 
		                                         selector: @selector(layoutItemViewFrameDidChange:) 
												     name: NSViewFrameDidChangeNotification
												   object: [self displayView]];
		/* Fake notification to update bounds size */
		[self layoutItemViewFrameDidChange: nil];
	}
	else
	{
		[[NSNotificationCenter defaultCenter] removeObserver: self];
		/* Restore bounds size */
		[[self displayView] setBoundsSize: [[self displayView] frame].size];
		[[self displayView] setNeedsDisplay: YES];
	}
}

- (BOOL) appliesResizingToBounds
{
	return _resizeBounds;
}

- (void) layoutItemViewFrameDidChange: (NSNotification *)notif
{
	NSAssert1([self displayView] != nil, @"View of %@ cannot be nil on view notification", self);
	NSAssert1([self appliesResizingToBounds] == YES, @"Bounds resizing must be set on view notification in %@", self);
	
	ETLog(@"Receives NSViewFrameDidChangeNotification in %@", self);
	
	// FIXME: the proper way to handle such scaling is to use an 
	// NSAffineTransform and applies to item view in 
	// -resizeLayoutItems:scaleFactor: when -appliesResizingToBounds returns YES
	[[self displayView] setBoundsSize: [self defaultFrame].size];
	[[self displayView] setNeedsDisplay: YES];
}

/** Returns a default image representation of the layout item. 
	It tries to find it by looking up for 'image' property, then 'icon' 
	property. If none is found and a view is referenced by the layout item, it 
	generates an image by taking a snapshot of the view. */
- (NSImage *) image
{
	NSImage *img = [VARIABLE_PROPERTIES objectForKey: @"image"];
	
	if (img == nil && [[self value] isKindOfClass: [NSImage class]])
		img = [self value];
		
	return img;
}

- (void) setImage: (NSImage *)img
{
	[(NSMutableDictionary *)VARIABLE_PROPERTIES setObject: img forKey: @"image"];
}

/** Returns the image to be displayed when the receiver must be represented in a 
	symbolic style. This icon is commonly used by some layouts and also if the 
	receiver represents another layout item (when -isMetaLayoutItem returns YES).
	By default this method, returns either -image if the returned value isn't 
	nil or a view snapshot when -view isn't nil. 
	-image and -icon can be considered as symetric equivalents of -name and 
	-displayName methods. */
- (NSImage *) icon
{
	NSImage *icon = [VARIABLE_PROPERTIES objectForKey: @"icon"];
	
	if (icon == nil)
		icon = [self image];

	// NOTE: -bitmapImageRepForCachingDisplayInRect:(NSRect)aRect on Mac OS 10.4
	if (icon == nil && [self displayView] != nil)
		icon = [[self displayView] snapshot];
		
	if (icon != nil && [self representedObject] != nil)
		icon = [[self representedObject] icon];
		
	if (icon == nil)
		ETLog(@"Icon missing for %@", self);
		
	return icon;
}

- (void) setIcon: (NSImage *)img
{
	[VARIABLE_PROPERTIES setObject: img forKey: @"icon"];
}

/* Events & Actions */

/** Returns the event handler associated with the receiver. The returned object
	must implement ETEventHandler protocol.
	By default the receiver returns itself. See ETLayoutItem+Events to know 
	more about event handling in the layout item tree. */
- (id <ETEventHandler>) eventHandler
{
	return self;
}

/* You can override this method for your own custom layout item */
- (void) doubleClick
{

}

- (void) showInspectorPanel
{
	[[[self inspector] panel] makeKeyAndOrderFront: self];
}

- (id <ETInspector>) inspector
{
	ETContainer *container = [self closestAncestorContainer];
	id <ETInspector> inspector = nil;
	
	if (container != nil)
		inspector = [container inspector];
		
	if (inspector != nil)
		[inspector setInspectedItems: [NSArray arrayWithObject: self]];
		
	return inspector;
}

/* Live Development */

- (void) beginEditingUI
{
	id view = [self view];
	
	/* Notify to view */
	if (view != nil && [view respondsToSelector: @selector(beginEditingUI)])
		[view beginEditingUI];

	/* Notify decorator item chain */
	[[self decoratorItem] beginEditingUI];
}

@end


@implementation NSObject (ETLayoutItem)

- (BOOL) isLayoutItem
{
	return ([self isKindOfClass: [ETLayoutItem class]]);
}

@end
