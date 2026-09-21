LUA ?= lua

build:
	luac -o dist/config.luac src/main.lua

test:
	$(LUA) tests/test_parameters.lua
