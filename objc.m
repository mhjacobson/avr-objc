/*
 * objc.m
 * author: Matt Jacobson
 * created: May 2021
 */

#include "objc.h"
#include <stdint.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <stddef.h>

// rodata flags
#define CLASS_RO_META           (1U << 0)
#define CLASS_RO_ROOT           (1U << 1)
#define CLASS_RO_CXXSTRUCTORS   (1U << 2)
#define CLASS_RO_HIDDEN         (1U << 4)
#define CLASS_RO_EXCEPTION      (1U << 5)
#define CLASS_RO_IVARRELEASER   (1U << 6)
#define CLASS_RO_ARC            (1U << 7)
#define CLASS_RO_CXXDESTRUCTOR  (1U << 8)
#define CLASS_RO_MRCWEAK        (1U << 9)

// class flags (for non-meta classes)
#define CLASS_SETUP       (1U << 0)
#define CLASS_LOADED      (1U << 1)
#define CLASS_INITIALIZED (1U << 2)

struct objc_object {
    Class isa;
};

struct objc_class {
    struct objc_class *isa;
    struct objc_class *superclass;

#if 0
    // NOTE: the Apple runtime replaces these with a single inline cache_t, which is two pointers in size.
    void *cache;
    void *vtable;
#endif /* 0 */
    union {
        uintptr_t flags;
        Class nonmeta;
    }; // void *cache;
    struct class_rw *rwdata; // void *vtable;

    // NOTE: the Apple runtime replaces this with a class_data_bits_t, which is the rw data pointer plus some flags in the unused bits.
    struct class_ro *rodata;
};

struct class_ro {
    unsigned int flags;
    unsigned int instance_start;
    unsigned int instance_size;
#if !__clang__
    // Well here's a shitty situation.
    // Clang's comments say there is an `unsigned int`-sized "reserved" member here, because 
    // when the objc4 modern runtime is used on LP64 platforms, there would otherwise be a 
    // 32-bit-sized hole here for alignment reasons.
    // However, it doesn't actually add the "reserved" field to its AST data structures.
    // GCC *does* add the field explicitly.
    // On LP64, adding it or not is irrelevant.  But on AVR, sizeof (unsigned int) == sizeof (uint8_t *),
    // and it matters.
    // NOTE: this means that I have to compile Objective-C code either all with clang or all with GCC.
    // Pending fix in GCC: <https://gcc.gnu.org/pipermail/gcc-patches/2021-September/579973.html>
    uint16_t reserved;
#endif
    uint8_t *ivarLayout;
    char *name;
    struct method_list *methods;
    struct protocol_list *protocols;
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
    unsigned int element_size;
    unsigned int element_count;
    struct method methods[];
};

struct ivar {
    long *offset;
    char *name;
    char *type;
    unsigned int alignment_raw;
    unsigned int size;
};

struct ivar_list {
    unsigned int element_size;
    unsigned int element_count;
    struct ivar ivars[];
};

struct property {
    const char *name;
    const char *attributes;
};

struct property_list {
    unsigned int element_size;
    unsigned int element_count;
    struct property properties[];
};

struct protocol_list {
    // clang says `long`, and gcc says `intptr_t`.  Another bug in GCC: <https://gcc.gnu.org/pipermail/gcc-patches/2021-September/580280.html>
#if __clang__
    long count;
#else /* __clang__ */
    intptr_t count;
#endif /* __clang__ */
    Protocol *list[];
};

struct objc_category {
    char *name;
    struct objc_class *cls;
    struct method_list *instanceMethods;
    struct method_list *classMethods;
    struct protocol_list *protocols;
    struct property_list *instanceProperties;
    // Fields below this point are not always present.
    struct property_list *_classProperties;
    unsigned int size;
};

#pragma mark -

#define MAX_ADDED_METHODS 16

struct class_rw {
    uint8_t num_added_methods;
    struct method added_methods[MAX_ADDED_METHODS];
};

#pragma mark -

extern const Class classlist[]   __asm__("__OBJC_CLASSLIST_BEGIN");
extern const Class classlist_end __asm__("__OBJC_CLASSLIST_END");

extern const struct objc_category *catlist[]   __asm__("__OBJC_CATLIST_BEGIN");
extern const struct objc_category *catlist_end __asm__("__OBJC_CATLIST_END");

extern Protocol *protolist[]   __asm__("__OBJC_PROTOLIST_BEGIN");
extern Protocol *protolist_end __asm__("__OBJC_PROTOLIST_END");

