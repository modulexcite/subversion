/*
 * svn_types.i :  SWIG interface file for svn_types.h
 *
 * ====================================================================
 * Copyright (c) 2000-2003 CollabNet.  All rights reserved.
 *
 * This software is licensed as described in the file COPYING, which
 * you should have received as part of this distribution.  The terms
 * are also available at http://subversion.tigris.org/license-1.html.
 * If newer versions of this license are posted there, you may use a
 * newer version instead, at your option.
 *
 * This software consists of voluntary contributions made by many
 * individuals.  For exact contribution history, see the revision
 * history and logs, available at http://subversion.tigris.org/.
 * ====================================================================
 */

/* This interface file only defines types and their related information.
   There is no module associated with this interface file. */

%import apr.i

/* -----------------------------------------------------------------------
   Create a typemap to define "type **" as OUT parameters.

   Note: SWIGTYPE is just a placeholder for "some arbitrary type". This
         typemap will be applied onto a "real" type.
*/
%typemap(python, in, numinputs=0) SWIGTYPE **OUTPARAM ($*1_type temp) {
    $1 = ($1_ltype)&temp;
}
%typemap(perl5, in, numinputs=0) SWIGTYPE **OUTPARAM ($*1_type temp) {
    $1 = ($1_ltype)&temp;
}
%typemap(ruby, in, numinputs=0) SWIGTYPE **OUTPARAM ($*1_type temp) {
  temp = NULL;
  $1 = ($1_ltype)&temp;
}

%typemap(python, argout, fragment="t_output_helper") SWIGTYPE **OUTPARAM {
    $result = t_output_helper($result,
                              SWIG_NewPointerObj(*$1, $*1_descriptor, 0));
}
%typemap(perl5, argout) SWIGTYPE **OUTPARAM {
    ST(argvi) = sv_newmortal();
    SWIG_MakePtr(ST(argvi++), (void *)*$1, $*1_descriptor,0);
}
%typemap(ruby, argout, fragment="output_helper") SWIGTYPE **OUTPARAM {
  $result = output_helper($result, SWIG_NewPointerObj(*$1, $*1_descriptor, 0));
}

/* -----------------------------------------------------------------------
   %apply-ing of typemaps
*/

%apply SWIGTYPE **OUTPARAM { svn_stream_t ** };

%apply long *OUTPUT { svn_revnum_t * };
%apply int *OUTPUT { svn_boolean_t * };

/* svn_fs_check_path() */
%apply long *OUTPUT { svn_node_kind_t * };

/* -----------------------------------------------------------------------
   Create a typemap for specifying string args that may be NULL.
*/
%typemap(python, in, parse="z") const char *MAY_BE_NULL "";

#ifdef SWIGPERL
%apply const char * { const char *MAY_BE_NULL };
#endif

%typemap(ruby, in) const char* MAY_BE_NULL
{
  if (NIL_P($input)) {
    $1 = NULL;
  } else {
    $1 = StringValuePtr($input);
  }
}

%typemap(ruby, out) const char *
{
  if ($1) {
    $result = rb_str_new2($1);
  } else {
    $result = Qnil;
  }
}

/* -----------------------------------------------------------------------
   Define a more refined 'memberin' typemap for 'const char *' members. This
   is used in place of the 'char *' handler defined automatically.

   We need to do the free/malloc/strcpy special because of the const
*/
%typemap(memberin) const char * {
    apr_size_t len = strlen($input) + 1;
    char *copied;
    if ($1) free((char *)$1);
    copied = malloc(len);
    memcpy(copied, $input, len);
    $1 = copied;
}

/* -----------------------------------------------------------------------
   Specify how svn_error_t returns are turned into exceptions.
*/
%typemap(python, out) svn_error_t * {
    if ($1 != NULL) {
        if ($1->apr_err != SVN_ERR_SWIG_PY_EXCEPTION_SET)
            svn_swig_py_svn_exception($1);
        else
            svn_error_clear($1);
        return NULL;
    }
    Py_INCREF(Py_None);
    $result = Py_None;
}

%typemap(perl5,out) svn_error_t * {
    if ($1) {
        SV *exception_handler = perl_get_sv ("SVN::Error::handler", FALSE);

        if (SvOK(exception_handler)) {
            SV *callback_result;

            svn_swig_pl_callback_thunk (CALL_SV, exception_handler,
                                        &callback_result, "S", $1,
                                        $1_descriptor);
        } else {
            $result = sv_newmortal();
            SWIG_MakePtr ($result, (void *)$1, $1_descriptor ,0);
            argvi++;
        }
    }
}

