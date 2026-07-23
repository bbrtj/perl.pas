PERL ?= perl
FPC ?= fpc
CC ?= gcc

FPC_FLAGS := -FEbuild -FUbuild -Flbuild -Fusrc
PERL_CFLAGS := $(shell $(PERL) -MExtUtils::Embed -e ccopts)
PERL_LDFLAGS := $(shell $(PERL) -MExtUtils::Embed -e ldopts)
PERL_LIBDIR := $(shell $(PERL) -MConfig -e 'print $$Config{archlibexp}')/CORE
SITE_DIR := site

# fpc's -k passes flags straight to the system linker (ld), not through
# gcc. ExtUtils::Embed's ldopts is written for gcc, though: it contains
# things like "-Wl,-E" (gcc-speak for "pass -E to ld") and gcc-only
# flags such as "-fstack-protector-strong" that plain ld rejects
# outright ("-f may not be used without -shared").
#
# Rather than trying to sanitize every possible gcc flag, just keep the
# handful of tokens raw ld actually needs: library search paths (-L),
# libraries to link (-l), and -E/--export-dynamic (needed so XS modules
# dlopen'd at runtime can resolve Perl core symbols from the exe).
PERL_LDFLAGS_CLEAN := $(shell echo '$(PERL_LDFLAGS)' | sed -e 's/-Wl,/ /g' -e 's/,/ /g')
PERL_LDFLAGS_FPC := $(addprefix -k,$(filter -l% -L% -E --export-dynamic,$(PERL_LDFLAGS_CLEAN)))

all: tests

xs: site/PascalObject.xs
	cd $(SITE_DIR) && $(PERL) Makefile.PL
	cd $(SITE_DIR) && make

wrapper: src/perlwrapper.c prepare
	$(CC) -O2 --shared -fPIC $(PERL_CFLAGS) src/perlwrapper.c -o build/libperlwrapper.so $(PERL_LDFLAGS)

test_wrappers:
	cd t && $(PERL) ../tools/wrapper_generator.pl wrappers.ini

tests: t/tests.t.pas t/leaks.t.pas src/perlembed.pas wrapper xs prepare test_wrappers
	$(FPC) $(FPC_FLAGS) -g -Fut/src -Fupascal-tap/src $(PERL_LDFLAGS_FPC) t/tests.t.pas -ot/tests.t
	$(FPC) $(FPC_FLAGS) -g -Fut/src -Fupascal-tap/src $(PERL_LDFLAGS_FPC) t/leaks.t.pas -ot/leaks.t
	cp -n $(PERL_LIBDIR)/libperl.so t/
	cp build/libperlwrapper.so t/

prepare:
	mkdir -p build

clean:
	rm -Rf build t/tests.t t/leaks.t t/*.so t/src/ObjectWrappers.pas t/lib/TCalculator.pm
	cd $(SITE_DIR) && [ -f Makefile ] && $(MAKE) clean || true

