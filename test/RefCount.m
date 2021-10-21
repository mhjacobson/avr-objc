#import "Test.h"
#import <objc.h>

@interface RefCountFoo : Object

@property (nonatomic) BOOL *didDeallocPointer;

@end

@implementation RefCountFoo

@synthesize didDeallocPointer=_didDeallocPointer;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-missing-super-calls"

- (void)dealloc {
    if (_didDeallocPointer) {
        *_didDeallocPointer = YES;
    }

    object_destroy(self);
}

#pragma clang diagnostic pop

@end

@interface TestRefCount <Test>
@end

@implementation TestRefCount

+ (void)run {
    BOOL didDealloc;

    didDealloc = NO;
    RefCountFoo *const foo1 = class_createInstance([RefCountFoo self]);
    [foo1 setDidDeallocPointer:&didDealloc];
    objc_release(foo1);
    TEST_ASSERT(didDealloc);

    didDealloc = NO;
    RefCountFoo *const foo2 = class_createInstance([RefCountFoo self]);
    [foo2 setDidDeallocPointer:&didDealloc];
    objc_retain(foo2);
    objc_release(foo2);
    TEST_ASSERT(!didDealloc);
    objc_release(foo2);
    TEST_ASSERT(didDealloc);

    didDealloc = NO;
    RefCountFoo *const foo3 = class_createInstance([RefCountFoo self]);
    [foo3 setDidDeallocPointer:&didDealloc];

    for (int i = 0; i < UINT8_MAX; i++) {
        objc_retain(foo3);
    }

    // Object should be immortal now, so these releases should do nothing.
    for (int i = 0; i < UINT8_MAX; i++) {
        objc_release(foo3);
    }

    TEST_ASSERT(!didDealloc);

    didDealloc = NO;
    RefCountFoo *const foo4 = class_createInstance([RefCountFoo self]);
    [foo4 setDidDeallocPointer:&didDealloc];

    @autoreleasepool {
        objc_autorelease(foo4);
    }

    TEST_ASSERT(didDealloc);
}

@end
