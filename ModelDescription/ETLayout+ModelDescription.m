/*
	Copyright (C) 2011 Quentin Mathe

	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  June 2011
	License: Modified BSD (see COPYING)
 */

#import <EtoileFoundation/EtoileFoundation.h>
#import "ETLayout.h"
#import "ETComputedLayout.h"
#import "ETFixedLayout.h"
#import "ETPositionalLayout.h"
#import "ETWidgetLayout.h"
#import "ETTableLayout.h"
#import "ETTemplateItemLayout.h"
#import "ETFormLayout.h"
#import "ETIconLayout.h"
#import "ETTokenLayout.h"
#import "ETOutlineLayout.h"
// FIXME: Move related code to the Appkit widget backend (perhaps in a category)
#import "ETWidgetBackend.h"

// NOTE: ETFixedLayout, ETFreeLayout uses ETLayout model description
@interface ETLayout (ModelDescription)
@end

@interface ETPositionalLayout (ModelDescription)
@end

@interface ETFixedLayout (ModelDescription)
@end

@interface ETComputedLayout (ModelDescription)
@end

@interface ETTemplateItemLayout (ModelDescription)
@end

@interface ETFormLayout (ModelDescription)
@end

@interface ETIconLayout (ModelDescription)
@end

@interface ETTokenLayout (ModelDescription)
@end


@implementation ETLayout (ModelDescription)

+ (ETEntityDescription *) newEntityDescription
{
	ETEntityDescription *entity = [self newBasicEntityDescription];

	// For subclasses that don't override -newEntityDescription, we must not add 
	// the property descriptions that we will inherit through the parent
	if ([[entity name] isEqual: [ETLayout className]] == NO) 
		return entity;

    ETPropertyDescription *contextItem =
        [ETPropertyDescription descriptionWithName: @"contextItem" type: (id)@"ETLayoutItemGroup"];
    [contextItem setDerived: YES];
    [contextItem setOpposite: (id)@"ETLayoutItemGroup.layout"];
	ETPropertyDescription *attachedTool =
		[ETPropertyDescription descriptionWithName: @"attachedTool" type: (id)@"ETTool"];
	[attachedTool setOpposite: (id)@"ETTool.layoutOwner"];
	ETPropertyDescription *layerItem = 
		[ETPropertyDescription descriptionWithName: @"layerItem" type: (id)@"ETLayoutItemGroup"];
	ETPropertyDescription *dropIndicator = 
		[ETPropertyDescription descriptionWithName: @"dropIndicator" type: (id)@"ETDropIndicator"];

	// NOTE: layoutSize is not transient, it is usually computed but can be customized
	ETPropertyDescription *layoutSize = 
		[ETPropertyDescription descriptionWithName: @"layoutSize" type: (id)@"NSSize"];
    ETPropertyDescription *oldProposedLayoutSize =
    	[ETPropertyDescription descriptionWithName: @"oldProposedLayoutSize" type: (id)@"NSSize"];
	// NOTE: We don't persist _previousScaleFactor, it's an optimization.
	// See -[ETPositionalLayout resizeItems:toScaleFactor:].

	// TODO: Declare the numerous derived (implicitly transient) properties we have 

	NSArray *transientProperties = @[contextItem, layerItem, layoutSize];
	NSArray *persistentProperties = @[attachedTool, oldProposedLayoutSize,
		dropIndicator];

	[entity setUIBuilderPropertyNames: (id)[[@[dropIndicator] mappedCollection] name]];

	[[persistentProperties mappedCollection] setPersistent: YES];
	[entity setPropertyDescriptions: 
		[persistentProperties arrayByAddingObjectsFromArray: transientProperties]];

	return entity;
}

@end


@implementation ETPositionalLayout (ModelDescription)

