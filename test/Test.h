#include <objc.h>
#include <stdio.h>

#define TEST_ASSERT(x) do { if (!(x)) { printf("Assertion failed (" __FILE__ "): " #x "\n"); for (;;) ; } } while (0)

@protocol Test

+ (void)run;

@end