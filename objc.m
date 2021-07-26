#include "objc.h"
#include <stdint.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <stddef.h>

#define CLASS_SETUP (1U << 0)

struct objc_class {
    struct objc_class *isa;
    struct objc_class *superclass;

#if 0
    // NOTE: the Apple runtime replaces these with a single inline cache_t, which is two pointers in size.
    void *cache;
    void *vtable;
#endif /* 0 */
    uintptr_t flags; // void *cache;
    uintptr_t unused; // void *vtable;

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
        printf("objc: undeliverable message '%s' (%p)\n", (const char *)_cmd, _cmd);
        for (;;) ;
    }

    return imp;
}

const struct objc_class *class_getSuperclass(const struct objc_class *cls) {
    return cls->superclass;
}

id class_createInstance(Class cls) {
    const size_t size = cls->rodata->instance_size;
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

static void objc_setup_class(Class cls) {
    if (!(cls->flags & CLASS_SETUP)) {
        cls->flags |= CLASS_SETUP;

        // In an environment with no dynamic linking, we don't have to worry about things like subclasses
        // showing up before (or without, in the case of weak linking) their superclasses.
        const Class superclass = cls->superclass;

        if (superclass) {
            objc_setup_class(cls);

            // Fix up instance_start to account for base class size changes.
            const uint16_t superclass_size = superclass->rodata->instance_size;
            const int16_t start_delta = (int16_t)superclass_size - cls->rodata->instance_start;
            cls->rodata->instance_start = superclass_size;
            cls->rodata->instance_size = superclass_size + start_delta;

#if DEBUG_INIT_SYMTAB
            printf("%s: %hd\n", cls->rodata->name, start_delta);
#endif /* DEBUG_INIT_SYMTAB */

            // Fix up ivar offsets, if necessary.
            if (start_delta != 0) {
                const struct ivar_list *const ivar_list = cls->rodata->ivars;

                if (ivar_list) {
                    for (int i = 0; i < ivar_list->element_count; i++) {
                        const struct ivar *const ivar = &ivar_list->ivars[i];
                        uint16_t *const offset = ivar->offset;
#if DEBUG_INIT_SYMTAB
                        printf("%s: %hu -> %hu\n", ivar->name, *offset, *offset + start_delta);
#endif /* DEBUG_INIT_SYMTAB */
                        *offset += start_delta;
                        // TODO: check that *offset + ivar_size <= instance_size ?
                    }
                }
            }
        }

        // TODO: add category methods.
    }
}

#define MAX_SYMTABS 16
static const struct objc_symtab *symtabs[MAX_SYMTABS];
static unsigned short nsymtab;

void objc_init_symtab(const struct objc_symtab *const symtab) {
    if (nsymtab < MAX_SYMTABS) {
        symtabs[nsymtab] = symtab;
        nsymtab++;
    } else {
        printf("objc: too many symtabs!\n");
        for (;;) ;
    }

    for (short i = 0; i < symtab->cls_def_cnt; i++) {
        const Class cls = symtab->defs[i];
        objc_setup_class(cls);

#if DEBUG_INIT_SYMTAB
        printf("objc: loaded class '%s'\n", cls->rodata->name);
#endif /* DEBUG_INIT_SYMTAB */
    }

#if DEBUG_INIT_SYMTAB
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