+ (ETEntityDescription *) newEntityDescription
{
	ETEntityDescription *entity = [self newBasicEntityDescription];
	
	// For subclasses that don't override -newEntityDescription, we must not add
	// the property descriptions that we will inherit through the parent
	if ([[entity name] isEqual: [ETPositionalLayout className]] == NO)
        return entity;
    

    ETPropertyDescription *contextLayout =
		[ETPropertyDescription descriptionWithName: @"contextLayout" type: (id)@"ETTemplateItemLayout"];
	[contextLayout setDerived: YES];
	[contextLayout setOpposite: (id)@"ETTemplateItemLayout.positionalLayout"];
	ETPropertyDescription *isContentSizeLayout =
		[ETPropertyDescription descriptionWithName: @"isContentSizeLayout" type: (id)@"BOOL"];
	ETPropertyDescription *constrainedItemSize =
		[ETPropertyDescription descriptionWithName: @"constrainedItemSize" type: (id)@"NSSize"];
	ETPropertyDescription *itemSizeConstraintStyle = 
		[ETPropertyDescription descriptionWithName: @"itemSizeConstraintStyle" type: (id)@"NSUInteger"];
	[itemSizeConstraintStyle setRole: [ETMultiOptionsRole new]];
	[[itemSizeConstraintStyle role] setAllowedOptions:
	 	[@{ _(@"None"): @(ETSizeConstraintStyleNone),
		    _(@"Vertical"): @(ETSizeConstraintStyleVertical),
		    _(@"Horizontal"): @(ETSizeConstraintStyleHorizontal),
		    _(@"Vertical and Horizontal"): @(ETSizeConstraintStyleVerticalHorizontal) } arrayRepresentation]];

	NSArray *transientProperties = @[contextLayout];
	NSArray *persistentProperties = @[isContentSizeLayout,
		constrainedItemSize, itemSizeConstraintStyle];

	[entity setUIBuilderPropertyNames: (id)[[@[isContentSizeLayout, constrainedItemSize,
		itemSizeConstraintStyle] mappedCollection] name]];

	[[persistentProperties mappedCollection] setPersistent: YES];
	[entity setPropertyDescriptions: 
		[persistentProperties arrayByAddingObjectsFromArray: transientProperties]];
	
	return entity;
}

@end


@implementation ETFixedLayout (ModelDescription)

+ (ETEntityDescription *) newEntityDescription
{
    ETEntityDescription *entity = [self newBasicEntityDescription];
    
    // For subclasses that don't override -newEntityDescription, we must not add
    // the property descriptions that we will inherit through the parent
    if ([[entity name] isEqual: [ETFixedLayout className]] == NO)
        return entity;
    
    ETPropertyDescription *autoresizesItems =
        [ETPropertyDescription descriptionWithName: @"autoresizesItems" type: (id)@"BOOL"];
	[autoresizesItems setPersistent: YES];

    [entity setPropertyDescriptions: @[autoresizesItems]];
    
    return entity;
}

@end


@implementation ETComputedLayout (ModelDescription)

+ (ETEntityDescription *) newEntityDescription
{
	ETEntityDescription *entity = [self newBasicEntityDescription];
	
	// For subclasses that don't override -newEntityDescription, we must not add
	// the property descriptions that we will inherit through the parent
	if ([[entity name] isEqual: [ETComputedLayout className]] == NO)
		return entity;

	ETPropertyDescription *borderMargin =
		[ETPropertyDescription descriptionWithName: @"borderMargin" type: (id)@"CGFloat"];
	ETPropertyDescription *itemMargin =
		[ETPropertyDescription descriptionWithName: @"itemMargin" type: (id)@"CGFloat"];
	ETPropertyDescription *autoresizesItemToFill =
		[ETPropertyDescription descriptionWithName: @"autoresizesItemToFill" type: (id)@"BOOL"];
	ETPropertyDescription *horizontalAlignment =
		[ETPropertyDescription descriptionWithName: @"horizontalAlignment" type: (id)@"NSUInteger"];
	ETPropertyDescription *horizontalAligmentGuide =
		[ETPropertyDescription descriptionWithName: @"horizontalAlignmentGuidePosition" type: (id)@"CGFloat"];
	ETPropertyDescription *computesItemRectFromBoundingBox =
		[ETPropertyDescription descriptionWithName: @"computesItemRectFromBoundingBox" type: (id)@"BOOL"];
	ETPropertyDescription *usesAlignmentHint =
		[ETPropertyDescription descriptionWithName: @"usesAlignmentHint" type: (id)@"BOOL"];
	ETPropertyDescription *separatorTemplateItem =
		[ETPropertyDescription descriptionWithName: @"separatorTemplateItem" type: (id)@"ETLayoutItem"];
	ETPropertyDescription *separatorItemEndMargin =
		[ETPropertyDescription descriptionWithName: @"separatorItemEndMargin" type: (id)@"CGFloat"];
	
	NSArray *transientProperties = @[];
	NSArray *persistentProperties = @[borderMargin, itemMargin, autoresizesItemToFill,
		horizontalAlignment, horizontalAligmentGuide, computesItemRectFromBoundingBox,
		usesAlignmentHint, separatorTemplateItem, separatorItemEndMargin];
	
	[entity setUIBuilderPropertyNames: (id)[[@[borderMargin, itemMargin,
		autoresizesItemToFill, horizontalAlignment, horizontalAligmentGuide,
		separatorTemplateItem, separatorItemEndMargin] mappedCollection] name]];

	[[persistentProperties mappedCollection] setPersistent: YES];
	[entity setPropertyDescriptions:
	 	[persistentProperties arrayByAddingObjectsFromArray: transientProperties]];
	
	return entity;
}

