COFFEE=node_modules/.bin/coffee

all: lib/bump.js

lib/%.js: src/%.coffee
	$(COFFEE) -cs < $< > $@
