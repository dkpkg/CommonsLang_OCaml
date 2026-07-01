/* Stub for glp_write_lp.
 *
 * The vendored glpk in opam's mccs dependency omits wrmip.c (the LP/MIP file
 * writer), so this symbol is undefined. mccs references glp_write_lp only from
 * code paths that are commented out, but glpk_solver.obj still emits an external
 * reference to it, which the MSVC linker cannot resolve (on Unix the unused
 * reference is dropped). This file is copied into mccs's glpk api/ directory and
 * "wrmip" is enabled in src_ext/mccs/src/glpk/dune so the symbol is provided.
 * It is never actually called.
 */
int glp_write_lp(void *P, const void *parm, const char *fname);
int glp_write_lp(void *P, const void *parm, const char *fname)
{
  (void)P;
  (void)parm;
  (void)fname;
  return 1;
}
