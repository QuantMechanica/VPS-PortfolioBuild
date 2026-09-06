#ifndef QM_NEWS_RULES_5ERS_MQH
#define QM_NEWS_RULES_5ERS_MQH

// The5ers blackout windows by impact level.
// Kept isolated so firm-rule tweaks are localized.
int QM_News5ersBeforeMinutes(const string impact_upper)
  {
   if(impact_upper == "HIGH")
      return 2;
   if(impact_upper == "MEDIUM")
      return 1;
   return 0;
  }

int QM_News5ersAfterMinutes(const string impact_upper)
  {
   if(impact_upper == "HIGH")
      return 2;
   if(impact_upper == "MEDIUM")
      return 1;
   return 0;
  }

#endif // QM_NEWS_RULES_5ERS_MQH
