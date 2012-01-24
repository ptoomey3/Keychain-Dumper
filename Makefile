ROOT := $(realpath $(shell dirname $(lastword $(MAKEFILE_LIST))))

# Create some symlinks in the CWD to your toolchain and sdk sysroot
# or just point these directly to their respective paths.
#
# TOOLCHAIN would be /Developer/Platforms/iPhoneOS.platform/Developer 
# if you were using the iPhone sdk.
# ex. ./toolchain -> /Developer/Platforms/iPhoneOS.platform/Developer
#
# SYSROOT would be the location of your iPhoneOS*.sdk directory. Using
# the sdk, that would be under SDKs in the toolchain location.
# ex. ./sdk -> /Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS4.2.sdk/
TOOLCHAIN_DIR=$(ROOT)/toolchain
SYSROOT = $(ROOT)/sdk

BIN=$(TOOLCHAIN_DIR)/usr/bin
GCC_BIN = $(BIN)/gcc


ARCH_FLAGS=-arch armv6
LDFLAGS	=\
	-F./sdk/System/Library/Frameworks/\
	-F./sdk/System/Library/PrivateFrameworks/\
	-framework UIKit\
	-framework CoreFoundation\
	-framework Foundation\
	-framework CoreGraphics\
	-framework Security\
	-lobjc\
	-lsqlite3\
	-bind_at_load

GCC_ARM = $(GCC_BIN) -Os -Wimplicit -isysroot $(SYSROOT) $(ARCH_FLAGS)

default: main.o 
	$(GCC_ARM) $(LDFLAGS) main.o -o keychain_dumper

main.o: main.m
	$(GCC_ARM) -c main.m

clean:
	rm -f keychain_dumper *.o 
