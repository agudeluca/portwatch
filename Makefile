.PHONY: build test app install uninstall run clean

build:
	swift build

test:
	swift test

app:
	./scripts/bundle.sh

install: app
	@pkill -x PortWatch 2>/dev/null || true
	rm -rf /Applications/PortWatch.app
	cp -R PortWatch.app /Applications/
	open /Applications/PortWatch.app
	@echo "Installed. Look for ⇅ in the menu bar."

uninstall:
	@pkill -x PortWatch 2>/dev/null || true
	rm -rf /Applications/PortWatch.app
	rm -rf "$(HOME)/Library/Application Support/PortWatch"

run: app
	@pkill -x PortWatch 2>/dev/null || true
	open PortWatch.app

clean:
	swift package clean
	rm -rf .build PortWatch.app
