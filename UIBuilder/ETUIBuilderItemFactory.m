/*
	Copyright (C) 2013 Quentin Mathe
 
	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  April 2013
	License:  Modified BSD (see COPYING)
 */

#import <EtoileFoundation/NSObject+Etoile.h>
#import <EtoileFoundation/NSObject+HOM.h>
#import <EtoileFoundation/NSObject+Model.h>
#import <EtoileFoundation/NSString+Etoile.h>
#import <EtoileFoundation/Macros.h>
#import <IconKit/IconKit.h>
#import "ETUIBuilderItemFactory.h"
#import "ETAspectCategory.h"
#import "ETAspectRepository.h"
#import "EtoileUIProperties.h"
#import "ETColumnLayout.h"
#import "ETController.h"
#import "ETFormLayout.h"
#import "ETLayoutItem.h"
#import "ETLayoutItem+Scrollable.h"
#import "ETLayoutItemGroup.h"
#import "ETLineLayout.h"
#import "ETUIBuilderController.h"
#import "ETModelDescriptionRenderer.h"
#import "ETObjectValueFormatter.h"
#import "ETOutlineLayout.h"
#import "NSObject+EtoileUI.h"
#import "NSView+Etoile.h"
#import "ETCompatibility.h"


@implementation ETUIBuilderItemFactory

- (id) init
{
	SUPERINIT;
	ASSIGN(renderer, [ETModelDescriptionRenderer renderer]);
	//[renderer setGroupingKeyPath: @"owner"];
	return self;
}

- (void) dealloc
{
	DESTROY(renderer);
	[super dealloc];
}

- (ETLayoutItem *) buttonWithIconNamed: (NSString *)aName target: (id)aTarget action: (SEL)anAction
{
	NSImage *icon = [[IKIcon iconWithIdentifier: aName] image];
	return [self buttonWithImage: icon target: aTarget action: anAction];
}

- (ETLayout *) defaultMasterViewLayout
{
	ETOutlineLayout *layout = [ETOutlineLayout layout];

	[layout setContentFont: [NSFont controlContentFontOfSize: [NSFont smallSystemFontSize]]];

	// TODO: Figure out a nice way to restore the layout as is because
	// displayed properties are lost on layout changes (happens only if the
	// user wants to customize the inspector UI).
	[layout setDisplayedProperties: A(kETIconProperty, @"UIBuilderName",
		kETIdentifierProperty, @"UIBuilderAction", @"UIBuilderTarget",
		@"UIBuilderModel", @"UIBuilderController")];

	/* Actions are stored as strings in ETLayoutItem variable storage. So we
	   don't need to use a custom property unlike for expressing targets as
	   strings. To do so, we introduce a targetIdentifier property and
	   -[ETLayoutItem target] checks whether this property is set just before
	   returning the target. */
	[layout setDisplayName: @"Name" forProperty: @"UIBuilderName"];
	[layout setDisplayName: @"Identifier" forProperty: kETIdentifierProperty];
	[layout setDisplayName: @"Action" forProperty: @"UIBuilderAction"];
	[layout setDisplayName: @"Target" forProperty: @"UIBuilderTarget"];
	[layout setDisplayName: @"Model" forProperty: @"UIBuilderModel"];
	[layout setDisplayName: @"Controller" forProperty: @"UIBuilderController"];
	
	[[layout columnForProperty: @"UIBuilderName"] setWidth: 140];
	[[layout columnForProperty: kETIdentifierProperty] setWidth: 120];
	[[layout columnForProperty: @"UIBuilderTarget"] setWidth: 100];
	[[layout columnForProperty: @"UIBuilderAction"] setWidth: 100];
	[[layout columnForProperty: @"UIBuilderModel"] setWidth: 100];
	[[layout columnForProperty: @"UIBuilderController"] setWidth: 120];

	[layout setEditable: YES forProperty: @"UIBuilderName"];
	[layout setEditable: YES forProperty: kETIdentifierProperty];
	[layout setEditable: YES forProperty: @"UIBuilderAction"];
	[layout setEditable: YES forProperty: @"UIBuilderTarget"];
	[layout setEditable: YES forProperty: @"UIBuilderModel"];
	[layout setEditable: YES forProperty: @"UIBuilderController"];

	return layout;
}

