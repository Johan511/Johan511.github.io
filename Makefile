HUGO_BIN=hugo

.PHONY: build demo release

build:
	$(HUGO_BIN)

demo:
	$(HUGO_BIN) server -D --bind 0.0.0.0

release: build
	rm -rf ./resources && cp -r ./resources ./resources
