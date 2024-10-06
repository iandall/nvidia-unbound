
saved_version := $(file <VERSION)

version ?= $(shell git describe --always 2>/dev/null || :)
ifeq (${version},)
        # Not in a git tree
	version:=${saved_version}
endif


# maybe we won't use the sort_version anywhere
short_version := $(shell git describe --abbrev=0 --always 2>/dev/null || :)
ifeq (${short_version},)
        # Not in a git tree
	short_version:=${version}
endif


prefix ?= /usr/local
bindir ?= ${prefix}/bin
mandir ?= ${prefix}/share/man
confdir ?= ${prefix}/

DOCS := doc/nvidia-unbound.1

all: nvidia-unbound $(DOCS)

.PHONY: all


ifneq (${version},${saved_version})
.PHONY: VERSION
VERSION:
	$(file >VERSION,$(version))
endif

nvidia-unbound:	nvidia-unbound.sh VERSION
	sed -e '1,10s/@@VERSION@@/$(version)/' nvidia-unbound.sh > nvidia-unbound
	@chmod 0755 nvidia-unbound

install: all
	mkdir -p $(DESTDIR}$(bindir)
	mkdir -p $(DESTDIR}$(mandir)
	install -m 0755 nvidia-unbound $(DESTDIR)$(bindir)/nvidia-unbound


doc/nvidia-unbound.1: nvidia-unbound 
	help2man --no-info nvidia-unbound -o $@
