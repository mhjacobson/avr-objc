#import "Test.h"
#import <stdlib.h>
#import <string.h>
#import <objc.h>

@interface PropertyFoo : Object

@property (nonatomic) int x;
@property (nonatomic) char y;
@property (strong) Object *object;

@end

@implementation PropertyFoo

@synthesize x=_x;
@dynamic y;
@synthesize object=_object;

@end

@protocol PropertyProto

@property (nonatomic) int z;

@end

@protocol PropertyProto2 <PropertyProto>

@end

@interface PropertyBar : PropertyFoo <PropertyProto2>
@end

@implementation PropertyBar

@dynamic z;

@end

@interface PropertyBar (Category)

@property (nonatomic) int w;

@end

@implementation PropertyBar (Category)

@dynamic w;

@end

@interface TestProperty <Test>
@end

@implementation TestProperty

+ (void)run {
    const Class PropertyFooClass = [PropertyFoo self];
    const Property x = class_getProperty(PropertyFooClass, "x");
    const Property y = class_getProperty(PropertyFooClass, "y");

    TEST_ASSERT(x != NULL);
    TEST_ASSERT(y != NULL);
    TEST_ASSERT(!strcmp(property_getName(x), "x"));
    TEST_ASSERT(!strcmp(property_getName(y), "y"));

    char *const xDynamicValue = property_copyAttributeValue(x, PROPERTY_DYNAMIC);
    char *const yDynamicValue = property_copyAttributeValue(y, PROPERTY_DYNAMIC);
    TEST_ASSERT(xDynamicValue == NULL);
    TEST_ASSERT(!strcmp(yDynamicValue, ""));
    free(xDynamicValue);
    free(yDynamicValue);

    char *const xTypeValue = property_copyAttributeValue(x, PROPERTY_TYPE);
    char *const yTypeValue = property_copyAttributeValue(y, PROPERTY_TYPE);
    TEST_ASSERT(!strcmp(xTypeValue, @encode(int)));
    TEST_ASSERT(!strcmp(yTypeValue, @encode(char)));
    free(xTypeValue);
    free(yTypeValue);

    char *const xIvarValue = property_copyAttributeValue(x, PROPERTY_IVAR);
    char *const yIvarValue = property_copyAttributeValue(y, PROPERTY_IVAR);
    TEST_ASSERT(!strcmp(xIvarValue, "_x"));
    TEST_ASSERT(yIvarValue == NULL);
    free(xIvarValue);
    free(yIvarValue);

    const Class PropertyBarClass = [PropertyBar self];
    const Property barX = class_getProperty(PropertyBarClass, "x");
    const Property barY = class_getProperty(PropertyBarClass, "y");
    TEST_ASSERT(x == barX);
    TEST_ASSERT(y == barY);

    const Property z = protocol_getProperty(@protocol(PropertyProto2), "z");
    TEST_ASSERT(z != NULL);
    TEST_ASSERT(!strcmp(property_getName(z), "z"));

    const Property w = class_getProperty(PropertyBarClass, "w");
    TEST_ASSERT(w != NULL);
    TEST_ASSERT(!strcmp(property_getName(w), "w"));
}

@end