- (NSSize) defaultInspectorSize
{
	return NSMakeSize(700, 1000);
}

- (NSSize) defaultInspectorBodySize
{
	NSSize size = [self defaultInspectorSize];
	size.height -= [self defaultIconAndLabelBarHeight];
	return size;
}

- (NSSize) defaultBrowserSize
{
	NSSize size = [self defaultInspectorBodySize];
	size.height -= [self defaultBasicInspectorSize].height;
	return size;
}

- (NSSize) defaultBasicInspectorSize
{
	NSSize size = [self defaultInspectorBodySize];
	size.height = 800;
	return size;
}

- (ETLayoutItemGroup *) inspectorWithObject: (id)anObject
                                 controller: (id)aController
{
	ETLayoutItemGroup *topBar = [self inspectorTopBarWithController: aController];
	ETLayoutItemGroup *body = [self inspectorBodyWithObject: anObject controller: aController];
	ETLayoutItemGroup *inspector = [self itemGroupWithSize: [self defaultInspectorSize]];

	[inspector addItems: A(topBar, body)];
	[inspector setIdentifier: @"inspector"];
	[inspector setAutoresizingMask: ETAutoresizingFlexibleWidth | ETAutoresizingFlexibleHeight];
	[inspector setLayout: [ETColumnLayout layout]];
	[inspector setController: aController];

	ETLog(@"\n%@\n", [inspector descriptionWithOptions: [NSMutableDictionary dictionaryWithObjectsAndKeys: 
		A(@"frame", @"autoresizingMask"), kETDescriptionOptionValuesForKeyPaths,
		@"items", kETDescriptionOptionTraversalKey, nil]]);

	return inspector;
}

- (ETLayoutItem *) viewPopUpWithController: (id)aController
{
	NSArray *choices = A(_(@"Browser"), _(@"Inspector"), _(@"Browser and Inspector"));
	ETLayoutItem *popUpItem = [self popUpMenuWithItemTitles: choices
		                                 representedObjects: [NSArray array]
		                                             target: aController 
		                                             action: @selector(changePresentationViewFromPopUp:)];

	[aController setViewPopUpItem: popUpItem];
	[popUpItem sizeToFit];
	[[popUpItem view] selectItemAtIndex: 2];

	return popUpItem;
}

- (NSArray *) allAspectRepositories
{
	NSArray *repos = [[[ETAspectRepository mainRepository]
		aspectCategoryNamed: _(@"Aspect Repository")] aspects];

	return [A([ETAspectRepository mainRepository]) arrayByAddingObjectsFromArray: repos];
}

- (ETLayoutItem *) aspectRepositoryPopUpWithController: (id)aController
{
	NSArray *aspectRepos = [self allAspectRepositories];
	NSArray *choices = (id)[[aspectRepos mappedCollection] name];
	ETLayoutItem *popUpItem = [self popUpMenuWithItemTitles: choices
		                                 representedObjects: aspectRepos
		                                             target: aController 
		                                             action: @selector(changeAspectRepositoryFromPopUp:)];

	[aController setAspectPopUpItem: popUpItem];
	[popUpItem sizeToFit];
	[[popUpItem view] selectItemAtIndex: 0];

	return popUpItem;
}