#pragma mark -

static struct class_rw *class_getRWData(const Class cls, const BOOL creating) {
    if (creating && !cls->rwdata) {
        cls->rwdata = calloc(sizeof (struct class_rw), 1);
    }

    return cls->rwdata;
}

static Class class_getMetaClass(const Class cls) {
    if (cls->rodata->flags & CLASS_RO_META) {
        return cls;
    } else {
        return cls->isa;
    }
}

static Class class_getNonMetaClass(const Class cls) {
    if ((cls->rodata->flags & CLASS_RO_META) == 0) {
        return cls;
    } else {
        return cls->nonmeta;
    }
}

static IMP class_lookupMethodIfPresent(const Class cls, const SEL _cmd) {
    const struct class_ro *const rodata = cls->rodata;
    const struct method_list *const method_list = rodata->methods;
    const struct class_rw *const rwdata = class_getRWData(cls, NO);

    IMP imp = 0;

    if (rwdata) {
        for (int i = 0; i < rwdata->num_added_methods; i++) {
            const struct method *const method = &rwdata->added_methods[i];

            if (strcmp((const char *)method->name, (const char *)_cmd) == 0) {
                imp = method->imp;
            }
        }
    }

    if (imp == 0 && method_list) {
        for (int i = 0; i < method_list->element_count; i++) {
            const struct method *const method = &method_list->methods[i];

            if (strcmp((const char *)method->name, (const char *)_cmd) == 0) {
                imp = method->imp;
            }
        }
    }

    if (imp == 0 && cls->superclass) {
        imp = class_lookupMethodIfPresent(cls->superclass, _cmd);
    }

    return imp;
}

IMP class_lookupMethod(const Class cls, const SEL _cmd) {
    // For now, always call +initialize on this path, since it's only used by messaging.
    const Class metaclass = class_getMetaClass(cls);
    const Class nonMetaClass = class_getNonMetaClass(cls);

    if (!(nonMetaClass->flags & CLASS_INITIALIZED)) {
        nonMetaClass->flags |= CLASS_INITIALIZED;

        const IMP initializeIMP = class_lookupMethodIfPresent(metaclass, @selector(initialize));

        if (initializeIMP) {
            ((void (*)(Class, SEL))initializeIMP)(nonMetaClass, @selector(initialize));
        }
    }

    const IMP imp = class_lookupMethodIfPresent(cls, _cmd);

    if (imp == 0) {
        const BOOL meta = (cls->rodata->flags & CLASS_RO_META) != 0;
        const char sigil = "-+"[meta]; // clang crashes with ternary
        // <https://reviews.llvm.org/D95664>, <https://bugs.llvm.org/show_bug.cgi?id=48863>

        printf("objc: undeliverable message %c[%s %s] (cls=%p, _cmd=%p)\n", sigil, cls->rodata->name, (const char *)_cmd, cls, _cmd);
        for (;;) ;
    }

    return imp;
}

Class class_getSuperclass(const Class cls) {
    return cls->superclass;
}

id class_createInstance(const Class cls) {
    const size_t size = cls->rodata->instance_size;
    const id object = calloc(size, 1);
    object_setClass(object, cls);
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

#if DEBUG_INIT
            printf("%s: %hd\n", cls->rodata->name, start_delta);
#endif /* DEBUG_INIT */

            // Fix up instance size and ivar offsets, if necessary.
            if (start_delta != 0) {
                cls->rodata->instance_size += start_delta;
                const struct ivar_list *const ivar_list = cls->rodata->ivars;

                if (ivar_list) {
                    for (int i = 0; i < ivar_list->element_count; i++) {
                        const struct ivar *const ivar = &ivar_list->ivars[i];
                        long *const offset = ivar->offset;
#if DEBUG_INIT
                        printf("%s: %lu -> %lu\n", ivar->name, *offset, *offset + start_delta);
#endif /* DEBUG_INIT */
                        *offset += start_delta;
                        // TODO: check that *offset + ivar_size <= instance_size ?
                    }
                }
            }
        }

        const Class metaclass = cls->isa;
        metaclass->nonmeta = cls;

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
            const struct method *const method = &instance_method_list->methods[i];
            class_addMethod(cls, *method);
        }
    }

    const Class metaclass = cls->isa;
    const struct method_list *const class_method_list = category->classMethods;
    
    if (class_method_list) {
        for (int i = 0; i < class_method_list->element_count; i++) {
            const struct method *const method = &class_method_list->methods[i];

            // Don't install +load.
            if (strcmp((const char *)method->name, "load") != 0) {
                class_addMethod(metaclass, *method);
            }
        }
    }

    // TODO: add category's protocol conformances
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

