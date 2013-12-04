.PHONY: test
test:
	mocha test

test-coverage:
	mocha -R html-cov test > coverage.html

test-coveralls:
	mocha test --reporter mocha-lcov-reporter | coveralls
