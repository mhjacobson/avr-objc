#import "Test.h"
#import <objc.h>
#import <serial.h>
#import <stdio.h>
#import <avr/interrupt.h>

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