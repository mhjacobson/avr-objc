#import "Test.h"
#import "IvarFoo.h"
#import <objc.h>

@interface IvarBar : IvarFoo {
@public
    char z;
}

@end

@implementation IvarBar
@end

static IvarBar *bar;

@interface TestIvar <Test>
@end

@implementation TestIvar

+ (void)run {
    TEST_ASSERT(&bar->z - (char *)bar == 2);
}

@end