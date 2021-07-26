#include "objc.h"
#include <stdint.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <stddef.h>

struct objc_class {
    struct objc_class *isa;
    struct objc_class *superclass;

    // NOTE: the Apple runtime replaces these with a single inline cache_t, which is two pointers in size.
    void *cache;
    void *vtable;

    // NOTE: the Apple runtime replaces this with a class_data_bits_t, which is the rw data pointer plus some flags in the unused bits.
    struct class_ro *rodata;
};

struct class_ro {
    // NOTE: GCC/clang emit these as `unsigned int`.
    uint16_t flags;
    uint16_t instance_start;
    uint16_t instance_size;
    uint16_t reserved;
    uint8_t *ivarLayout;
    char *name;
    struct method_list *methods;
    void *protocols;
    struct ivar_list *ivars;
    uint8_t *weakIvarLayout;
    struct property_list *properties;
};

struct method {
    SEL name;
    char *types;
    IMP imp;
};

struct method_list {
    // NOTE: GCC/clang emit these as `unsigned int`.
    uint16_t element_size;
    uint16_t element_count;
    struct method methods[];
};

struct ivar {
    uint16_t *offset;
    char *name;
    char *type;
    uint32_t alignment_raw;
    uint32_t size;
};

struct ivar_list {
    // NOTE: GCC/clang emit these as `unsigned int`.
    uint16_t element_size;
    uint16_t element_count;
    struct ivar ivars[];
};

IMP class_lookupMethod(const struct objc_class *const cls, const SEL _cmd) {
    const struct class_ro *const rodata = cls->rodata;
    const struct method_list *const method_list = rodata->methods;
    const char *const name = rodata->name;

    IMP imp = 0;

    if (method_list) {
        for (int i = 0; i < method_list->element_count; i++) {
            const struct method *const method = &method_list->methods[i];

            if (strcmp((char *)method->name, (char *)_cmd) == 0) {
                imp = method->imp;
            }
        }
    }

    if (imp == 0 && cls->superclass) {
        imp = class_lookupMethod(cls->superclass, _cmd);
    }

    if (imp == 0) {
        printf("objc: undeliverable message %s\n", (char *)_cmd);
        for (;;) ;
    }

    return imp;
}

const struct objc_class *class_getSuperclass(const struct objc_class *cls) {
    return cls->superclass;
}

// TODO: I need to fix up instance_size before this is usable.
id class_createInstance(Class cls) {
    const struct class_ro *const rodata = cls->rodata;
    const size_t size = rodata->instance_size;
    
    const id object = calloc(size, 1);
    *(struct objc_class **)object = cls;
    return object;
}

// Comment from objc4:
#if 0
// This entry point was designed wrong.  When used as a getter, src needs to be locked so that
// if simultaneously used for a setter then there would be contention on src.
// So we need two locks - one of which will be contended.
#endif /* 0 */
// For now, we don't care about atomic properties and just copy the bits over.
void objc_copyStruct(void *dest, const void *src, ptrdiff_t size, BOOL atomic, BOOL hasStrong) {
    memmove(dest, src, size);
}

#define MAX_SYMTABS 16
static const struct objc_symtab *symtabs[MAX_SYMTABS];
static unsigned short nsymtab;

void objc_init_symtab(const struct objc_symtab *const symtab) {
    if (nsymtab < MAX_SYMTABS) {
        symtabs[nsymtab] = symtab;
        nsymtab++;
    } else {
        printf("objc: too many symbtabs!\n");
        for (;;) ;
    }

#if DEBUG_INIT_SYMTAB
    for (short i = 0; i < symtab->cls_def_cnt; i++) {
        const struct objc_class *const cls = symtab->defs[i];
        printf("objc: loaded class '%s'\n", cls->rodata->name);
    }

    printf("objc: loaded symtab %p\n", symtab);
#endif /* DEBUG_INIT_SYMTAB */
}

Class objc_getClass(const char *const name) {
    for (short i = 0; i < nsymtab; i++) {
        const struct objc_symtab *const symtab = symtabs[i];

        for (short j = 0; j < symtab->cls_def_cnt; j++) {
            struct objc_class *const cls = symtab->defs[j];

            if (!strcmp(name, cls->rodata->name)) {
                return cls;
            }
        }
    }

    return Nil;
}

@implementation Object

+ (Class)self {
    return self;
}

@end

@implementation Protocol

@end