static void objc_load_category(const struct objc_category *const category) {
    // Send category +load, if necessary.
    const struct method_list *const class_method_list = category->classMethods;

    if (class_method_list) {
        for (int i = 0; i < class_method_list->element_count; i++) {
            const struct method *const method = &class_method_list->methods[i];

            if (strcmp((const char *)method->name, "load") == 0) {
                const Class cls = category->cls;
                const SEL load = @selector(load);
                const IMP loadIMP = method->imp;

                loadIMP(cls, load);
                break;
            }
        }
    }
}

// ISO C11, sec. 6.5.9.6
// Two pointers compare equal if and only if both are null pointers, both are pointers to the
// same object (including a pointer to an object and a subobject at its beginning) or function,
// both are pointers to one past the last element of the same array object, or one is a pointer
// to one past the end of one array object and the other is a pointer to the start of a different
// array object that happens to immediately follow the first array object in the address
// space. [109]
//
// [109]:
// Two objects may be adjacent in memory because they are adjacent elements of a larger array or
// adjacent members of a structure with no padding between them, or because the implementation chose
// to place them so, even though they are unrelated. If prior invalid pointer operations (such as accesses
// outside array bounds) produced undefined behavior, subsequent comparisons also produce undefined
// behavior.

static void objc_setup_classes(void) {
    for (const Class *ptr = classlist; ptr != &classlist_end; ptr++) {
        const Class cls = *ptr;
        objc_setup_class(cls);
#if DEBUG_INIT
        printf("objc: setup class '%s'\n", cls->rodata->name);
#endif /* DEBUG_INIT */
    }
}

static void objc_install_categories(void) {
    for (const struct objc_category **ptr = catlist; ptr != &catlist_end; ptr++) {
        const struct objc_category *const category = *ptr;
        objc_install_category(category);

#if DEBUG_INIT
        printf("objc: installed category '%s'\n", category->name);
#endif /* DEBUG_INIT */
    }
}

static void objc_load_classes(void) {
    for (const Class *ptr = classlist; ptr != &classlist_end; ptr++) {
        const Class cls = *ptr;
        objc_load_class(cls);

#if DEBUG_INIT
        printf("objc: loaded class '%s'\n", cls->rodata->name);
#endif /* DEBUG_INIT */
    }
}

static void objc_load_categories(void) {
    for (const struct objc_category **ptr = catlist; ptr != &catlist_end; ptr++) {
        const struct objc_category *const category = *ptr;
        objc_load_category(category);

#if DEBUG_INIT
        printf("objc: loaded category '%s'\n", category->name);
#endif /* DEBUG_INIT */
    }
}

static void objc_setup_protocols(void) {
    const Class ProtocolClass = [Protocol self];

    for (Protocol **ptr = protolist; ptr != &protolist_end; ptr++) {
        Protocol *const protocol = *ptr;
        object_setClass(protocol, ProtocolClass);

#if DEBUG_INIT
        printf("objc: setup protocol '%s'\n", protocol->_name);
#endif /* DEBUG_INIT */
    }
}

__attribute__((constructor))
static void objc_init(void) {
    objc_setup_classes();
    objc_install_categories();
    objc_load_classes();
    objc_load_categories();
    objc_setup_protocols();

#if DEBUG_INIT
    printf("objc: initialized\n");
#endif /* DEBUG_INIT */
}

Class objc_getClass(const char *const name) {
    for (const Class *ptr = classlist; ptr < &classlist_end; ptr++) {
        const Class cls = *ptr;

        if (!strcmp(name, cls->rodata->name)) {
            return cls;
        }
    }

    return Nil;
}

