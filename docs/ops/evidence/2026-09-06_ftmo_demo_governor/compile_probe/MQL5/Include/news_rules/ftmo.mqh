#ifndef QM_NEWS_RULES_FTMO_MQH
#define QM_NEWS_RULES_FTMO_MQH

// FTMO blackout windows by impact level.
// Kept isolated so firm-rule tweaks are localized.
int QM_NewsFTMOBeforeMinutes(const string impact_upper)
  {
   if(impact_upper == "HIGH")
      return 5;
   if(impact_upper == "MEDIUM")
      return 3;
   if(impact_upper == "LOW")
      return 1;
   return 0;
  }

int QM_NewsFTMOAfterMinutes(const string impact_upper)
  {
   if(impact_upper == "HIGH")
      return 5;
   if(impact_upper == "MEDIUM")
      return 3;
   if(impact_upper == "LOW")
      return 1;
   return 0;
  }

#endif // QM_NEWS_RULES_FTMO_MQH
