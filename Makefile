# kutu OS Makefile
# All builds and tests run inside docker/QEMU; nothing touches the host system.

.PHONY: help check packages build clean distclean test-vm smoke test

help:
	@echo "kutu OS build system"
	@echo ""
	@echo "  make packages   - build kutu-* packages into work/repo (docker)"
	@echo "  make build      - build the ISO (docker, 30-90 min first run)"
	@echo "  make test       - lint + unit tests + package builds (docker)"
	@echo "  make smoke      - boot latest ISO in QEMU and assert the memory stack"
	@echo "  make test-vm    - boot latest ISO in QEMU interactively"
	@echo "  make clean      - remove build dir (docker, no sudo)"
	@echo "  make distclean  - remove build dir and ISOs"
	@echo ""

check:
	@for cmd in docker qemu-system-x86_64; do \
		command -v $$cmd >/dev/null 2>&1 && echo "ok: $$cmd" || echo "missing: $$cmd"; \
	done

packages:
	./scripts/build-packages.sh

build:
	./scripts/build.sh

test:
	./scripts/test.sh

smoke:
	./scripts/smoke-test.sh

test-vm:
	./scripts/test-vm.sh

clean:
	docker run --rm -v "$$PWD:/w" archlinux:base-devel rm -rf /w/work

distclean: clean
	rm -rf out && mkdir -p out
