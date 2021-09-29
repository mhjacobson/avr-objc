#import "Test.h"
#import <objc.h>

@interface MessagingFoo : Object

- (int)transformValue:(int)value;

@end

@implementation MessagingFoo

- (int)transformValue:(int)value {
    return value;
}

+ (int)transformValue:(int)value {
    return value + 10;
}

@end

@interface MessagingBar : MessagingFoo {
    int _intIvar;
}

@end

@implementation MessagingBar

- (int)transformValue:(int)value {
    return [super transformValue:value] + 100;
}

+ (int)transformValue:(int)value {
    return [super transformValue:value] + 100;
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

    TEST_ASSERT([foo transformValue:1] == 1);

    printf("BarClass=%p, bar=%p, *bar=%p\n", BarClass, bar, *(Class *)bar);
    [bar transformValue:2];
    // TEST_ASSERT([bar transformValue:2] == 102);

    // TEST_ASSERT([MessagingFoo transformValue:3] == 103);
    // TEST_ASSERT([MessagingBar transformValue:4] == 114);
}

@end