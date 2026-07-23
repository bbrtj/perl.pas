#!/usr/bin/env perl

use v5.14;
use strict;
use warnings;
use autodie;
use English;
use List::Util qw(any);

use constant DEFAULT_SECTION => '__DEFAULT';
use constant KNOWN_BASE_TYPES => [qw(String Int64 Double)];
use constant MAPPINGS_PERL => {
	String => 'Perl.ScalarToString',
	Int64 => 'Perl.ScalarToInteger',
	Double => 'Perl.ScalarToFloat',
};
use constant MAPPINGS_PASCAL => {
	String => 'Perl.StringToScalar',
	Int64 => 'Perl.IntegerToScalar',
	Double => 'Perl.FloatToScalar',
};

sub parse_config
{
	my ($filename) = @_;
	my @lines = do {
		open my $fh, '<', $filename;
		readline $fh;
	};

	state $parse_ini_line = qr{
		\A
		(
			(?: # [Section]
				\s* \[
				(?<section> [^\[\]]+ )
				\]
			)
			|
			(?: # key=value
				\s*
				(?<key> \w+)
				\s* = \s*
				(?<value> .*)
			)
			|
			(?: # ;comment - no capture
				; .*
			)
			|
			(?: # empty line - no capture
				\s*
			)
		)
		\Z
	}x;

	my %config;
	my $current_section;
	my $line_no = 0;
	foreach my $line (@lines) {
		die "error in line $line_no: not an ini line"
			unless $line =~ $parse_ini_line;

		my ($section, $key, $value) = @{^CAPTURE}{qw(section key value)};
		if ($section) {
			$current_section = $section;
		}
		elsif ($key) {
			$config{$current_section // DEFAULT_SECTION}{$key} = $value;
		}

		++$line_no;
	}

	return %config;
}

sub get_signature
{
	my ($string) = @_;

	my ($args_string, $result) = split /:/, $string;
	my @args = split /;/, ($args_string // '');

	# TODO: allow mapping to types unknown here / add a typemap
	foreach my $type (@args, $result // ()) {
		die "unknown type $type, supported: " . join ', ', @{(KNOWN_BASE_TYPES)}
			unless any { $type eq $_ } @{(KNOWN_BASE_TYPES)};
	}

	return (\@args, $result);
}

sub pascal_to_snake
{
	my ($string) = @_;

	$string = lcfirst $string;
	$string =~ s{([A-Z][^A-Z])}{'_' . lc $1}ge;

	return $string;
}

sub snake_to_pascal
{
	my ($string) = @_;

	$string = ucfirst $string;
	$string =~ s{_(\w)}{uc $1}ge;

	return $string;
}

sub resolve_blueprint
{
	my ($blueprint) = @_;

	state $blueprints = do {
		my @lines = readline *DATA;
		my %all;
		my @last;
		my $name;
		my $indentation;

		my $add_blueprint = sub {
			pop @last while @last && $last[-1] =~ m{^\s*$};
			$all{$name} = join '', map { s{^$indentation}{}r } @last
				if $name;
			@last = ();
			undef $indentation;
		};

		foreach my $line (@lines) {
			if ($line =~ m{^(\w+)$}) {
				$add_blueprint->();
				$name = $1;
			}
			else {
				$indentation //= ($line =~ m{^(\s+)})[0];
				push @last, $line;
			}
		}

		$add_blueprint->();
		foreach my $key (keys %all) {
			my $content = $all{$key};
			$all{$key} = sub {
				my (%args) = @_;

				my $result = $content;
				foreach my $key (keys %args) {
					my $replace_key = uc "%%$key";
					$result =~ s{
						(^\h+)? \Q$replace_key\E \b
					}{
						my $result = $args{$key};
						if ($1) {
							my $indentation = $1;
							$result =~ s{^(.)}{$indentation$1}mg;
						}

						$result
					}mgex;
				}

				return $result;
			};
		}

		# special cases
		$all{joined} = sub {
			my (%args) = @_;

			my $result = join $args{separator}, @{$args{values}};
			$result = $args{prefix} . $result
				if defined $args{prefix};

			return $result;
		};

		\%all;
	};

	return $blueprint unless ref $blueprint;

	if (ref $blueprint eq 'HASH') {
		$blueprint = {map { $_ => resolve_blueprint($blueprint->{$_}) } keys %$blueprint};

		my $type = $blueprint->{blueprint};
		return ($blueprints->{$type} // die "bad blueprint $type")
			->(%{$blueprint});
	}
	elsif (ref $blueprint eq 'ARRAY') {
		return [map { resolve_blueprint($_) } @{$blueprint}];
	}
}

sub generate_pascal
{
	my ($result, $class_name, $class_conf, $class_opts) = @_;
	my $wrapper_class_name = "${class_name}Pascal";
	my $constructor_name = $class_opts->{_constructor};
	my $constructor_args;

	if ($constructor_name) {
		push @{$result->{unit}{initialization}{values}}, "PascalObjectRegistry.RegisterClass($wrapper_class_name);";
		($constructor_args) = get_signature(delete $class_conf->{$constructor_name});
	}

	if ($class_opts->{_unit}) {
		push @{$result->{unit}{uses}{values}}, $class_opts->{_unit};
	}

	my @subs;
	foreach my $method (sort keys %{$class_conf}) {
		my ($args, $returns) = get_signature($class_conf->{$method});
		my $type = defined $returns ? 'Function' : 'Procedure';

		push @subs, {
			blueprint => "PerlPascal${type}Definition",
			pascal_name => $method,
			perl_name => pascal_to_snake($method),
			perl_args_count => scalar @$args,
			perl_args => {
				blueprint => 'joined',
				separator => ', ',
				values => [map { MAPPINGS_PERL->{$args->[$_]} . "(Args[$_])" } 0 .. $#$args],
			},
			($returns ? (pascal_result => MAPPINGS_PASCAL->{$returns}) : ()),
		};
	}

	push @{$result->{unit}{type}{values}}, {
		blueprint => 'PerlPascalClassDeclaration',
		class_name => $wrapper_class_name,
		class => $class_name,
	};

	push @{$result->{unit}{implementation}{values}}, {
		blueprint => 'PerlPascalClassDefinition',
		class_name => $wrapper_class_name,
		class => $class_name,
		create_call => $constructor_name ? {
			blueprint => 'PerlPascalConstructorCall',
			class => $class_name,
			constructor_name => $constructor_name,
			perl_args_count => scalar @$constructor_args,
			perl_args => {
				blueprint => 'joined',
				separator => ', ',
				values => [map { MAPPINGS_PERL->{$constructor_args->[$_]} . "(Args[$_])" } 0 .. $#$constructor_args],
			}
		} : '',
		method_switch => {
			blueprint => 'joined',
			separator => "\n",
			values => \@subs,
		},
	};

	$result->{modules}{$class_name} = {
		blueprint => 'PerlModule',
		module_name => $class_name,
		methods => {
			blueprint => 'joined',
			separator => ' ',
			values => [map { $_->{perl_name} } @subs],
		},
	};
}

sub generate_perl
{
	my ($result, $class_name, $class_conf, $class_opts) = @_;
	my $wrapper_class_name = "TPerl${class_name}";
	my $constructor_name = $class_opts->{_constructor};
	my $constructor_args;

	if ($constructor_name) {
		($constructor_args) = get_signature(delete $class_conf->{$constructor_name});
	}

	my @subs_declaration;
	my @subs_definition;
	foreach my $method (sort keys %{$class_conf}) {
		my ($args, $returns) = get_signature($class_conf->{$method});
		my $type = defined $returns ? 'Function' : 'Procedure';

		push @subs_declaration, {
			blueprint => "PascalPerl${type}Declaration",
			name => snake_to_pascal($method),
			args => {
				blueprint => 'joined',
				separator => '; ',
				values => [map { "Arg$_: $args->[$_]" } 0 .. $#$args],
			},
			($returns ? (result => $returns) : ()),
		};

		push @subs_definition, {
			blueprint => "PascalPerl${type}Definition",
			class_name => $wrapper_class_name,
			name => snake_to_pascal($method),
			args => {
				blueprint => 'joined',
				separator => '; ',
				values => [map { "Arg$_: $args->[$_]" } 0 .. $#$args],
			},
			($returns ? (result => $returns) : ()),
			perl_name => $method,
			perl_args => {
				blueprint => 'joined',
				separator => ', ',
				values => [map { MAPPINGS_PASCAL->{$args->[$_]} . "(Arg$_)" } 0 .. $#$args],
			},
			($returns ? (perl_result => MAPPINGS_PERL->{$returns}) : ()),
		};
	}

	push @{$result->{unit}{type}{values}}, {
		blueprint => 'PascalPerlClassDeclaration',
		class_name => $wrapper_class_name,
		constructor_args => {
			blueprint => 'joined',
			separator => '; ',
			values => [map { "Arg$_: $constructor_args->[$_]" } 0 .. $#$constructor_args],
		},
		subs => {
			blueprint => 'joined',
			separator => '',
			values => \@subs_declaration,
		},
	};

	push @{$result->{unit}{implementation}{values}}, {
		blueprint => 'PascalPerlClassDefinition',
		class_name => $wrapper_class_name,
		class_name_perl => $class_name,
		constructor_args => {
			blueprint => 'joined',
			separator => '; ',
			values => [map { "Arg$_: $constructor_args->[$_]" } 0 .. $#$constructor_args],
		},
		constructor_args_perl => {
			blueprint => 'joined',
			separator => ', ',
			values => [map { MAPPINGS_PASCAL->{$constructor_args->[$_]} . "(Arg$_)" } 0 .. $#$constructor_args],
		},
		subs => {
			blueprint => 'joined',
			separator => "\n",
			values => \@subs_definition,
		},
	};
}

sub run
{
	my (%args) = @_;
	my %conf = parse_config($args{filename});
	my $conf_section = delete $conf{config};
	my ($unit_name) = $conf_section->{pascal_unit} =~ m{(\w+)\.pas};

	my $result = {
		modules => {},
		unit => {
			blueprint => 'PascalUnit',
			unit_name => $unit_name,
			uses => {
				blueprint => 'joined',
				separator => ', ',
				prefix => ', ',
				values => [],
			},
			type => {
				blueprint => 'joined',
				separator => "\n",
				values => [],
			},
			implementation => {
				blueprint => 'joined',
				separator => "\n",
				values => [],
			},
			initialization => {
				blueprint => 'joined',
				separator => "\n",
				values => [],
			},
		}
	};

	foreach my $topic (sort keys %conf) {
		my ($lang, $class_name) = split m{/}, $topic;

		my %class_conf = %{$conf{$topic}};
		my %class_opts = map { $_ => delete $class_conf{$_} } grep { m{^_} } keys %class_conf;

		my $sub = do {
			no strict 'refs';
			*{"generate_" . lc $lang};
		};
		$sub->($result, $class_name, \%class_conf, \%class_opts);
	}

	foreach my $module (sort keys %{$result->{modules}}) {
		my $file_name = sprintf "%s/%s.pm", $conf_section->{perl_library}, $module;
		open my $fh, '>', $file_name;
		print {$fh} resolve_blueprint $result->{modules}{$module};
	}

	{
		open my $fh, '>', $conf_section->{pascal_unit};
		print {$fh} resolve_blueprint $result->{unit};
	}
}

run(filename => shift);
say 'done';

__DATA__

PascalUnit
	unit %%UNIT_NAME;

	{$mode objfpc}{$H+}{$J-}

	interface

	uses SysUtils, PerlEmbed, PerlObjectLayer
		%%USES;

	type
		TWrappedPerlObject = class(TPerlObject)
		protected
			function GetPerl(): TPerlHandle; override;
		end;

		TWrappedPascalObject = class(TPascalObject)
		protected
			function GetPerl(): TPerlHandle; override;
		end;

		%%TYPE

	var
		WrappersPerl: TPerlHandle;

	implementation

	procedure AssertArgsCount(Args: Array of TPerlSV; Count: Integer);
	begin
		if length(Args) <> Count then
			raise Exception.Create('bad number of arguments, expected ' + Count.ToString);
	end;

	function TWrappedPerlObject.GetPerl(): TPerlHandle;
	begin
		result := WrappersPerl;
	end;

	function TWrappedPascalObject.GetPerl(): TPerlHandle;
	begin
		result := WrappersPerl;
	end;

	%%IMPLEMENTATION

	initialization
		%%INITIALIZATION
	end.

PascalPerlClassDeclaration
	%%CLASS_NAME = class(TWrappedPerlObject)
	public
		constructor Create(%%CONSTRUCTOR_ARGS);
	public
		class function PerlClassName(): String; override;
	public
		%%SUBS
	end;

PascalPerlClassDefinition
	constructor %%CLASS_NAME.Create(%%CONSTRUCTOR_ARGS);
	begin
		inherited Create([%%CONSTRUCTOR_ARGS_PERL]);
	end;

	class function %%CLASS_NAME.PerlClassName(): String;
	begin
		result := '%%CLASS_NAME_PERL';
	end;

	%%SUBS

PascalPerlProcedureDeclaration
	procedure %%NAME(%%ARGS);

PascalPerlProcedureDefinition
	procedure %%CLASS_NAME.%%NAME(%%ARGS);
	begin
		Perl.CallMethod(
			Instance,
			'%%PERL_NAME',
			[%%PERL_ARGS]
		);
	end;

PascalPerlFunctionDeclaration
	function %%NAME(%%ARGS): %%RESULT;

PascalPerlFunctionDefinition
	function %%CLASS_NAME.%%NAME(%%ARGS): %%RESULT;
	begin
		result := %%PERL_RESULT(
			Perl.CallMethod(
				Instance,
				'%%PERL_NAME',
				[%%PERL_ARGS]
			)
		);
	end;

PerlPascalClassDeclaration
	%%CLASS_NAME = class(TWrappedPascalObject)
	strict private
		FInstance: %%CLASS;
	public
		constructor Create(AInstance: %%CLASS);
		constructor CreateFromPerl(Args: Array of TPerlSV); override;
		destructor Destroy; override;
	public
		function CallMethod(const AMethodName: String; Args: Array of TPerlSV): TPerlSV; override;
	public
		class function PerlClassName(): String; override;
	end;

PerlPascalClassDefinition
	constructor %%CLASS_NAME.Create(AInstance: %%CLASS);
	begin
		inherited Create();
		FInstance := AInstance;
	end;

	constructor %%CLASS_NAME.CreateFromPerl(Args: Array of TPerlSV);
	begin
		inherited;
		%%CREATE_CALL
	end;

	destructor %%CLASS_NAME.Destroy();
	begin
		if not ManageObject then
			FInstance.Free;
	end;

	function %%CLASS_NAME.CallMethod(const AMethodName: String; Args: Array of TPerlSV): TPerlSV;
	begin
		result := nil;

		case AMethodName of
			%%METHOD_SWITCH
			otherwise
				raise Exception.Create('No such method');
		end;
	end;

	class function %%CLASS_NAME.PerlClassName(): String;
	begin
		result := '%%CLASS';
	end;

PerlPascalConstructorCall
	AssertArgsCount(Args, %%PERL_ARGS_COUNT);
	FInstance := %%CLASS.%%CONSTRUCTOR_NAME(%%PERL_ARGS);

PerlPascalFunctionDefinition
	'%%PERL_NAME': begin
		AssertArgsCount(Args, %%PERL_ARGS_COUNT);
		result := %%PASCAL_RESULT(FInstance.%%PASCAL_NAME(%%PERL_ARGS));
		Perl.SnatchScalar;
	end;

PerlPascalProcedureDefinition
	'%%PERL_NAME': begin
		AssertArgsCount(Args, %%PERL_ARGS_COUNT);
		FInstance.%%PASCAL_NAME(%%PERL_ARGS);
	end;

PerlModule
	package %%MODULE_NAME;

	use strict;
	use warnings;

	use parent 'PascalObject';

	__PACKAGE__->setup_methods(qw(%%METHODS));

	1;