%typemap(ruby, out) svn_error_t *
{
  if ($1) {
    svn_error_t *error = $1;
    apr_status_t error_code = error->apr_err;
    VALUE message;

    message = rb_str_new2(error->message ? error->message : "");
    
    while (error->child) {
      error = error->child;
      if (error->message) {
        rb_str_concat(message, rb_str_new2("\n"));
        rb_str_concat(message, rb_str_new2(error->message));
      }
    }
    svn_error_clear(error);
    
    rb_exc_raise(svn_swig_rb_svn_error_new(INT2NUM(error_code),
                                           message));
  }
  $result = Qnil;
}

/* -----------------------------------------------------------------------
   Define an OUTPUT typemap for 'svn_filesize_t *'.  For now, we'll
   treat it as a 'long' even if that isn't entirely correct...  
*/
%typemap(python,in,numinputs=0) svn_filesize_t * (svn_filesize_t temp)
    "$1 = &temp;";

%typemap(perl5,in,numinputs=0) svn_filesize_t * (svn_filesize_t temp)
    "$1 = &temp;";

%typemap(ruby,in,numinputs=0) svn_filesize_t * (svn_filesize_t temp)
    "$1 = &temp;";

/* We have to use APR_INT64_T_FMT because SWIG won't convert the
   SVN_FILESIZE_T_FMT to the actual value only APR_INT64_T_FMT */
#if APR_INT64_T_FMT == "ld"

%typemap(python,argout,fragment="t_output_helper") svn_filesize_t *
    "$result = t_output_helper($result,PyLong_FromLong((long) (*$1)));";

%apply long *OUTPUT { svn_filesize_t * };

#else

%typemap(python,argout,fragment="t_output_helper") svn_filesize_t *
    "$result = t_output_helper($result,
                               PyLong_FromLongLong((apr_int64_t) (*$1)));";

/* XXX: apply long long *OUTPUT doesn't track $1 correctly */
%typemap(perl5,argout) svn_filesize_t * {
    char temp[256];
    sprintf(temp,"%lld", *$1);
    ST(argvi) = sv_newmortal();
    sv_setpv((SV*)ST(argvi++), temp);
};

%typemap(ruby,argout,fragment="output_helper") svn_filesize_t *
    "$result = output_helper($result, LL2NUM((apr_int64_t) (*$1)));";
#endif 

/* -----------------------------------------------------------------------
   Define a general ptr/len typemap. This takes a single script argument
   and expands it into a ptr/len pair for the native call.
*/
%typemap(python, in) (const char *PTR, apr_size_t LEN) {
    if (!PyString_Check($input)) {
        PyErr_SetString(PyExc_TypeError, "expecting a string");
        return NULL;
    }
    $1 = PyString_AS_STRING($input);
    $2 = PyString_GET_SIZE($input);
}

%typemap(perl5, in) (const char *PTR, apr_size_t LEN) {
    if (SvPOK($input)) {
        $1 = SvPV($input, $2);
    } else {
        /* set to 0 to avoid warning */
        $1 = 0;
        $2 = 0;
        SWIG_croak("Expecting a string");
    }
}

/* -----------------------------------------------------------------------
   Handle retrieving the error message from svn_strerror
*/

%typemap(perl5,in,numinputs=0) (char *buf, apr_size_t bufsize) ( char temp[128] ) {
    memset (temp,0,128); /* paranoia */
    $1 = temp;
    $2 = 128;
}

/* -----------------------------------------------------------------------
   Define a generic arginit mapping for pools.
*/

%typemap(python, arginit) apr_pool_t *pool(apr_pool_t *_global_pool) {
    /* Assume that the pool here is the last argument in the list */
    SWIG_ConvertPtr(PyTuple_GET_ITEM(args, PyTuple_GET_SIZE(args) - 1),
                    (void **)&$1, $1_descriptor, SWIG_POINTER_EXCEPTION | 0);
    _global_pool = $1;
}

%typemap(perl5, in) apr_pool_t *pool "";
%typemap(perl5, default) apr_pool_t *pool(apr_pool_t *_global_pool) {
    _global_pool = $1 = svn_swig_pl_make_pool (ST(items-1));
}
%typemap(ruby, arginit) apr_pool_t *pool (apr_pool_t *_global_pool) {
  if (argc == 0) {
    /* wrong # of arguments: we need at least a pool. */
  } else if (argc <= $argnum) {
    if (NIL_P(argv[argc - 1])) {
      rb_raise(rb_eArgError, "pool must be not nil");
    }
    /* Assume that the pool here is the last argument in the list */
    SWIG_ConvertPtr(argv[argc - 1], (void **)&$1, $1_descriptor, 1);
    _global_pool = $1;
  }
}

