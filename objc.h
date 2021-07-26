#include <stdint.h>

#ifndef OBJC_H
#define OBJC_H

typedef struct objc_object *id;
typedef struct objc_selector *SEL;
typedef struct objc_class *Class;
typedef id (*IMP)(id, SEL, ...);
typedef _Bool BOOL;
#define nil ((id)0)
#define Nil ((Class)0)

struct objc_symtab {
     long sel_ref_cnt;
     SEL *refs;
     short cls_def_cnt;
     short cat_def_cnt;
     void *defs[0];
};
void objc_init_symtab(const struct objc_symtab *symtab);

// XXX: this would be better if it were emitted by the compiler automatically
__attribute__((constructor))
static void objc_init_module(void) {
    extern const struct objc_symtab symtab __asm__("_OBJC_Symbols");
    objc_init_symtab(&symtab);
}

id class_createInstance(Class cls);
Class objc_getClass(const char *name);

#if __OBJC__
@interface Object {
@public
    Class _isa;
}

+ (Class)self;

@end

@interface Protocol : Object

@end
#endif /* __OBJC__ */

#endif /* OBJC_H */