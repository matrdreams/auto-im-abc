.PHONY: build install uninstall restart status clean

BIN_NAME = auto-im-abc
SRC = Sources/auto-im-abc/main.swift

build:
	swiftc -O $(SRC) -o $(BIN_NAME)

install:
	./install.sh

uninstall:
	./uninstall.sh

restart:
	launchctl kickstart -k gui/$$(id -u)/com.auto-im-abc

status:
	~/.local/bin/auto-im-abc --status

clean:
	rm -rf $(BIN_NAME) .build
