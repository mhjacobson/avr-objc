#import "Test.h"
#import <objc.h>
#import <string.h>

@interface CategoryFoo : Object

@end

@implementation CategoryFoo

static BOOL calledLoad;
+ (void)load {
    calledLoad = YES;
}

static BOOL calledInitialize;
+ (void)initialize {
    calledInitialize = YES;
}

- (const char *)title {
    return "Title";
}

@end

@interface CategoryFoo (StompTitle)

- (const char *)title;
- (const char *)subtitle;

@end

@implementation CategoryFoo (StompTitle)

static BOOL calledCategoryLoad;
+ (void)load {
    calledCategoryLoad = YES;
}

static BOOL calledCategoryInitialize;
+ (void)initialize {
    calledCategoryInitialize = YES;
}

- (const char *)title {
    return "StompedTitle";
}

- (const char *)subtitle {
    return "Subtitle";
}

@end

@interface TestCategory <Test>
@end

@implementation TestCategory

+ (void)run {
    TEST_ASSERT(calledLoad);
    TEST_ASSERT(calledCategoryLoad);
    TEST_ASSERT(!calledInitialize);
    TEST_ASSERT(!calledCategoryInitialize);

    TEST_ASSERT([CategoryFoo self] == objc_getClass("CategoryFoo"));
    TEST_ASSERT(!calledInitialize); // +initialize should have been stomped
    TEST_ASSERT(calledCategoryInitialize);

    CategoryFoo *const foo = class_createInstance([CategoryFoo self]);
    TEST_ASSERT(!strcmp([foo title], "StompedTitle"));
    TEST_ASSERT(!strcmp([foo subtitle], "Subtitle"));
}

@end