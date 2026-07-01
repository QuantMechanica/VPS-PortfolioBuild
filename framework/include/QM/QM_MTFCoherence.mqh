#ifndef QM_MTF_COHERENCE_MQH
#define QM_MTF_COHERENCE_MQH

#include "QM_CurrencyStrength.mqh"

struct QM_MTFCoherenceState
  {
   int currency_idx;
   int d1_sign;
   int w1_sign;
   int mn_sign;
   bool coherent;
  };

void QM_MTFCoherence_Reset(QM_MTFCoherenceState &state)
  {
   state.currency_idx = -1;
   state.d1_sign = 0;
   state.w1_sign = 0;
   state.mn_sign = 0;
   state.coherent = false;
  }

bool QM_MTFCoherence_Evaluate(const QM_CSMReading &d1,
                              const QM_CSMReading &w1,
                              const QM_CSMReading &mn,
                              const int currency_idx,
                              QM_MTFCoherenceState &state)
  {
   QM_MTFCoherence_Reset(state);
   if(currency_idx < 0 || currency_idx >= QM_CSM_CURRENCY_COUNT)
      return false;

   state.currency_idx = currency_idx;
   state.d1_sign = QM_CSM_Sign(d1.strength[currency_idx]);
   state.w1_sign = QM_CSM_Sign(w1.strength[currency_idx]);
   state.mn_sign = QM_CSM_Sign(mn.strength[currency_idx]);
   state.coherent = (state.d1_sign != 0 &&
                     state.d1_sign == state.w1_sign &&
                     state.d1_sign == state.mn_sign);
   return state.coherent;
  }

bool QM_MTFCoherence_Load(const int currency_idx,
                          QM_CSMReading &d1,
                          QM_CSMReading &w1,
                          QM_CSMReading &mn,
                          QM_MTFCoherenceState &state)
  {
   if(!QM_CSM_LoadStrength(PERIOD_D1, d1, 0))
      return false;
   if(!QM_CSM_LoadStrength(PERIOD_W1, w1, 0))
      return false;
   if(!QM_CSM_LoadStrength(PERIOD_MN1, mn, 0))
      return false;
   return QM_MTFCoherence_Evaluate(d1, w1, mn, currency_idx, state);
  }

#endif // QM_MTF_COHERENCE_MQH
