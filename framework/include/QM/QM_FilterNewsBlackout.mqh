#ifndef QM_FILTER_NEWS_BLACKOUT_MQH
#define QM_FILTER_NEWS_BLACKOUT_MQH

// QuantMechanica V5 filter module: news blackout.
//
// Purpose: reusable pre-entry gate for mandatory high-impact-news blackout
// windows. This formalizes the existing central QM_NewsFilter as a first-class
// filter module while keeping the single source of truth for calendar parsing
// and firm-specific blackout rules in QM_NewsFilter.mqh.
//
// Parameters:
//   mode: existing QM_NewsMode enum, normally QM_NEWS_FTMO_PAUSE for Edge Lab.

#include "QM_NewsFilter.mqh"

bool QM_FilterNewsBlackoutAllowsTrade(const string symbol,
                                      const datetime broker_time,
                                      const QM_NewsMode mode)
  {
   if(mode == QM_NEWS_OFF)
      return true;
   return QM_NewsAllowsTrade(symbol, broker_time, mode);
  }

bool QM_FilterNewsBlackoutBlocksTrade(const string symbol,
                                      const datetime broker_time,
                                      const QM_NewsMode mode)
  {
   return !QM_FilterNewsBlackoutAllowsTrade(symbol, broker_time, mode);
  }

#endif
