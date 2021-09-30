HEADER_SEARCH_PATHS=-I ${HOME}/src/avr-serial/ -I ../
LIBRARIES=${HOME}/src/avr-serial/build/serial.a ../build/objc.a
OTHER_CFLAGS=

ifdef GCC
  GENFLAGS=-mmcu=${MCU}
  CFLAGS=--std=c11 -Wa,-mno-dollar-line-separator -Os ${HEADER_SEARCH_PATHS} ${OTHER_CFLAGS}
  OBJCFLAGS=-x objective-c -fnext-runtime -fobjc-abi-version=2 -fno-objc-sjlj-exceptions -fobjc-nilcheck
  CC=avr-gcc
else
  GENFLAGS=-target avr -mmcu=${MCU} --sysroot /opt/local
  CFLAGS=--std=c11 -mdouble=64 -Os ${HEADER_SEARCH_PATHS} ${OTHER_CFLAGS}
  OBJCFLAGS=-x objective-c -fobjc-runtime=macosx
  CC=avr-clang
endif

LDFLAGS=-Wl,--gc-sections -Wl,--allow-multiple-definition -Wl,-T,../link.ld
OBJCOPY=avr-objcopy
MCU=atmega1284

.PHONY: all clean upload-%

all: build/objc-test

clean:
	rm -rf build

build:
	mkdir build

build/%.o: %.c | build
	${CC} -c -o "$@" ${GENFLAGS} ${CFLAGS} $<

build/%.o: %.m | build
	${CC} -c -o "$@" ${GENFLAGS} ${CFLAGS} ${OBJCFLAGS} $<

build/objc-test: build/Test.o build/Category.o build/Messaging.o build/Protocols.o | build
	${CC} -o "$@" ${GENFLAGS} ${LDFLAGS} $^ ${LIBRARIES}

build/objc-test.hex: build/objc-test | build
	${OBJCOPY} -O ihex -R .eeprom $< $@

upload: build/objc-test.hex
	avrdude -p${MCU} -c${PROGRAMMER} -P${PORT} -b${BAUD} -D -Uflash:w:$<:i

upload-usb: build/objc-test.hex
	avrdude -p${MCU} -cusbtiny -Uflash:w:$<:i