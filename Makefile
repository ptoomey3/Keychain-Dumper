TARGET := iphone:clang:latest:10.0
export THEOS_DEVICE_IP = 192.168.31.89
export THEOS_DEVICE_PORT = 22
include $(THEOS)/makefiles/common.mk

TOOL_NAME = keychain_dumper

keychain_dumper_FILES = main.m
keychain_dumper_CFLAGS = -fno-objc-arc
keychain_dumper_CODESIGN_FLAGS = -Sentitlements.xml
keychain_dumper_INSTALL_PATH = /usr/bin

include $(THEOS_MAKE_PATH)/tool.mk
SUBPROJECTS += securitydhook
include $(THEOS_MAKE_PATH)/aggregate.mk
 