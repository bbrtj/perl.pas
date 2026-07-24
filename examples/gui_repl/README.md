# Perl REPL in Pascal

This example provides a very simple Lazarus GUI which reads Perl code, executes
it, and prints the result using `Data::Dumper::Dumper`. It uses
`TDynaLoaderPerl` because apparently `Data::Dumper` won't work without it (it
tries to load `List::Util`, which is written in XS). Stdout is not captured,
only the result of eval (last executed thing). No safety measures are in place,
Perl code is not sandboxed in any way and can do damage to the system if the
program is abused.

Note that Perl.pas currently only handles scalars, so every eval will only show
a scalar result, not a list.

## Compiling

This project is compiled with Lazarus or `lazbuild`. Project options point to a
relative path `../../src` to find PerlEmbed.

Before compiling with Lazarus, a Perl interpreter should be adjusted in Lazarus
options, by adding a new custom option stored in session of the project in
`Additions and Overrides` (in project options). This option should be written
as `-perl/path/to/perl`.

Also before compiling, `make wrapper` should be made in the main directory, and
the `libperlwrapper.so` (from `build` directory) should be made available for
the linking process to succeed. This can be done with `LD_LIBRARY_PATH` or
simply by copying the `.so` to the example directory. Same must be done for
`libperl.so`.

If any adjustments to the build process are needed, they can be added inside
`compile.sh` script.

