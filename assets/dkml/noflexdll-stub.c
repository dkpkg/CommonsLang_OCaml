/* FlexDLL runtime for the DkMLStatic toolchain.

   The DkMLStatic Windows build copies this file over flexdll/flexdll.c before
   OCaml builds FlexDLL. The installed bin/flexdll_msvc.obj (x86) or
   bin/flexdll_msvc64.obj (x64) holds these definitions, and flexlink links
   that object into every executable. An executable built by DkMLStatic
   carries no FlexDLL loader and links only the static C runtime.

   Every loader entry point fails. flexdll_dlerror names the reason, and the
   OCaml runtime prints it when Dynlink, a bytecode executable or the toplevel
   asks for a shared library:

     dynamic loading is not available in this executable

   The prototypes are those of flexdll.h (FlexDLL 0.43). */

#include <stddef.h>
#include <wchar.h>
#include "flexdll.h"

static char dkml_noflexdll_error[] =
  "dynamic loading is not available in this executable";

void *flexdll_dlopen(const char *file, int mode)
{
  (void)file;
  (void)mode;
  return NULL;
}

void *flexdll_wdlopen(const wchar_t *file, int mode)
{
  (void)file;
  (void)mode;
  return NULL;
}

void *flexdll_dlsym(void *handle, const char *name)
{
  (void)handle;
  (void)name;
  return NULL;
}

void flexdll_dlclose(void *handle)
{
  (void)handle;
}

char *flexdll_dlerror(void)
{
  return dkml_noflexdll_error;
}

void flexdll_dump_exports(void *handle)
{
  (void)handle;
}

void flexdll_dump_relocations(void *handle)
{
  (void)handle;
}
