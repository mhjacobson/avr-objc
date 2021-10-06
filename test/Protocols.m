#import "Test.h"
#import <objc.h>

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
        TEST_ASSERT(!protocol_conformsToProtocol(@protocol(Proto), @protocol(Proto2)));

        const Protocol *const proto = objc_getProtocol("Proto");
        TEST_ASSERT(proto != nil);
        TEST_ASSERT(proto == @protocol(Proto));

        const Protocol *const proto2 = objc_getProtocol("Proto2");
        TEST_ASSERT(proto2 != nil);
        TEST_ASSERT(proto2 == @protocol(Proto2));

        TEST_ASSERT([ProtocolsFoo conformsToProtocol:@protocol(Proto)]);
        // TEST_ASSERT([ProtocolsBar conformsToProtocol:@protocol(Proto)]);
        TEST_ASSERT([proto2 conformantClassesConformToProtocol:@protocol(Proto)]);
        TEST_ASSERT(![proto conformantClassesConformToProtocol:@protocol(Proto2)]);
}

@end
