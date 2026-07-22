#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

/* Pascal object handle - opaque pointer to Pascal side */
typedef void* PascalObjectHandle;

EXTERN_C SV* bless_pointer(const char *class_name, void *handle);

/* External functions implemented in Pascal */
extern PascalObjectHandle pascal_object_new(const char *class_name, SV **args, int arg_count);
extern void pascal_object_destroy(PascalObjectHandle handle);
extern SV* pascal_object_call_method(PascalObjectHandle handle, const char *method_name, SV **args, int arg_count);
extern char* pascal_last_error();

MODULE = PascalObject		PACKAGE = PascalObject

PROTOTYPES: ENABLE

SV*
new(class_name, ...)
	const char *class_name
	PREINIT:
		PascalObjectHandle handle;
		SV **args;
		int arg_count;
	CODE:
		/* Collect arguments (skip class_name which is items[0]) */
		arg_count = items - 1;
		args = &ST(1);

		/* Call Pascal constructor */
		handle = pascal_object_new(class_name, args, arg_count);

		if (handle == NULL) {
			croak("Failed to create Pascal object of class %s: %s", class_name, pascal_last_error());
		}

		RETVAL = bless_pointer(class_name, handle);
	OUTPUT:
		RETVAL

SV*
_call_method(obj_ref, method_name, ...)
	SV *obj_ref
	const char *method_name
	PREINIT:
		PascalObjectHandle handle;
		SV *obj;
		SV **args;
		int arg_count;
		SV *result;
	CODE:
		if (!SvROK(obj_ref)) {
			croak("Not a reference");
		}

		obj = SvRV(obj_ref);
		handle = INT2PTR(PascalObjectHandle, SvIV(obj));

		/* Collect method arguments (skip obj_ref and method_name) */
		arg_count = items - 2;
		args = (arg_count > 0) ? &ST(2) : NULL;

		/* Call Pascal method */
		result = pascal_object_call_method(handle, method_name, args, arg_count);
		char *error = pascal_last_error();

		if (strlen(error) > 0) {
			croak("Failed to call pascal method %s: %s", method_name, error);
		}

		if (result == NULL) {
			result = &PL_sv_undef;
		}

		RETVAL = result;
	OUTPUT:
		RETVAL

void
DESTROY(obj_ref)
	SV *obj_ref
	PREINIT:
		PascalObjectHandle handle;
		SV *obj;
	CODE:
		if (!SvROK(obj_ref)) {
			return;
		}

		obj = SvRV(obj_ref);
		handle = INT2PTR(PascalObjectHandle, SvIV(obj));

		if (handle != NULL) {
			pascal_object_destroy(handle);
			char *error = pascal_last_error();

			if (strlen(error) > 0) {
				warn("Failed to destroy pascal object: %s", error);
			}
		}

