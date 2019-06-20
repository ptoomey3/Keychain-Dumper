#!/bin/bash
rm /usr/bin/keychain_dumper
ldid -Sentitlements.xml keychain_dumper
mv keychain_dumper /usr/bin
