HEADER_SEARCH_PATHS=-I ${HOME}/src/avr-serial/
LIBRARIES=${HOME}/src/avr-serial/build/serial.a
OTHER_CFLAGS=
CFLAGS=--std=c11 -Wa,-mno-dollar-line-separator -mmcu=${MCU} -Os ${HEADER_SEARCH_PATHS} ${OTHER_CFLAGS}
OBJCFLAGS=-x objective-c -fnext-runtime -fobjc-abi-version=2 -fno-objc-sjlj-exceptions -fobjc-nilcheck

CC=avr-gcc
AR=avr-ar
MCU=atmega644p

.PHONY: all clean upload-%

all: build/objc.a

clean:
	rm -r build

build:
	mkdir build

build/%.o: %.c | build
	${CC} -c -o "$@" ${CFLAGS} $<

build/%.o: %.m | build
	${CC} -c -o "$@" ${CFLAGS} ${OBJCFLAGS} $<

build/%.o: %.s | build
	${CC} -c -o "$@" ${CFLAGS} $<

build/objc.a: build/objc.o build/message.o build/misc.o | build
	${AR} -cq $@ $^
