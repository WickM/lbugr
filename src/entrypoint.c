#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>

extern void lbugr_R_init_embeddable(DllInfo *info);

static const R_CallMethodDef CallEntries[] = {
    {"lbugr_R_init_embeddable", (DL_FUNC) &lbugr_R_init_embeddable, 1},
    {NULL, NULL, 0}
};

void R_init_lbugr(DllInfo *info) {
    R_registerRoutines(info, NULL, CallEntries, NULL, NULL);
    R_useDynamicSymbols(info, FALSE);
}