Class *objc_copyClassList(void) {
    size_t n = 0;

    for (const Class *ptr = classlist; ptr < &classlist_end; ptr++) {
        n++;
    }

    Class *const list = malloc((n + 1) * sizeof (Class));
    memcpy(list, classlist, n * sizeof (Class));
    list[n] = Nil;

    return list;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-objc-isa-usage"

Class object_getClass(const id object) {
    return object->isa;
}

void object_setClass(const id object, const Class cls) {
    object->isa = cls;
}

#pragma clang diagnostic pop

const char *class_getName(const Class cls) {
    return cls->rodata->name;
}

BOOL class_conformsToProtocol(const Class cls, const Protocol *const protocol) {
    const struct protocol_list *const protocols = cls->rodata->protocols;

    if (protocols != NULL) {
        for (long i = 0; i < protocols->count; i++) {
            const Protocol *const p = protocols->list[i];

            if (protocol_conformsToProtocol(p, protocol)) {
                return YES;
            }
        }
    }

    return NO;
}

const Protocol *objc_getProtocol(const char *const name) {
    for (const Protocol **ptr = protolist; ptr < &protolist_end; ptr++) {
        const Protocol *protocol = *ptr;

        if (!strcmp(name, protocol->_name)) {
            return protocol;
        }
    }

    return nil;
}

BOOL protocol_conformsToProtocol(const Protocol *const conformer, const Protocol *const conformee) {
    if (conformer == conformee) {
        return YES;
    } else {
        const struct protocol_list *const protocols = conformer->_protocols;

        if (protocols != NULL) {
            for (long i = 0; i < protocols->count; i++) {
                Protocol *const p = protocols->list[i];

                if (protocol_conformsToProtocol(p, conformee)) {
                    return YES;
                }
            }
        }

        return NO;
    }
}

Property class_getProperty(const Class cls, const char *const name) {
    struct property_list *const property_list = cls->rodata->properties;

    if (property_list != NULL) {
        for (int i = 0; i < property_list->element_count; i++) {
            const Property p = &property_list->properties[i];

            if (!strcmp(p->name, name)) {
                return p;
            }
        }
    }

    // TODO: check categories

    return NULL;
}

Property protocol_getProperty(const Protocol *const protocol, const char *const name) {
    struct property_list *const property_list = protocol->_instanceProperties;

    if (property_list != NULL) {
        for (int i = 0; i < property_list->element_count; i++) {
            const Property p = &property_list->properties[i];

            if (!strcmp(p->name, name)) {
                return p;
            }
        }
    }

    return NULL;
}

const char *property_getName(const Property property) {
    return property->name;
}

const char *property_getAttributes(const Property property) {
    return property->attributes;
}

/*
 * Property attribute string format:
 *   - Comma-separated name-value pairs
 *   - Name and value may not contain ','
 *   - Name may not contain '"'
 *   - Value may be empty
 *   - Name is:
 *     - single char (value follows), or
 *     - double-quoted string of 2+ chars (value follows closing quote)
 */
char *property_copyAttributeValue(const Property property, const char *const attributeName) {
    const char *attributes = property_getAttributes(property);
    char *value = NULL;

    while (*attributes != '\0') {
        BOOL isQuotedName = NO;
        size_t nameLen = 1;

        // Detect quoted name.
        if (*attributes == '"') {
            attributes++;
            isQuotedName = YES;

            nameLen = strcspn(attributes, "\"");
        }

        // Compare name to requested name.
        const int cmp = strncmp(attributes, attributeName, nameLen);
        attributes += nameLen;

        // Skip closing quote if needed.
        if (isQuotedName) {
            attributes++;
        }

        // The value ends at the next ',' or '\0'.
        const size_t valueLen = strcspn(attributes, ",");

        // If name matched, copy and return value.  Otherwise, skip value.
        if (cmp == 0) {
            value = malloc(valueLen + 1);
            strncpy(value, attributes, valueLen);
            value[valueLen] = '\0';
            break;
        } else {
            attributes += valueLen;

            if (*attributes == ',') {
                attributes++;
            }
        }
    }

    return value;
}

@implementation Object

- (id)self {
    return self;
}

// Unlike NSObject, we let [SomeClass class] return the metaclass.
- (Class)class {
    return _isa;
}

- (BOOL)conformsToProtocol:(Protocol *const)protocol {
    // class_conformsToProtocol() works fine when called on the metaclass.
    return class_conformsToProtocol([self class], protocol);
}

@end

@implementation Protocol

- (const char *)name {
    return _name;
}

- (BOOL)conformantClassesConformToProtocol:(Protocol *)conformee {
    return protocol_conformsToProtocol(self, conformee);
}

@end

@implementation Object (Description)

+ (const char *)description {
    return class_getName(self);
}

- (const char *)copyDescription {
    char *const description = malloc(30);
    snprintf(description, 30, "<%s: %p>", [self->_isa description], self);
    return description;
}

@end
