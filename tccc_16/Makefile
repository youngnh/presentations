all: closure.html

closure.html: closure.md
	~/.cabal/bin/pandoc --self-contained -s -t slidy -o $@ $<

clean:
	rm -f closure.html
