#
# Makefile
# author: Matt Jacobson
# created: July 2021
#

OTHER_CFLAGS=

ifdef GCC
  GENFLAGS=-mmcu=${MCU}
  CFLAGS=--std=c11 -Wa,-mno-dollar-line-separator -Os ${OTHER_CFLAGS}
  OBJCFLAGS=-x objective-c -fnext-runtime -fobjc-abi-version=2 -fno-objc-sjlj-exceptions -fobjc-nilcheck
  CC=avr-gcc
else
  GENFLAGS=-target avr -mmcu=${MCU} --sysroot /opt/local
  CFLAGS=--std=c11 -mdouble=64 -Os -Wno-cast-of-sel-type ${OTHER_CFLAGS}
  OBJCFLAGS=-x objective-c -fobjc-runtime=macosx
  CC=avr-clang
endif

AR=avr-ar
MCU=atmega644p

.PHONY: all clean upload-%

all: build/objc.a

clean:
	rm -rf build

build:
	mkdir build

build/%.o: %.c | build
	${CC} -c -o "$@" ${GENFLAGS} ${CFLAGS} $<

build/%.o: %.m | build
	${CC} -c -o "$@" ${GENFLAGS} ${CFLAGS} ${OBJCFLAGS} $<

build/%.o: %.s | build
	${CC} -c -o "$@" ${GENFLAGS} $<

build/objc.a: build/objc.o build/message.o build/misc.o | build
	${AR} -cq $@ $^
