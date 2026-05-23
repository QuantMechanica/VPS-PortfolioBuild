#ifndef QM_FILTER_LIBRARY_MQH
#define QM_FILTER_LIBRARY_MQH

// QuantMechanica V5 core filter library.
//
// Include this umbrella from EAs that use first-class, thesis-declared filters.
// Each filter is deterministic, mechanical, and parameter-light. Filter on/off
// variants are declared before testing and run through the existing pipeline.

#include "QM_FilterNewsBlackout.mqh"
#include "QM_FilterRegime.mqh"
#include "QM_FilterVolatility.mqh"

#endif
