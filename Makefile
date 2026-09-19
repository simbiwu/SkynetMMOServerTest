.PHONY: bootstrap build test server client debug-console build-luapanda

bootstrap:
	./scripts/bootstrap_skynet.sh

build:
	./scripts/linux/build.sh

test:
	./scripts/linux/test.sh

server:
	./scripts/linux/run_server.sh

client:
	./scripts/linux/run_client.sh

debug-console:
	./scripts/linux/debug_console.sh

build-luapanda:
	./scripts/linux/build_luapanda.sh