#ifndef QM_TWIN_WARMUP_GUARD_MQH
#define QM_TWIN_WARMUP_GUARD_MQH

#define QM_TWIN_SECONDS_PER_DAY 86400
#define QM_TWIN_MTF_WARMUP_W1_PERIODS 4
#define QM_TWIN_MTF_WARMUP_MN_DAYS 31

datetime QM_TWIN_MtfWarmupReadyTime(const datetime first_bar_time)
  {
   if(first_bar_time <= 0)
      return 0;
   const datetime w1_ready = first_bar_time +
                             (datetime)(QM_TWIN_MTF_WARMUP_W1_PERIODS * 7 *
                                        QM_TWIN_SECONDS_PER_DAY);
   const datetime mn_ready = first_bar_time +
                             (datetime)(QM_TWIN_MTF_WARMUP_MN_DAYS *
                                        QM_TWIN_SECONDS_PER_DAY);
   return (mn_ready > w1_ready) ? mn_ready : w1_ready;
  }

bool QM_TWIN_MtfWarmupReady(const datetime first_bar_time,
                            const datetime broker_time)
  {
   if(first_bar_time <= 0 || broker_time <= 0)
      return false;
   return broker_time >= QM_TWIN_MtfWarmupReadyTime(first_bar_time);
  }

#endif // QM_TWIN_WARMUP_GUARD_MQH
