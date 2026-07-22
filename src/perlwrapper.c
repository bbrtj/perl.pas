#include <EXTERN.h>
#include <perl.h>

void setup_flags(int destruct_level)
{
	PL_exit_flags |= PERL_EXIT_DESTRUCT_END;
	PL_perl_destruct_level = destruct_level;
}

/* Simple wrapper to call a Perl subroutine with arguments */
SV* call_perl_sub(const char *sub_name, SV **args, int arg_count, int is_method)
{
	dSP;
	int count;
	SV *result = NULL;
	int i;

	ENTER;
	SAVETMPS;

	PUSHMARK(SP);
	EXTEND(SP, arg_count);
	for (i = 0; i < arg_count; i++) {
		PUSHs(args[i]);
	}
	PUTBACK;

	count = is_method ? call_method(sub_name, G_SCALAR | G_EVAL) : call_pv(sub_name, G_SCALAR | G_EVAL);

	SPAGAIN;

	if (count != 1) {
		croak("calling %s failed", sub_name);
	}

	result = POPs;
	SvREFCNT_inc(result);

	PUTBACK;
	FREETMPS;
	LEAVE;

	return result;
}

SV* bless_pointer(const char *class_name, void *handle)
{
	SV *obj = newSViv(PTR2IV(handle));
	SV *obj_ref = newRV_noinc(obj);
	HV *stash = gv_stashpv(class_name, GV_ADD);
	return sv_bless(obj_ref, stash);
}

/* Helpers to wrap Perl macros */

void do_PERL_SYS_INIT3(int argc, char **argv, char **env)
{
	PERL_SYS_INIT3(&argc, &argv, &env);
}

void do_PERL_SYS_TERM()
{
	PERL_SYS_TERM();
}

char* do_SvPV(SV *sv, STRLEN *len)
{
	return SvPV(sv, *len);
}

double do_SvNV(SV *sv)
{
	return SvNV(sv);
}

long do_SvIV(SV *sv)
{
	return SvIV(sv);
}

int do_SvOK(SV *sv)
{
	return SvOK(sv);
}

int do_SvTRUE(SV *sv)
{
	return SvTRUE(sv);
}

SV* do_ERRSV()
{
	return ERRSV;
}

void do_SVREFCNT_dec(SV *sv)
{
	SvREFCNT_dec(sv);
}