@end


@implementation ETWidgetLayout (ModelDescription)

+ (ETEntityDescription *) newEntityDescription
{
	ETEntityDescription *entity = [self newBasicEntityDescription];
	
	// For subclasses that don't override -newEntityDescription, we must not add
	// the property descriptions that we will inherit through the parent
	if ([[entity name] isEqual: [ETWidgetLayout className]] == NO)
		return entity;
	
	ETPropertyDescription *nibName =
		[ETPropertyDescription descriptionWithName: @"nibName" type: (id)@"NSString"];
	[nibName setReadOnly: YES];
	ETPropertyDescription *layoutView =
		[ETPropertyDescription descriptionWithName: @"layoutView" type: (id)@"NSView"];
	[layoutView setPersistentTypeName: @"NSData"];
	ETPropertyDescription *selectionIndexPaths =
		[ETPropertyDescription descriptionWithName: @"selectionIndexPaths" type: (id)@"NSIndexPath"];
	[selectionIndexPaths setMultivalued: YES];
	[selectionIndexPaths setOrdered: YES];
	ETPropertyDescription *doubleClickedItem =
		[ETPropertyDescription descriptionWithName: @"doubleClickedItem" type: (id)@"ETLayoutItem"];
	[doubleClickedItem setReadOnly: YES];
	// TODO: Perhaps add a Class entity description to the metamodel (not sure)
	ETPropertyDescription *widgetViewClass =
		[ETPropertyDescription descriptionWithName: @"widgetViewClass" type: (id)@"NSObject"];
	[widgetViewClass setReadOnly: YES];

	NSArray *transientProperties = @[nibName, selectionIndexPaths,
		doubleClickedItem, widgetViewClass];
	NSArray *persistentProperties = @[layoutView];
	
	[[persistentProperties mappedCollection] setPersistent: YES];
	[entity setPropertyDescriptions:
		[persistentProperties arrayByAddingObjectsFromArray: transientProperties]];
	
	return entity;
}

@end


@implementation ETTableLayout (ModelDescription)

