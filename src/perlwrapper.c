#include <EXTERN.h>
#include <perl.h>

void xs_init(PerlInterpreter *my_perl)
{
}

/* Simple wrapper to call a Perl subroutine with arguments */
SV* call_perl_sub(const char *sub_name, SV **args, int arg_count)
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
        XPUSHs(sv_2mortal(args[i]));
    }
    PUTBACK;

    count = call_pv(sub_name, G_SCALAR | G_EVAL);

    SPAGAIN;

    if (count > 0) {
        result = newSVsv(POPs);
    }

    PUTBACK;
    FREETMPS;
    LEAVE;

    return result;
}

/* Helpers to wrap Perl macros */

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

