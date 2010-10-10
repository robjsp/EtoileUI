/*
	Copyright (C) 2007 Quentin Mathe
 
	Author:  Quentin Mathe <qmathe@club-internet.fr>
	Date:  January 2007
	License:  Modified BSD  (see COPYING)
 */

#import <EtoileFoundation/Macros.h>
#import <EtoileFoundation/ETCollection+HOM.h>
#import <EtoileFoundation/ETUTI.h>
#import <EtoileFoundation/NSObject+Model.h>
#import "ETDocumentController.h"
#import "ETLayoutItem.h"
#import "ETLayoutItemGroup.h"
#import "NSObject+EtoileUI.h"
#import "ETCompatibility.h"


@implementation ETDocumentController

- (void) dealloc
{
	DESTROY(_error);
	[super dealloc];
}

/** Returns the items that match the given UTI in the receiver content.

Each item subtype must conform to the given type to be matched.

See -[ETLayoutItem subtype] and -[ETUTI conformsToType:]. */
- (NSArray *) itemsForType: (ETUTI *)aUTI
{
 	NSMutableArray *items = AUTORELEASE([[self content] mutableCopy]); 
	[[(ETLayoutItem *)[items filter] subtype] conformsToType: aUTI];
	return items;
}

/** Returns the items that match the given URL in the receiver content.

Either the item or its represented object must have a URL property to be 
matched.

The returned array usually contains a single item, unless the application allows 
to open multiple instances of the same document (e.g. a web browser). */
- (NSArray *) itemsForURL: (NSURL *)aURL
{
	NSMutableArray *items = AUTORELEASE([[self content] mutableCopy]); 
	[[[items filter] valueForProperty: @"URL"] isEqual: aURL];
	return items;
}

// TODO: Implement
- (NSArray *) documentItems
{
	return nil;
}

// TODO: Implement
- (id) activeItem
{
	return nil;
}

/** Returns the type of the object to be instantiated on -add:, -insert: and 
-newDocument:.

By default, returns the UTI of the object class.<br />
See -objectClass and -setObjectClass:.

Can be overriden to return a custom type based on a use case or a user setting. */
- (ETUTI *) defaultType
{
	return [ETUTI typeWithClass: [self objectClass]];
}

/** By default, returns the class that corresponds to the given UTI. 

If the UTI doesn't describe an ObjC class, returns Nil.  */
- (Class) objectClassForType: (ETUTI *)aUTI
{
	return [aUTI classValue];
}

- (Class) validatedClass: (Class)objectClass forType: (ETUTI *)aUTI
{
	if (Nil == objectClass)
	{
		[NSException raise: NSInvalidArgumentException 
		            format: @"-objectClassForType: returns no valid object class for the type %@", aUTI];
	}
	return objectClass;
}

/**

All arguments can be nil. */
- (id) newInstanceWithURL: (NSURL *)aURL ofType: (ETUTI *)aUTI options: (NSDictionary *)options
{
	Class objectClass = [self validatedClass: [self objectClassForType: aUTI] forType: aUTI];
	id newInstance = [objectClass alloc];

	if ([newInstance conformsToProtocol: @protocol(ETDocumentCreation)])
	{ 
		[newInstance initWithURL: aURL options: options];
	}
	else
	{
		[newInstance init];
	}

	if ([newInstance isCollection])
	{
		newInstance = [self newItemGroupWithRepresentedObject: AUTORELEASE(newInstance)];
	}
	else
	{
		newInstance = [self newItemWithRepresentedObject: AUTORELEASE(newInstance)];
	}
	ETAssert(nil != newInstance);

	return newInstance;
}

/** 

Raises a NSInvalidArgumentException if the given URL is nil, and a 
NSInternalInconsistencyException the object class for the given type doesn't 
conform to [ETDocumentCreation] protocol. */
- (id) openInstanceWithURL: (NSURL *)aURL options: (NSDictionary *)options
{
	NILARG_EXCEPTION_TEST(aURL); 

	if (NO == [self allowsMultipleInstancesForURL: aURL]
	 && NO == [[self itemsForURL: aURL] isEmpty])
	{
			ETAssert(1 == [[self itemsForURL: aURL] count]);
			return [[self itemsForURL: aURL] firstObject];
	}

	ETUTI *uti = [self typeForURL: aURL];
	ETAssert(nil != uti);
	Class objectClass = [self validatedClass: [self objectClassForType: uti] forType: uti];
	id newInstance = nil;

	if ([objectClass conformsToProtocol: @protocol(ETDocumentCreation)])
	{ 
		newInstance = [[objectClass alloc] initWithURL: aURL options: options];
	}
	else
	{
		[NSException raise: NSInternalInconsistencyException
		            format: @"For type %@, -objectClassForType: returned %@ that "
		                    "does not conform to ETDocumentCreation protocol",
		                    uti, objectClass];
	}

	if ([newInstance isCollection])
	{
		newInstance = [self newItemGroupWithRepresentedObject: AUTORELEASE(newInstance)];
	}
	else
	{
		newInstance = [self newItemWithRepresentedObject: AUTORELEASE(newInstance)];
	}
	ETAssert(nil != newInstance);

	return newInstance;
}

/** <override-dummy />
Returns whether the same document can appear multiple times on screen for 
the given URL. 

By default, returns NO.

Can be overriden in a subclass to implement a web browser for example. */
- (BOOL) allowsMultipleInstancesForURL: (NSURL *)aURL
{
	return NO;
}

/** <override-dummy />
Returns the content types the application can read or write.

By default, returns an array that contains only a default type.

Can be overriden to return multiple types if the application can view or edit 
more than a single content type. */
- (NSArray *) supportedTypes
{
	return A([self defaultType]);
}

/** Returns the UTI that describes the content at the given URL.

Will call -[ETUTI typeWithPath:] to determine the type, can be overriden to 
implement a tailored behavior. */
- (ETUTI *) typeForURL: (NSURL *)aURL
{
	// TODO: If UTI is nil, set error.
	return [ETUTI typeWithPath: [aURL path]];
}

/** Returns the last error that was reported to the receiver. */
- (NSError *) error
{
	return _error;
}

- (NSArray *) URLsFromRunningOpenPanel
{
	NSOpenPanel *op = [NSOpenPanel openPanel];

	[op setAllowsMultipleSelection: YES];
	[op setAllowedFileTypes: [self supportedTypes]];

	return ([op runModal] == NSFileHandlingPanelOKButton ? [op URLs] : [NSArray array]);
}

/* Actions */

/** Creates a new object of the default type and adds it to the receiver content.

Will call -newInstanceWithURL:ofType:options: to create the new document. */
- (IBAction) newDocument: (id)sender
{
	[self newInstanceWithURL: nil ofType: [self defaultType] options: [NSDictionary dictionary]];
}

/** Creates one or more objects with the URLs the user has choosen in an open 
panel and adds them to the receiver content.

Will call -openInstanceWithURL:options: to open the document(s).

See also [ETDocumentCreation] protocol. */
- (IBAction) openDocument: (id)sender
{
	NSURL *url = [[self URLsFromRunningOpenPanel] firstObject];
	NSDictionary *options = nil;
	ETLayoutItem *openedItem = [[self itemsForURL: url] firstObject];

	if (nil != openedItem)
	{
		[self setSelectionIndex: [[self content] indexOfItem: openedItem]];
		return;
	}

	[self openInstanceWithURL: url options: options];
}

@end