#ifdef SWIGPERL
%apply apr_pool_t *pool {
    apr_pool_t *dir_pool,
    apr_pool_t *file_pool,
    apr_pool_t *node_pool
};
#endif

/* -----------------------------------------------------------------------
   Callback: svn_log_message_receiver_t
   svn_client_log()
   svn_ra get_log()
   svn_repos_get_logs()
*/

%typemap(python, in) (svn_log_message_receiver_t receiver, 
                      void *receiver_baton) {
    $1 = svn_swig_py_log_receiver;
    $2 = (void *)$input;
}
%typemap(perl5, in) (svn_log_message_receiver_t receiver, 
                     void *receiver_baton) {
    $1 = svn_swig_pl_thunk_log_receiver;
    $2 = (void *)$input;
}

%typemap(ruby, in) (svn_log_message_receiver_t receiver, 
                    void *receiver_baton) {
    $1 = svn_swig_rb_log_receiver;
    $2 = (void *)$input;
}

/* -----------------------------------------------------------------------
   Callback: svn_commit_callback_t
   svn_ra get_commit_editor()
   svn_repos_get_commit_editor()
*/

%typemap(perl5, in) (svn_commit_callback_t callback, void *callback_baton) {
    $1 = svn_swig_pl_thunk_commit_callback;
    $2 = (void *)$input;
    svn_swig_pl_hold_ref_in_pool (_global_pool, $input);
};

/* -----------------------------------------------------------------------
   Callback: svn_cancel_func_t
*/

%typemap(python, in) (svn_cancel_func_t cancel_func, void *cancel_baton) {
  $1 = svn_swig_py_cancel_func;
  $2 = $input; /* our function is the baton. */
}

/* -----------------------------------------------------------------------
   svn_stream_t interoperability with language native io handles
*/

%typemap(python, in) svn_stream_t *WRAPPED_STREAM {
    $1 = svn_swig_py_make_stream ($input, _global_pool);
}

%typemap(perl5, in) svn_stream_t * {
    svn_swig_pl_make_stream (&$1, $input);
}

%typemap(perl5, out) svn_stream_t * {
    $result = svn_swig_pl_from_stream ($1);
    argvi++;
}

%typemap(perl5, argout) svn_stream_t ** {
    $result = svn_swig_pl_from_stream (*$1);
    argvi++;
}

%typemap(ruby, in) svn_stream_t * {
    $1 = svn_swig_rb_make_stream($input, _global_pool);
}

/* -----------------------------------------------------------------------
   Wrap the digest output for functions populating digests.
*/

%typemap(in, numinputs=0) unsigned char digest[ANY]
    ($*1_type temp[APR_MD5_DIGESTSIZE]) {
    $1 = ($1_ltype)temp;
}

%typemap(python, argout, fragment="t_output_helper") unsigned char digest[ANY]
{
    $result = t_output_helper($result,
        PyString_FromString(svn_md5_digest_to_cstring ($1, _global_pool)));
}

%typemap(perl5, argout) unsigned char digest[ANY] {
    ST(argvi) = sv_newmortal();
    sv_setpv((SV*)ST(argvi++), svn_md5_digest_to_cstring ($1,_global_pool));
}

/* svn_txdelta_send_stream() uses *digest not digest[] . */
%apply unsigned char digest[ANY] { unsigned char *digest };