- (ETLayoutItemGroup *) inspectorTopBarWithController: (id)aController
{
	NSSize size = NSMakeSize([self defaultBrowserSize].width, [self defaultIconAndLabelBarHeight]);
	ETLayoutItemGroup *itemGroup = [self itemGroupWithSize: size];
	ETLayoutItem *inspectItem = [self buttonWithIconNamed: @"list-add"
	                                               target: aController
	                                               action: @selector(inspectSelection:)];
	ETLayoutItem *searchItem = [self searchFieldWithTarget: aController
	                                                action: @selector(filter:)];
	ETLayoutItem *viewItem = [self viewPopUpWithController: aController];
	ETLayoutItem *repoItem = [self aspectRepositoryPopUpWithController: aController];
	ETLayoutItemGroup *rightItemGroup = [self itemGroup];

	[(NSSearchFieldCell *)[[searchItem view] cell] setSendsSearchStringImmediately: YES];

	[itemGroup setIdentifier: @"inspectorTopBar"];
	[itemGroup setAutoresizingMask: ETAutoresizingFlexibleWidth];
	[itemGroup setLayout: [ETLineLayout layout]];
	[[itemGroup layout] setSeparatorTemplateItem: [self flexibleSpaceSeparator]];

	[rightItemGroup setLayout: [ETLineLayout layout]];
	[[rightItemGroup layout] setIsContentSizeLayout: YES];

	[rightItemGroup addItems:
	 	A([self barElementFromItem: viewItem withLabel: _(@"View")],
		  [self barElementFromItem: repoItem withLabel: _(@"Aspect Repository")],
		  [self barElementFromItem: searchItem withLabel: _(@"Filter")])];

	[itemGroup addItems:
		A([self barElementFromItem: inspectItem withLabel: _(@"Inspect")],
		  rightItemGroup)];

	/*[rightItemGroup updateLayoutRecursively: NO];
	[itemGroup updateLayoutRecursively: NO];*/

	return itemGroup;
}

- (ETLayoutItemGroup *) inspectorBodyWithObject: (id)anObject
                                     controller: (id)aController
{
	ETLayoutItemGroup *body = [self itemGroupWithSize: [self defaultInspectorBodySize]];
	ETLayoutItemGroup *browser = [self browserWithObject: anObject
	                                          controller: aController];
	ETLayoutItemGroup *basicInspector = [self basicInspectorWithObject: anObject
	                                                              size: [self defaultBasicInspectorSize]
	                                                        controller: aController];

	[body setIdentifier: @"inspectorBody"];
	[body setAutoresizingMask: ETAutoresizingFlexibleWidth | ETAutoresizingFlexibleHeight];
	[body setLayout: [ETColumnLayout layout]];
	[body addItems: A(browser, basicInspector)];

	return body;
}

- (ETLayoutItemGroup *) browserWithObject: (id)anObject
                               controller: (id)aController
{
	ETLayoutItemGroup *itemGroup = [self itemGroupWithSize: [self defaultBrowserSize]];

	[itemGroup setRepresentedObject: anObject];
	[itemGroup setIdentifier: @"browser"];
	[itemGroup setAutoresizingMask: ETAutoresizingFlexibleWidth];
	[itemGroup setLayout: [self defaultMasterViewLayout]];
	[itemGroup setHasVerticalScroller: YES];
	[itemGroup setSource: itemGroup];
	[itemGroup setDelegate: aController];
	[itemGroup setDoubleAction: @selector(doubleClickInItemGroupView:)];
	[itemGroup setTarget: aController];
	[itemGroup setSelectionIndex: 0];

	[aController setBrowserItem: itemGroup];

	return itemGroup;
}

- (ETLayoutItemGroup *) basicInspectorWithObject: (id)anObject
                                            size: (NSSize)aSize
                                      controller: (id)aController
{
	ETLayoutItemGroup *itemGroup = [self itemGroupWithSize: aSize];
	ETLayoutItemGroup *header = [self basicInspectorHeaderWithObject: anObject controller: aController];
	ETLayoutItemGroup *pane = [self basicInspectorContentWithObject: anObject controller: aController aspectName: @"layout"];

	[itemGroup setIdentifier: @"basicInspector"];
	[itemGroup setAutoresizingMask: ETAutoresizingFlexibleWidth | ETAutoresizingFlexibleHeight];
	[itemGroup setLayout: [ETColumnLayout layout]];
	[itemGroup addItems: A(header, pane)];

	[aController setAspectInspectorItem: itemGroup];
	[aController setItemFactory: self];

	return itemGroup;
}

