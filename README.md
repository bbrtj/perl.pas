# Perl interpreter embeded in a Pascal runtime

This is a set of tools which makes it easier to embed Perl interpreter inside a
Pascal program. This is significantly more difficult than embeding in C,
because Pascal has no access to Perl C macros, which do a lot of heavy lifting.

`perlembed.pas` is a Pascal unit which contains `TPerlContext` - a class
holding the pointer to a Perl interpreter. Constructing this class results in
allocating and initializing a Perl interpreter. The base class offers only a
very bare interface to the interpreter - you are expected to subclass it and
make some higher level functions to call whatever perl code you need.

At the moment, following restrictions are in place:

- only one class of the interpreter can be instantiated at a time (regardless
  of interpreter's multiplicity)
- can only be linked to non-threaded perls

## Author

Bartosz Jarzyna, bbrtj.pro@gmail.com

## License

BSD 3-clause

