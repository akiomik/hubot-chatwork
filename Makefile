.PHONY: test
test:
	mocha --compilers coffee:coffee-script tests
