#import "Test.h"
#import <objc.h>

typedef struct {
    double x, y, z;
} Point;

static BOOL equalPoints(Point a, Point b) {
    return a.x == b.x && a.y == b.y && a.z == b.z;
}

@interface MessagingFoo : Object

- (int)transformInt:(int)value;
- (Point)transformPoint:(Point)value;

@end

@interface MessagingBar : MessagingFoo

@end

@implementation MessagingFoo

- (int)transformInt:(int)value {
    return value;
}

+ (int)transformInt:(int)value {
    return value + 10;
}

- (Point)transformPoint:(Point)value {
    value.x++;
    return value;
}

+ (Point)transformPoint:(Point)value {
    value.y++;
    return value;
}

@end

@implementation MessagingBar

- (int)transformInt:(int)value {
    return [super transformInt:value] + 100;
}

+ (int)transformInt:(int)value {
    return [super transformInt:value] + 100;
}

- (Point)transformPoint:(Point)value {
    value = [super transformPoint:value];
    value.z++;
    return value;
}

+ (Point)transformPoint:(Point)value {
    value = [super transformPoint:value];
    value.z++;
    return value;
}

@end

@interface TestMessaging <Test>
@end

@implementation TestMessaging

+ (void)run {
    const Class FooClass = objc_getClass("MessagingFoo");
    TEST_ASSERT(FooClass != Nil);
    const Class BarClass = objc_getClass("MessagingBar");
    TEST_ASSERT(BarClass != Nil);

    MessagingFoo *const foo = class_createInstance(FooClass);
    TEST_ASSERT(foo != nil);
    MessagingBar *const bar = class_createInstance(BarClass);
    TEST_ASSERT(bar != nil);

    TEST_ASSERT([foo transformInt:1] == 1);
    TEST_ASSERT([bar transformInt:2] == 102);

    TEST_ASSERT([MessagingFoo transformInt:3] == 13);
    TEST_ASSERT([MessagingBar transformInt:4] == 114);

    TEST_ASSERT(equalPoints([foo transformPoint:(Point){1., 1., 1.}], (Point){2., 1., 1.}));
    TEST_ASSERT(equalPoints([bar transformPoint:(Point){2., 2., 2.}], (Point){3., 2., 3.}));

    TEST_ASSERT(equalPoints([MessagingFoo transformPoint:(Point){3., 3., 3.}], (Point){3., 4., 3.}));
    TEST_ASSERT(equalPoints([MessagingBar transformPoint:(Point){4., 4., 4.}], (Point){4., 5., 5.}));
}

@end