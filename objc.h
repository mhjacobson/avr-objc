/*
 * objc.h
 * author: Matt Jacobson
 * created: June 2021
 */

#include <stdint.h>

#ifndef OBJC_H
#define OBJC_H

typedef struct objc_object *id;
typedef struct objc_selector *SEL;
typedef struct objc_class *Class;
@class Protocol;
typedef id (*IMP)(id, SEL, ...);
typedef _Bool BOOL;
#define YES 1
#define NO 0
#define nil ((id)0)
#define Nil ((Class)0)

id class_createInstance(Class cls);
Class objc_getClass(const char *name);
Class *objc_copyClassList(void);

Class object_getClass(id object);
void object_setClass(id object, Class cls);

const char *class_getName(Class cls);
BOOL class_conformsToProtocol(Class cls, const Protocol *protocol);

const Protocol *objc_getProtocol(const char *const name);
BOOL protocol_conformsToProtocol(const Protocol *conformer, const Protocol *conformee);

#if __OBJC__

@protocol Object

- (id)self;
- (Class)class;
- (BOOL)conformsToProtocol:(const Protocol *)protocol;

@end

#if __clang__
__attribute__((objc_root_class))
#endif /* __clang__ */
@interface Object <Object> {
    Class _isa;
}

- (id)self;
- (Class)class;
- (BOOL)conformsToProtocol:(const Protocol *)protocol;

@end

@interface Protocol : Object {
@public
    const char *_name;
    struct protocol_list *_protocols;
    struct method_list *_instanceMethods;
    struct method_list *_classMethods;
    struct method_list *_optionalInstanceMethods;
    struct method_list *_optionalClassMethods;
    struct property_list *_instanceProperties;
}

- (const char *)name;
- (BOOL)conformantClassesConformToProtocol:(const Protocol *)conformee;

@end

@interface Object (Description)

+ (const char *)description;
- (const char *)copyDescription;

@end

#endif /* __OBJC__ */

#endif /* OBJC_H */
