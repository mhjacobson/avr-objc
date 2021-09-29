#include "Test.h"
#include <objc.h>
#include <serial.h>
#include <stdio.h>
#include <avr/interrupt.h>

__attribute__((constructor))
void init_stdio(void) {
    sei();
    serial_init();
    printf("boot\n\n");
}

int main(void) {
    const Class *const classes = objc_copyClassList();

    printf("Running tests...\n");

    for (const Class *c = classes; *c != Nil; c++) {
        const Class cls = *c;

        if (class_conformsToProtocol(cls, @protocol(Test))) {
            printf("Running %s...\n", class_getName(cls));
            [(Class<Test>)cls run];
        }
    }

    printf("Tests passed.\n");
    for (;;) ;
}