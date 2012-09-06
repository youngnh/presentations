all: at_revelytix.html

at_revelytix.html: at_revelytix.md
	~/.cabal/bin/pandoc --self-contained -s -t slidy -o $@ $<

clean:
	-rm -f at_revelytix.html
