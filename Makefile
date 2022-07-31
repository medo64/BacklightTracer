.PHONY: all clean distclean install uninstall dist release package

ifeq ($(PREFIX),)
    PREFIX := /usr/local/
endif


DIST_NAME := backlight-tracer
DIST_VERSION := $(shell cat CHANGES.md | grep '[0-9]\.' | head -1 | cut -d" " -f2)
DIST_ARCHITECTURE := all

SOURCE_LIST := Makefile CONTRIBUTING.md LICENSE.md README.md src/ docs/


HAS_LINTIAN := $(shell which lintian >/dev/null ; echo $$?)
HAS_UNCOMMITTED := $(shell git diff --quiet ; echo $$?)


all: release


clean:
	-@$(RM) -r bin/
	-@$(RM) -r build/

distclean: clean
	-@$(RM) -r dist/
	-@$(RM) -r target/


install: bin/backlight-tracer
	@sudo install -d $(DESTDIR)/$(PREFIX)/bin/
	@sudo install bin/backlight-tracer $(DESTDIR)/$(PREFIX)/bin/
	@mkdir -p build/man/
	@sed 's/MAJOR.MINOR.PATCH/$(DIST_VERSION)/g' docs/man/backlight-tracer.1 > build/man/backlight-tracer.1
	@gzip -cn --best build/man/backlight-tracer.1 > build/man/backlight-tracer.1.gz
	@sudo install -m 644 build/man/backlight-tracer.1.gz /usr/share/man/man1/
	@sudo mandb -q
	@echo Installed at $(DESTDIR)/$(PREFIX)/bin/ | sed 's^//^/^g'

uninstall: $(DESTDIR)/$(PREFIX)/bin/backlight-tracer
	@sudo $(RM) $(DESTDIR)/$(PREFIX)/bin/backlight-tracer
	@sudo $(RM) /usr/share/man/man1/backlight-tracer.1.gz
	@sudo mandb -q

dist: release
	@$(RM) -r build/dist/
	@mkdir -p build/dist/$(DIST_NAME)-$(DIST_VERSION)/
	@cp -r $(SOURCE_LIST) build/dist/$(DIST_NAME)-$(DIST_VERSION)/
	@tar -cz -C build/dist/  --owner=0 --group=0 -f build/dist/$(DIST_NAME)-$(DIST_VERSION).tar.gz $(DIST_NAME)-$(DIST_VERSION)/
	@mkdir -p dist/
	@mv build/dist/$(DIST_NAME)-$(DIST_VERSION).tar.gz dist/
	@echo Output at dist/$(DIST_NAME)-$(DIST_VERSION).tar.gz


release: src/backlight-tracer.sh
	@mkdir -p bin/
	@cp src/backlight-tracer.sh bin/backlight-tracer
	@chmod +x bin/backlight-tracer
	$(if $(findstring 0,$(HAS_UNCOMMITTED)),,$(warning Uncommitted changes present))


package: dist
	$(if $(findstring 0,$(HAS_LINTIAN)),,$(warning No 'lintian' in path, consider installing 'lintian' package))
	@command -v dpkg-deb >/dev/null 2>&1 || { echo >&2 "Package 'dpkg-deb' not installed!"; exit 1; }
	@$(eval PACKAGE_NAME = $(DIST_NAME)_$(DIST_VERSION)_$(DIST_ARCHITECTURE))
	@$(eval PACKAGE_DIR = /tmp/$(PACKAGE_NAME)/)
	-@$(RM) -r $(PACKAGE_DIR)/
	@mkdir $(PACKAGE_DIR)/
	@cp -r package/deb/DEBIAN $(PACKAGE_DIR)/
	@sed -i "s/MAJOR.MINOR.PATCH/$(DIST_VERSION)/" $(PACKAGE_DIR)/DEBIAN/control
	@sed -i "s/ARCHITECTURE/$(DIST_ARCHITECTURE)/" $(PACKAGE_DIR)/DEBIAN/control
	@mkdir -p $(PACKAGE_DIR)/usr/share/doc/backlight-tracer/
	@cp package/deb/copyright $(PACKAGE_DIR)/usr/share/doc/backlight-tracer/copyright
	@cp CHANGES.md build/changelog
	@sed -i '/^$$/d' build/changelog
	@sed -i '/## Release Notes ##/d' build/changelog
	@sed -i '1{s/### \(.*\) \[.*/backlight-tracer \(\1\) stable; urgency=low/}' build/changelog
	@sed -i '/###/,$$d' build/changelog
	@sed -i 's/\* \(.*\)/  \* \1/' build/changelog
	@echo >> build/changelog
	@echo ' -- Josip Medved <jmedved@jmedved.com>  $(shell date -R)' >> build/changelog
	@gzip -cn --best build/changelog > $(PACKAGE_DIR)/usr/share/doc/backlight-tracer/changelog.gz
	@mkdir -p build/man/
	@sed 's/MAJOR.MINOR//g' docs/man/backlight-tracer.1 > build/man/backlight-tracer.1
	@mkdir -p $(PACKAGE_DIR)/usr/share/man/man1/
	@gzip -cn --best build/man/backlight-tracer.1 > $(PACKAGE_DIR)/usr/share/man/man1/backlight-tracer.1.gz
	@find $(PACKAGE_DIR)/ -type d -exec chmod 755 {} +
	@find $(PACKAGE_DIR)/ -type f -exec chmod 644 {} +
	@chmod 755 $(PACKAGE_DIR)/DEBIAN/config $(PACKAGE_DIR)/DEBIAN/p*inst $(PACKAGE_DIR)/DEBIAN/p*rm
	@install -d $(PACKAGE_DIR)/opt/backlight-tracer/
	@install bin/backlight-tracer $(PACKAGE_DIR)/opt/backlight-tracer/
	@install -d $(PACKAGE_DIR)/lib/systemd/system/
	@sudo install -m 644 src/backlight-tracer.service $(PACKAGE_DIR)/lib/systemd/system/
	@fakeroot dpkg-deb -Zgzip --build $(PACKAGE_DIR)/ > /dev/null
	@cp /tmp/$(PACKAGE_NAME).deb dist/
	@$(RM) -r $(PACKAGE_DIR)/
	@lintian --suppress-tags dir-or-file-in-opt dist/$(PACKAGE_NAME).deb
	@echo Output at dist/$(PACKAGE_NAME).deb
	$(if $(findstring 0,$(HAS_UNCOMMITTED)),,$(warning Uncommitted changes present))