- (ETLayoutItem *) aspectPopUpWithController: (id)aController
{
	NSArray *choices = A(_(@"Overview"), _(@"Layout"), _(@"Represented Object"),
		_(@"Controller"), _(@"Cover Style"), _(@"Style Group"),
		_(@"Action Handler"), _(@"Tool"));
	NSArray *representedProperties = A(@"self", @"layout", @"representedObject",
		@"controller", @"coverStyle", @"styleGroup", @"actionHandler", @"layout.attachedTool");
	ETLayoutItem *popUpItem = [self popUpMenuWithItemTitles: choices
		                                 representedObjects: representedProperties
		                                             target: aController 
		                                             action: @selector(changeAspectPaneFromPopUp:)];

	[popUpItem setName: _(@"Aspect")];
	[aController setAspectPopUpItem: popUpItem];
	[[popUpItem view] selectItemAtIndex: 1];
	return popUpItem;
}

- (ETLayoutItem *) typeField
{
	ETLayoutItem *typeField = [self textField];
	[typeField setName: _(@"Type")];
	return typeField;
}

- (ETLayoutItemGroup *) basicInspectorHeaderWithObject: (id)anObject controller: (id)aController
{
	NSSize size = NSMakeSize([self defaultBasicInspectorSize].width, 80);
	ETLayoutItemGroup *itemGroup = [self itemGroupWithSize: size];
	ETFormLayout *formLayout = [ETFormLayout layout];
	ETLayoutItem *aspectPopUpItem = [self aspectPopUpWithController: aController];
	ETLayoutItem *typeFieldItem = [self typeField];
	
	// TODO: Perhaps use aspectInspector
	[itemGroup setIdentifier: @"basicInspectorHeader"];
	[itemGroup setAutoresizingMask: ETAutoresizingFlexibleWidth];
	// TODO: Remove -setSize: and just uses -setIsContentSizeLayout:
	//[formLayout setIsContentSizeLayout: YES];
	[itemGroup setLayout: formLayout];
	[itemGroup addItems: A(aspectPopUpItem, typeFieldItem)];

	return itemGroup;
}

- (NSArray *) presentedPropertyNamesForAspectName: (NSString *)anAspectName ofObject: (id)anObject
{
	// NOTE: We use -valueForKey: to support using @"self" as a key
	if ([anObject valueForKeyPath: anAspectName] == nil)
	{
		return [NSArray array];
	}
	return [[[anObject valueForKeyPath: anAspectName] entityDescription] allUIBuilderPropertyNames];
}

- (ETLayoutItemGroup *) basicInspectorContentWithObject: (id)anObject
                                             controller: (id)aController
                                             aspectName: (NSString *)anAspectName
{
	NSParameterAssert(anObject != nil);
	NSParameterAssert(aController != nil);
	NSParameterAssert(anAspectName != nil);

	ETEntityDescription *rootEntity = [[renderer repository] descriptionForName: @"Object"];

	[(ETObjectValueFormatter *)[renderer formatterForType: rootEntity] setDelegate: aController];

	[renderer setRenderedPropertyNames: [self presentedPropertyNamesForAspectName: anAspectName
	                                                                     ofObject: anObject]];

	ETLayoutItemGroup *itemGroup = [renderer renderObject: [anObject valueForKeyPath: anAspectName]];
	NSSize size = [self defaultBasicInspectorSize];
	
	size.height -= 80;

	// TODO: Perhaps use aspectInspector
	[itemGroup setIdentifier: @"basicInspectorContent"];
	[itemGroup setAutoresizingMask: ETAutoresizingFlexibleWidth | ETAutoresizingFlexibleHeight];
	[itemGroup setSize: size];

	return itemGroup;
}
	 
- (ETLayoutItemGroup *) inspectorPaneWithObject: (id)anObject forAspectName: (NSString *)anAspectName
{
	return nil;
}

@end


@implementation NSObject (UIBuilder)

- (IBAction) inspectUI: (id)sender
{
	ETLayoutItemGroup *inspector = [[ETUIBuilderItemFactory factory]
		inspectorWithObject: self controller: AUTORELEASE([ETUIBuilderController new])];

	[[[ETUIBuilderItemFactory factory] windowGroup] addItem: inspector];
}

@end

