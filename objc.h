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
typedef const struct property *Property;
typedef id (*IMP)(id, SEL, ...);
typedef _Bool BOOL;
#define YES 1
#define NO 0
#define nil ((id)0)
#define Nil ((Class)0)

id class_createInstance(Class cls);
void object_destroy(id object);

id objc_retain(id object);
void objc_release(id object);

Class objc_getClass(const char *name);
Class *objc_copyClassList(void);

Class object_getClass(id object);
void object_setClass(id object, Class cls);

const char *class_getName(Class cls);
BOOL class_conformsToProtocol(Class cls, const Protocol *protocol);

const Protocol *objc_getProtocol(const char *const name);
BOOL protocol_conformsToProtocol(const Protocol *conformer, const Protocol *conformee);

Property class_getProperty(Class cls, const char *name);
Property protocol_getProperty(const Protocol *protocol, const char *name);

const char *property_getName(Property property);
const char *property_getAttributes(Property property);

#define PROPERTY_READONLY "R"
#define PROPERTY_COPY "C"
#define PROPERTY_STRONG "&"
#define PROPERTY_WEAK "W"
#define PROPERTY_DYNAMIC "D"
#define PROPERTY_GETTER "G"
#define PROPERTY_SETTER "S"
#define PROPERTY_IVAR "V"
#define PROPERTY_TYPE "T"
#define PROPERTY_NONATOMIC "N"

char *property_copyAttributeValue(Property property, const char *attributeName);

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
