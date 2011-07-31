/**
	<abstract>A collection of related aspects or styles.</abstract>

	Copyright (C) 20010 Quentin Mathe

	Author:  Quentin Mathe <quentin.mathe@gmail.com>
	Date:  May 2010
	License: Modified BSD (see COPYING)
 */

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

/** @group Aspect Repository

An aspect category regroups various aspects together based on some criteria.

The built-in criteria to restrict the allowed aspects in a category is the type. 
See -setAllowedAspectTypes:.<br />
Subclasses might implement other criterias.

Aspects can be aliased under multiple names in the category, see 
-setAspect:forKey: and -resolvedAspectForKey:.<br />
For -setAspect:forKey:, insert an aspect name as value rather than a aspect 
object, as shown below.<br />
Aliased aspect names must be prefixed with <em>@</em>.

<example>
[category setAspect: [NSColor cyanColor] forKey: @"cyan"];
[category setAspect: @"@cyan" forKey: @"lightblue"];
NSColor *cyanColor = [category resolvedAspectForKey: @"lightblue"];
</example>

In the example above, the last line returns [NSColor cyanColor] and 
<em>lightblue</em> is the alias (or semantic aspect).<br /> */
@interface ETAspectCategory : NSObject
{
	@protected
	NSMutableArray *_aspects; /* An array of ETKeyValuePair */
	@private
	NSSet *allowedAspectTypes;
	NSString *name;
}

/** @taskunit Initialization */

- (id) initWithDictionary: (NSDictionary *)dict;
- (id) init;

/** @taskunit Basic Properties */

/** The category name.

Must not be nil. */
@property (retain, nonatomic) NSString *name;

/** @taskunit Accessing and Managing Aspects */

- (id) aspectForKey: (NSString *)aKey;
- (void) setAspect: (id)anAspect forKey: (NSString *)aKey;
- (void) removeAspectForKey: (NSString *)aKey;
- (NSArray *) aspectKeys;
- (NSArray *) aspects;

/** @taskunit Restricting Valid Aspects */

/** The aspect UTI types allowed in the category.

Aspect objects which don't conform to these types won't be accepted by 
-setAspect:forKey:.

See also ETUTI. */
@property (copy, nonatomic) NSSet *allowedAspectTypes;

/** @taskunit Resolving Semantic Aspect */

- (id) resolvedAspectForKey: (NSString *)aKey;

@end