/* -----------------------------------------------------------------------
  useful convertors for svn_opt_revision_t
*/
%typemap(perl5, in) svn_opt_revision_t * (svn_opt_revision_t rev) {
    $1 = &rev;
    if ($input == NULL || $input == &PL_sv_undef || !SvOK($input)) {
        rev.kind = svn_opt_revision_unspecified;
    }
    else if (sv_isobject($input) && sv_derived_from($input, "_p_svn_opt_revision_t")) {
        SWIG_ConvertPtr($input, (void **)&$1, $1_descriptor, 0);
    }
    else if (looks_like_number($input)) {
        rev.kind = svn_opt_revision_number;
        rev.value.number = SvIV($input);
    }
    else if (SvPOK($input)) {
        char *input = SvPV_nolen($input);
        if (strcasecmp(input, "BASE") == 0)
            rev.kind = svn_opt_revision_base;
        else if (strcasecmp(input, "HEAD") == 0)
            rev.kind = svn_opt_revision_head;
        else if (strcasecmp(input, "WORKING") == 0)
            rev.kind = svn_opt_revision_working;
        else if (strcasecmp(input, "COMMITTED") == 0)
            rev.kind = svn_opt_revision_committed;
        else if (strcasecmp(input, "PREV") == 0)
            rev.kind = svn_opt_revision_previous;
        else if (*input == '{') {
            svn_boolean_t matched;
            apr_time_t tm;
            svn_error_t *err;

            char *end = strchr(input,'}');
            if (!end)
                SWIG_croak("unknown opt_revision_t type");
            *end = '\0';
            err = svn_parse_date (&matched, &tm, input + 1, apr_time_now(),
                                  svn_swig_pl_make_pool ((SV *)NULL));
            if (err) {
                svn_error_clear (err);
                SWIG_croak("unknown opt_revision_t type");
            }
            if (!matched)
                SWIG_croak("unknown opt_revision_t type");

            rev.kind = svn_opt_revision_date;
            rev.value.date = tm;
        } else
            SWIG_croak("unknown opt_revison_t type");
    } else
        SWIG_croak("unknown opt_revision_t type");
}

%typemap(ruby, in) svn_opt_revision_t * (svn_opt_revision_t rev) {
  $1 = &rev;
  svn_swig_rb_set_revision(&rev, $input);
}

/* -----------------------------------------------------------------------
   apr_hash_t **dirents
   svn_client_ls()
   svn_io_get_dirents()
   svn_ra get_dir()
*/

%typemap(python,in,numinputs=0) apr_hash_t **dirents = apr_hash_t **OUTPUT;
%typemap(python,argout,fragment="t_output_helper") apr_hash_t **dirents {
    $result = t_output_helper
	($result,
	 svn_swig_py_convert_hash(*$1, SWIG_TypeQuery("svn_dirent_t *")));
}

%typemap(perl5,in,numinputs=0) apr_hash_t **dirents = apr_hash_t **OUTPUT;
%typemap(perl5,argout) apr_hash_t **dirents {
    ST(argvi++) = svn_swig_pl_convert_hash
	(*$1, SWIG_TypeQuery("svn_dirent_t *"));
}

/* -----------------------------------------------------------------------
   Special boolean mapping for ruby.
*/

%typemap(ruby, in) svn_boolean_t "$1 = RTEST($input);";
%typemap(ruby, out) svn_boolean_t "$result = $1 ? Qtrue : Qfalse;";

%typemap(ruby, in, numinputs=0) svn_boolean_t * (svn_boolean_t temp)
{
  $1 = &temp;
}

%typemap(ruby, argout) svn_boolean_t *
{
  $result = *$1 ? Qtrue : Qfalse;
}

/* -----------------------------------------------------------------------
   Handle python thread locking.

   Swig doesn't allow us to specify a language in the %exception command,
   so we have to use #ifdefs for the python-specific parts.
*/

%exception {
#ifdef SWIGPYTHON
    svn_swig_py_release_py_lock();
#endif
    $action
#ifdef SWIGPYTHON
    svn_swig_py_acquire_py_lock();
#endif
}


/* -----------------------------------------------------------------------
   handle config and fs_config in svn_{fs,repos}_create
*/


%typemap(ruby, in) apr_hash_t *config (apr_hash_t *temp)
{
  if (NIL_P($input)) {
    $1 = NULL;
  } else {
    $1 = svn_swig_rb_hash_to_apr_hash_swig_type($input, "svn_config_t *", _global_pool);
  }
}
%typemap(ruby, in) apr_hash_t *fs_config
{
  if (NIL_P($input)) {
    $1 = NULL;
  } else {
    $1 = svn_swig_rb_hash_to_apr_hash_string($input, _global_pool);
  }
}

/* -----------------------------------------------------------------------
   remove destructor for apr_pool and Ruby's GC.
*/
#ifdef SWIGRUBY
#define REMOVE_DESTRUCTOR(type)                 \
%extend type                                    \
{                                               \
  ~type(type *obj)                              \
    {                                           \
      /* do nothing */                          \
    }                                           \
}
#endif

/* ----------------------------------------------------------------------- */

%{
#include "svn_types.h"
#include "svn_time.h"

#ifdef SWIGPYTHON
#include "swigutil_py.h"
#endif

#ifdef SWIGPERL
#include "swigutil_pl.h"
#endif

#ifdef SWIGRUBY
#include "swigutil_rb.h"
#endif
%}

%include svn_types.h
