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

Perl should be compiled without any `@INC` to avoid potential lib mismatches and
make it easier to test - work out how to do that.

To make XS layer work, DynaLoader must be available for the perl interpreter to
import during runtime.

Perl should be sandboxed as much as possible - for example, it should not be
possible to change program's name with `$0`, or cause the termination of the
program with `exit`.

Perl functions can only be called in scalar context.

## Author

Bartosz Jarzyna, bbrtj.pro@gmail.com

## License

BSD 3-clause

