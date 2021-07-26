#include "objc.h"
#include <stdint.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <stddef.h>

#define CLASS_SETUP  (1U << 0)
#define CLASS_LOADED (1U << 1)

struct objc_class {
    struct objc_class *isa;
    struct objc_class *superclass;

#if 0
    // NOTE: the Apple runtime replaces these with a single inline cache_t, which is two pointers in size.
    void *cache;
    void *vtable;
#endif /* 0 */
    uintptr_t flags; // void *cache;
    struct class_rw *rwdata; // void *vtable;

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

struct objc_category {
    char *name;
    struct objc_class *cls;
    struct method_list *instanceMethods;
    struct method_list *classMethods;
#if 0
    struct protocol_list_t *protocols;
    struct property_list_t *instanceProperties;
    // Fields below this point are not always present.
    struct property_list_t *_classProperties;
#endif /* 0 */
};

#pragma mark -

#define MAX_ADDED_METHODS 16

struct class_rw {
    uint8_t num_added_methods;
    struct method added_methods[MAX_ADDED_METHODS];
};

static struct class_rw *class_getRWData(const Class cls, const BOOL creating) {
    if (creating && !cls->rwdata) {
        cls->rwdata = calloc(sizeof (struct class_rw), 1);
    }

    return cls->rwdata;
}

static IMP class_lookupMethodIfPresent(struct objc_class *const cls, const SEL _cmd) {
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

    const struct class_rw *const rwdata = class_getRWData(cls, NO);

    if (rwdata) {
        for (int i = 0; i < rwdata->num_added_methods; i++) {
            const struct method *const method = &rwdata->added_methods[i];

            if (strcmp((char *)method->name, (char *)_cmd) == 0) {
                imp = method->imp;
            }
        }
    }

    if (imp == 0 && cls->superclass) {
        imp = class_lookupMethodIfPresent(cls->superclass, _cmd);
    }

    return imp;
}

IMP class_lookupMethod(struct objc_class *const cls, const SEL _cmd) {
    const IMP imp = class_lookupMethodIfPresent(cls, _cmd);

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

static void objc_setup_class(const Class cls) {
    if (!(cls->flags & CLASS_SETUP)) {
        // In an environment with no dynamic linking, we don't have to worry about things like subclasses
        // showing up before (or without, in the case of weak linking) their superclasses.
        const Class superclass = cls->superclass;

        if (superclass) {
            objc_setup_class(superclass);

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

        cls->flags |= CLASS_SETUP;
    }
}

static void class_addMethod(const Class cls, const struct method method) {
    struct class_rw *const rwdata = class_getRWData(cls, YES);

    if (rwdata->num_added_methods < MAX_ADDED_METHODS) {
        rwdata->added_methods[rwdata->num_added_methods] = method;
        rwdata->num_added_methods++;
    } else {
        printf("objc: too many methods added to '%s'\n", cls->rodata->name);
        for (;;) ;
    }
}

static void objc_install_category(const struct objc_category *const category) {
    const Class cls = category->cls;
    const struct method_list *const instance_method_list = category->instanceMethods;
    
    if (instance_method_list) {
        for (int i = 0; i < instance_method_list->element_count; i++) {
            class_addMethod(cls, instance_method_list->methods[i]);
        }
    }

    const Class metaclass = cls->isa;
    const struct method_list *const class_method_list = category->classMethods;
    
    if (class_method_list) {
        for (int i = 0; i < class_method_list->element_count; i++) {
            class_addMethod(metaclass, class_method_list->methods[i]);
        }
    }
}

static void objc_load_class(const Class cls) {
    if (!(cls->flags & CLASS_LOADED)) {
        // In an environment with no dynamic linking, we don't have to worry about things like subclasses
        // showing up before (or without, in the case of weak linking) their superclasses.
        const Class superclass = cls->superclass;

        if (superclass) {
            objc_load_class(cls->superclass);
        }

        // Send +load, if necessary.
        const Class metaclass = cls->isa;
        const SEL load = @selector(load);
        const IMP loadIMP = class_lookupMethodIfPresent(metaclass, load);

        if (loadIMP) {
            loadIMP(cls, load);
        }

        cls->flags |= CLASS_LOADED;
    }
}

#define MAX_SYMTABS 8
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
        printf("objc: setup class '%s'\n", cls->rodata->name);
#endif /* DEBUG_INIT_SYMTAB */
    }

    for (short i = 0; i < symtab->cat_def_cnt; i++) {
        const struct objc_category *const category = symtab->defs[symtab->cls_def_cnt + i];
        objc_install_category(category);

#if DEBUG_INIT_SYMTAB
        printf("objc: installed category '%s'\n", category->name);
#endif /* DEBUG_INIT_SYMTAB */
    }

    for (short i = 0; i < symtab->cls_def_cnt; i++) {
        const Class cls = symtab->defs[i];
        objc_load_class(cls);

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

@implementation Object (Description)

+ (const char *)description {
    return ((Class)self)->rodata->name;
}

- (const char *)copyDescription {
    char *const description = malloc(30);
    snprintf(description, 30, "<%s: %p>", [self->_isa description], self);
    return description;
}

@end