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
typedef id (*IMP)(id, SEL, ...);
typedef _Bool BOOL;
#define YES 1
#define NO 0
#define nil ((id)0)
#define Nil ((Class)0)

id class_createInstance(Class cls);
Class objc_getClass(const char *name);

#if __OBJC__
#if __clang__
__attribute__((objc_root_class))
#endif /* __clang__ */
@interface Object {
@private
    Class _isa;
}

+ (Class)self;

@end

@interface Protocol : Object

@end

@interface Object (Description)

+ (const char *)description;
- (const char *)copyDescription;

@end
#endif /* __OBJC__ */

#endif /* OBJC_H */
