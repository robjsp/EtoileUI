/*
	Copyright (C) 2009 Quentin Mathe

	Author:  Quentin Mathe <qmathe@club-internet.fr>
	Date:  August 2009
	License: Modified BSD (see COPYING)
 */

#import "EtoileUIProperties.h"

NSString * const kETAcceptsActionsProperty = @"acceptsActions";
NSString * const kETActionHandlerProperty = @"actionHandler";
NSString * const kETActionProperty = @"action";
NSString * const kETAnchorPointProperty = @"anchorPoint";
NSString * const kETAutoresizingMaskProperty = @"autoresizingMask";
NSString * const kETSourceItemProperty = @"sourceItem";
NSString * const kETBoundingBoxProperty = @"boundingBox";
NSString * const kETContentAspectProperty = @"contentAspect";
NSString * const kETContentBoundsProperty = @"contentBounds";
NSString * const kETControllerProperty = @"controller";
NSString * const kETControllerItemProperty = @"controllerItem";
NSString * const kETCoverStyleProperty = @"coverStyle";
NSString * const kETDecoratedItemProperty = @"decoratedItem";
NSString * const kETDecoratorItemProperty = @"decoratorItem";
NSString * const kETDefaultFrameProperty = @"defaultFrame";
NSString * const kETDelegateProperty = @"delegate";
NSString * const kETDisplayNameProperty = @"displayName"; 
NSString * const kETDoubleClickedItemProperty = @"doubleClickedItem";
NSString * const kETExposedProperty = @"exposed";
NSString * const kETFlippedProperty = @"flipped";
NSString * const kETFrameProperty = @"frame";
NSString * const kETHeightProperty = @"height";
NSString * const kETHiddenProperty = @"hidden";
NSString * const kETIconProperty = @"icon";
NSString * const kETIdentifierProperty = @"identifier";
NSString * const kETImageProperty = @"image";
NSString * const kETIsMetaItemProperty = @"isMetaItem";
NSString * const kETItemScaleFactorProperty = @"itemScaleFactor";
NSString * const kETLayoutProperty = @"layout";
NSString * const kETNameProperty = @"name";
NSString * const kETNeedsDisplayProperty = @"needsDisplay";
NSString * const kETNextResponderProperty = @"nextResponder";
NSString * const kETParentItemProperty = @"parentItem";
NSString * const kETPersistentFrameProperty = @"persistentFrame";
NSString * const kETPositionProperty = @"position";
NSString * const kETRepresentedObjectProperty = @"representedObject";
NSString * const kETRootItemProperty = @"rootItem";
NSString * const kETSelectedProperty = @"selected";
NSString * const kETSelectableProperty = @"selectable";
NSString * const kETSourceProperty = @"source";
NSString * const kETStyleGroupProperty = @"styleGroup";
NSString * const kETStyleProperty = @"style";
NSString * const kETSubjectProperty = @"subject";
NSString * const kETSubtypeProperty = @"subtype";
NSString * const kETTargetProperty = @"target";
NSString * const kETTransformProperty = @"transform";
NSString * const kETUTIProperty = @"UTI";
NSString * const kETValueProperty = @"value";
NSString * const kETValueKeyProperty = @"valueKey";
NSString * const kETViewProperty = @"view";
NSString * const kETVisibleProperty = @"visible";
NSString * const kETWidthProperty = @"width";
NSString * const kETXProperty = @"x";
NSString * const kETYProperty = @"y";


/* Pickboard Item Metadata */

NSString * const kETPickMetadataWasUsedAsRepresentedObject = @"wasUsedAsRepresentedObject";
NSString * const kETPickMetadataPickIndex = @"pickIndex";
NSString * const kETPickMetadataDraggedItems = @"draggedItems";
NSString * const kETPickMetadataCurrentDraggedItem = @"currentDraggedItem";
NSString * const  kETPickMetadataWereItemsRemoved = @"wereRemoved";

NSString * const kETPickMetadataProperty = @"pickMetadata";


/* Commit Descriptor Identifiers */

NSString * const kETCommitItemInsert = @"org.etoile-project.EtoileUI.item-insert";
NSString * const kETCommitRectangleInsert = @"org.etoile-project.EtoileUI.rectangle-insert";
NSString * const kETCommitItemRemove = @"org.etoile-project.EtoileUI.item-remove";
NSString * const kETCommitItemDuplicate = @"org.etoile-project.EtoileUI.item-duplicate";

NSString * const kETCommitItemMove = @"org.etoile-project.EtoileUI.item-move";
NSString * const kETCommitItemResize = @"org.etoile-project.EtoileUI.item-resize";
NSString * const kETCommitItemReorder = @"org.etoile-project.EtoileUI.item-reorder";
NSString * const kETCommitItemRegroup = @"org.etoile-project.EtoileUI.item-regroup";
NSString * const kETCommitItemUngroup = @"org.etoile-project.EtoileUI.item-ungroup";
NSString * const kETCommitItemSendToBack = @"org.etoile-project.EtoileUI.item-send-to-back";
NSString * const kETCommitItemBringToFront = @"org.etoile-project.EtoileUI.item-bring-to-front";
NSString * const kETCommitItemSendBackward = @"org.etoile-project.EtoileUI.item-send-backward";
NSString * const kETCommitItemBringForward = @"org.etoile-project.EtoileUI.item-bring-forward";

NSString * const kETCommitObjectDrop = @"org.etoile-project.EtoileUI.object-drop";

NSString * const kETCommitEditProperty = @"org.etoile-project.EtoileUI.edit-property";
