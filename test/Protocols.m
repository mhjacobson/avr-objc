#include "Test.h"
#include <objc.h>

@protocol Proto
@end

@interface ProtocolsFoo : Object <Proto>
@end

@implementation ProtocolsFoo
@end

@interface ProtocolsBar : Object
@end

@implementation ProtocolsBar
@end

@interface ProtocolsBar (Proto) <Proto>
@end

@implementation ProtocolsBar (Proto)
@end

@protocol Proto2 <Proto>
@end

@interface ProtocolsBaz : Object <Proto2>
@end

@implementation ProtocolsBaz
@end

@interface TestProtocols <Test>
@end

@implementation TestProtocols

+ (void)run {
        TEST_ASSERT(class_conformsToProtocol([ProtocolsFoo self], @protocol(Proto)));
        // TEST_ASSERT(class_conformsToProtocol([ProtocolsBar self], @protocol(Proto)));
        TEST_ASSERT(protocol_conformsToProtocol(@protocol(Proto2), @protocol(Proto)));

        printf("Tests passed.\n");
        for (;;) ;
}

@end
