# Perl interpreter embeded in a Pascal runtime

This is a set of tools which makes it easier to embed Perl interpreter inside a
Pascal program. This is significantly more difficult than embeding in C,
because Pascal has no access to Perl C macros, which do a lot of heavy lifting.

## Description

`src/perlembed.pas` is a Pascal unit which contains `TPerlHandle` - a class
holding the pointer to a Perl interpreter. Constructing this class results in
allocating and initializing a Perl interpreter. The base class offers only a
very bare interface to the interpreter - you are expected to subclass it and
make some higher level functions to call whatever perl code you need.

## Building

This repo can only build automated tests, with `make tests`. Then, `prove` can
be run to ensure everything is working correctly.

To use it in a project, you need the contents of `src` and use unit `PerlEmbed`
in your Pascal code. Building process can be copied from `makefile`.

## TODO

Only unthreaded perls are supported right now. No support for multiplicity -
only one interpreter can be instantiated at a time.

Perl functions can only be called in scalar context.

There is no way to call Pascal back from Perl - an XS layer for that needs to
be created, with XS code generation.

Eventually, a shared library for wrapping perl embedding should be developed,
which will only require you to add `PerlEmbed` into the project and link
correctly with `libperlpas` and `libperl`, without the need to build
`perlwrapper.c` with C compiler.

## Author

Bartosz Jarzyna, bbrtj.pro@gmail.com

## License

BSD 3-clause