+ (ETEntityDescription *) newEntityDescription
{
	ETEntityDescription *entity = [self newBasicEntityDescription];
	
	// For subclasses that don't override -newEntityDescription, we must not add
	// the property descriptions that we will inherit through the parent
	if ([[entity name] isEqual: [ETTableLayout className]] == NO)
		return entity;

	ETPropertyDescription *propertyColumns =
		[ETPropertyDescription descriptionWithName: @"propertyColumns" type: (id)@"NSTableColumn"];
	[propertyColumns setMultivalued: YES];
	[propertyColumns setKeyed: YES];
	[propertyColumns setReadOnly: YES];
	ETPropertyDescription *displayedProperties =
		[ETPropertyDescription descriptionWithName: @"displayedProperties" type: (id)@"NSString"];
	[displayedProperties setMultivalued: YES];
	[displayedProperties setOrdered: YES];
	[displayedProperties setDerived: YES];
	ETPropertyDescription *editableProperties =
		[ETPropertyDescription descriptionWithName: @"editableProperties" type: (id)@"BOOL"];
	[editableProperties setMultivalued: YES];
	ETPropertyDescription *styles =
		[ETPropertyDescription descriptionWithName: @"styles" type: (id)@"ETStyle"];
	[styles setMultivalued: YES];
	// FIXME: Use ETColumnFragment as type
	ETPropertyDescription *columns =
		[ETPropertyDescription descriptionWithName: @"columns" type: (id)@"NSObject"];
	[columns setMultivalued: YES];
	ETPropertyDescription *formatters =
		[ETPropertyDescription descriptionWithName: @"formatters" type: (id)@"NSFormatter"];
	[formatters setMultivalued: YES];
	[formatters setKeyed: YES];
	/* The collection is immutable because you cannot declare new properties by 
	   editing it. You must edit 'displayedProperties' to do so instead. 
	   However the formatter objects themselves are mutable, but editing doesn't 
	   involve mutating the collection. */
	[formatters setReadOnly: YES];
	// TODO: Set a value transformer for 'value' so we can resolve the
	// formatter against the aspect repositories and NSFormatter subclasses.
	ETPropertyDescription *sortable =
		[ETPropertyDescription descriptionWithName: @"sortable" type: (id)@"BOOL"];
	ETPropertyDescription *contentFont =
		[ETPropertyDescription descriptionWithName: @"contentFont" type: (id)@"NSFont"];
	[contentFont setValueTransformerName: @"COObjectToArchivedData"];
	[contentFont setPersistentTypeName: @"NSData"];

	// FIXME: NSArray *transientProperties = @[displayedProperties, editableProperties,
	//	formatters, styles];
	NSArray *transientProperties = @[displayedProperties, formatters];
	NSArray *persistentProperties = @[propertyColumns, sortable, contentFont];
	
	[entity setUIBuilderPropertyNames: (id)[[transientProperties mappedCollection] name]];

	[[persistentProperties mappedCollection] setPersistent: YES];
	[entity setPropertyDescriptions:
		[persistentProperties arrayByAddingObjectsFromArray: transientProperties]];
	
	return entity;
}

/* This method is exposed to ensure the property visibility as declared in 
the metamodel. We need to persist _propertyColumns, so we declare a related 
property description, but the persisted value is returned by -serializedPropertyColumns, 
so -propertyColumns is never used unless the user inspects the object. */
- (NSDictionary *) propertyColumns
{
	return _propertyColumns;
}

- (NSDictionary *) formatters
{
	NSMutableDictionary *formatters = [NSMutableDictionary dictionary];

	for (NSString *property in _propertyColumns)
	{
		NSTableColumn *column = _propertyColumns[property];
		ETMutableObjectViewpoint *formatterViewpoint =
			[ETMutableObjectViewpoint viewpointWithName: @"formatter"
			                          representedObject: [column dataCell]];
	
		formatters[property] = formatterViewpoint;
	}
	return [formatters copy];
}

@end


@implementation ETTemplateItemLayout (ModelDescription)


+ (ETEntityDescription *) newEntityDescription
{
	ETEntityDescription *entity = [self newBasicEntityDescription];
	
	// For subclasses that don't override -newEntityDescription, we must not add
	// the property descriptions that we will inherit through the parent
	if ([[entity name] isEqual: [ETTemplateItemLayout className]] == NO)
		return entity;

	ETPropertyDescription *positionalLayout =
		[ETPropertyDescription descriptionWithName: @"positionalLayout" type: (id)@"ETPositionalLayout"];
	[positionalLayout setOpposite: (id)@"ETPositionalLayout.contextLayout"];
	ETPropertyDescription *templateItem =
		[ETPropertyDescription descriptionWithName: @"templateItem" type: (id)@"ETLayoutItem"];
	ETPropertyDescription *templateKeys =
		[ETPropertyDescription descriptionWithName: @"templateKeys" type: (id)@"NSString"];
	[templateKeys setMultivalued: YES];
	[templateKeys setOrdered: YES];
	ETPropertyDescription *localBindings =
		[ETPropertyDescription descriptionWithName: @"localBindings" type: (id)@"NSString"];
	[localBindings setMultivalued: YES];
	[localBindings setOrdered: NO];
	[localBindings setKeyed: YES];
	ETPropertyDescription *renderedItems =
		[ETPropertyDescription descriptionWithName: @"renderedItems" type: (id)@"ETLayoutItem"];
	[renderedItems setMultivalued: YES];
	[renderedItems setOrdered: NO];

	NSArray *persistentProperties = @[positionalLayout, templateItem,
		templateKeys, localBindings];
	NSArray *transientProperties = @[renderedItems];
	
	[entity setUIBuilderPropertyNames: (id)[[persistentProperties mappedCollection] name]];
	
	[[persistentProperties mappedCollection] setPersistent: YES];
	[entity setPropertyDescriptions:
	 	[persistentProperties arrayByAddingObjectsFromArray: transientProperties]];
	
	return entity;
}

