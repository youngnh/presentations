all: clojurescript.html

clojurescript.html: clojurescript.md
	~/.cabal/bin/pandoc --offline -s -t slidy -o $@ $<

clean:
	-rm -f clojurescript.html