@end


@implementation ETFormLayout (ModelDescription)

+ (ETEntityDescription *) newEntityDescription
{
	ETEntityDescription *entity = [self newBasicEntityDescription];
	
	// For subclasses that don't override -newEntityDescription, we must not add
	// the property descriptions that we will inherit through the parent
	if ([[entity name] isEqual: [ETFormLayout className]] == NO)
		return entity;

	ETPropertyDescription *alignment =
		[ETPropertyDescription descriptionWithName: @"alignment" type: (id)@"NSUInteger"];
	ETPropertyDescription *itemLabelFont =
		[ETPropertyDescription descriptionWithName: @"itemLabelFont" type: (id)@"NSFont"];
	[itemLabelFont setDerived: YES];
	
	NSArray *persistentProperties = @[alignment];
	NSArray *transientProperties = @[itemLabelFont];
	
	[entity setUIBuilderPropertyNames: (id)[[persistentProperties mappedCollection] name]];
	
	[[persistentProperties mappedCollection] setPersistent: YES];
	[entity setPropertyDescriptions:
	 	[persistentProperties arrayByAddingObjectsFromArray: transientProperties]];
	
	return entity;
}

@end


@implementation ETIconLayout (ModelDescription)

+ (ETEntityDescription *) newEntityDescription
{
	ETEntityDescription *entity = [self newBasicEntityDescription];
	
	// For subclasses that don't override -newEntityDescription, we must not add
	// the property descriptions that we will inherit through the parent
	if ([[entity name] isEqual: [ETIconLayout className]] == NO)
		return entity;

	ETPropertyDescription *itemLabelFont =
		[ETPropertyDescription descriptionWithName: @"itemLabelFont" type: (id)@"NSFont"];
	[itemLabelFont setValueTransformerName: @"COObjectToArchivedData"];
	[itemLabelFont setPersistentTypeName: @"NSData"];
	ETPropertyDescription *iconSizeForScaleFactorUnit =
		[ETPropertyDescription descriptionWithName: @"iconSizeForScaleFactorUnit" type: (id)@"NSSize"];
	ETPropertyDescription *minIconSize =
		[ETPropertyDescription descriptionWithName: @"minIconSize" type: (id)@"NSSize"];

	NSArray *persistentProperties = @[itemLabelFont, iconSizeForScaleFactorUnit, minIconSize];
	
	[entity setUIBuilderPropertyNames: (id)[[persistentProperties mappedCollection] name]];
	
	[[persistentProperties mappedCollection] setPersistent: YES];
	[entity setPropertyDescriptions: persistentProperties];
	
	return entity;
}

@end


@implementation ETTokenLayout (ModelDescription)

+ (ETEntityDescription *) newEntityDescription
{
	ETEntityDescription *entity = [self newBasicEntityDescription];
	
	// For subclasses that don't override -newEntityDescription, we must not add
	// the property descriptions that we will inherit through the parent
	if ([[entity name] isEqual: [ETTokenLayout className]] == NO)
		return entity;

	ETPropertyDescription *editedProperty =
		[ETPropertyDescription descriptionWithName: @"editedProperty" type: (id)@"NSString"];
	ETPropertyDescription *itemLabelFont =
		[ETPropertyDescription descriptionWithName: @"itemLabelFont" type: (id)@"NSFont"];
	[itemLabelFont setValueTransformerName: @"COObjectToArchivedData"];
	[itemLabelFont setPersistentTypeName: @"NSData"];
	ETPropertyDescription *maxTokenWidth =
		[ETPropertyDescription descriptionWithName: @"maxTokenWidth" type: (id)@"CGFloat"];

	NSArray *persistentProperties = @[editedProperty, itemLabelFont, maxTokenWidth];
	
	[entity setUIBuilderPropertyNames: (id)[[persistentProperties mappedCollection] name]];
	
	[[persistentProperties mappedCollection] setPersistent: YES];
	[entity setPropertyDescriptions: persistentProperties];
	
	return entity;
}

@end
