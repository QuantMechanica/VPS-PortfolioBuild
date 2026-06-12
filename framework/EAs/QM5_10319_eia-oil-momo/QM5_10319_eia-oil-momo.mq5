#property strict
#property version   "5.0"
#property description "QM5_10319 EIA Oil Announcement Intraday Momentum"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10319;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_atr_period              = 14;
input double strategy_atr_sl_mult             = 0.80;
input double strategy_daily_range_atr_mult    = 2.50;
input double strategy_spread_median_mult      = 1.50;
input int    strategy_spread_lookback_eia_days = 20;
input int    strategy_history_days             = 90;
input int    strategy_eia_day_of_week          = 3;     // Sunday=0, Wednesday=3.
input int    strategy_release_hour_broker      = 17;
input int    strategy_release_minute_broker    = 30;
input int    strategy_final_entry_hour_broker  = 21;
input int    strategy_final_entry_minute_broker = 0;
input int    strategy_final_close_hour_broker  = 21;
input int    strategy_final_close_minute_broker = 30;

int Hhmm(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.hour * 100 + dt.min);
  }

int DateKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.year * 10000 + dt.mon * 100 + dt.day);
  }

datetime DayStart(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

int DayOfWeekForDate(const int year, const int month, const int day)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   dt.year = year;
   dt.mon = month;
   dt.day = day;
   datetime t = StructToTime(dt);
   TimeToStruct(t, dt);
   return dt.day_of_week;
  }

int NthWeekdayOfMonth(const int year, const int month, const int weekday, const int nth)
  {
   int seen = 0;
   for(int d = 1; d <= 31; ++d)
     {
      MqlDateTime probe;
      ZeroMemory(probe);
      probe.year = year;
      probe.mon = month;
      probe.day = d;
      datetime t = StructToTime(probe);
      TimeToStruct(t, probe);
      if(probe.mon != month)
         break;
      if(probe.day_of_week == weekday)
        {
         seen++;
         if(seen == nth)
            return d;
        }
     }
   return 0;
  }

int LastWeekdayOfMonth(const int year, const int month, const int weekday)
  {
   int last = 0;
   for(int d = 1; d <= 31; ++d)
     {
      MqlDateTime probe;
      ZeroMemory(probe);
      probe.year = year;
      probe.mon = month;
      probe.day = d;
      datetime t = StructToTime(probe);
      TimeToStruct(t, probe);
      if(probe.mon != month)
         break;
      if(probe.day_of_week == weekday)
         last = d;
     }
   return last;
  }

bool IsUsFederalHoliday(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);

   if((dt.mon == 1 && dt.day == 1) ||
      (dt.mon == 6 && dt.day == 19) ||
      (dt.mon == 7 && dt.day == 4) ||
      (dt.mon == 11 && dt.day == 11) ||
      (dt.mon == 12 && dt.day == 25))
      return true;

   if(dt.mon == 1 && dt.day == NthWeekdayOfMonth(dt.year, 1, 1, 3))
      return true;
   if(dt.mon == 2 && dt.day == NthWeekdayOfMonth(dt.year, 2, 1, 3))
      return true;
   if(dt.mon == 5 && dt.day == LastWeekdayOfMonth(dt.year, 5, 1))
      return true;
   if(dt.mon == 9 && dt.day == NthWeekdayOfMonth(dt.year, 9, 1, 1))
      return true;
   if(dt.mon == 10 && dt.day == NthWeekdayOfMonth(dt.year, 10, 1, 2))
      return true;
   if(dt.mon == 11 && dt.day == NthWeekdayOfMonth(dt.year, 11, 4, 4))
      return true;

   return false;
  }

bool IsScheduledEiaDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   if(dt.day_of_week != strategy_eia_day_of_week)
      return false;
   if(IsUsFederalHoliday(t))
      return false;
   return true;
  }

bool IsConfiguredMinute(const datetime t, const int hour, const int minute)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.hour == hour && dt.min == minute);
  }

bool IsAtOrAfterTodayTime(const datetime t, const int hour, const int minute)
  {
   return (Hhmm(t) >= (hour * 100 + minute));
  }

bool FindTodayBar(const MqlRates &rates[], const int count, const int hour, const int minute, MqlRates &out_bar)
  {
   for(int i = 0; i < count; ++i)
     {
      if(IsConfiguredMinute(rates[i].time, hour, minute))
        {
         out_bar = rates[i];
         return true;
        }
     }
   return false;
  }

bool TodayRangeBeforeEntry(const MqlRates &rates[], const int count, const datetime entry_time, double &out_range)
  {
   out_range = 0.0;
   double hi = -DBL_MAX;
   double lo = DBL_MAX;
   bool have_bar = false;

   for(int i = 0; i < count; ++i)
     {
      if(rates[i].time >= entry_time)
         continue;
      if(rates[i].high <= 0.0 || rates[i].low <= 0.0 || rates[i].high < rates[i].low)
         continue;
      hi = MathMax(hi, rates[i].high);
      lo = MathMin(lo, rates[i].low);
      have_bar = true;
     }

   if(!have_bar || hi <= lo)
      return false;

   out_range = hi - lo;
   return true;
  }

bool HistoricalEiaSpreadMedian(double &out_median)
  {
   out_median = 0.0;
   const int lookback_days = MathMax(strategy_history_days, strategy_spread_lookback_eia_days * 7 + 14);
   const datetime end_t = TimeCurrent();
   const datetime start_t = end_t - (datetime)(lookback_days * 86400);

   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   const int copied = CopyRates(_Symbol, PERIOD_M30, start_t, end_t, rates); // perf-allowed: bounded EIA-day spread sample, called only on the closed final-entry bar.
   if(copied <= 0)
      return false;

   double samples[];
   ArrayResize(samples, 0);
   const int today_key = DateKey(end_t);

   for(int i = copied - 1; i >= 0; --i)
     {
      if(ArraySize(samples) >= strategy_spread_lookback_eia_days)
         break;
      if(DateKey(rates[i].time) >= today_key)
         continue;
      if(!IsScheduledEiaDay(rates[i].time))
         continue;
      if(!IsConfiguredMinute(rates[i].time, strategy_final_entry_hour_broker, strategy_final_entry_minute_broker))
         continue;
      if(rates[i].spread <= 0)
         continue;

      const int n = ArraySize(samples);
      ArrayResize(samples, n + 1);
      samples[n] = (double)rates[i].spread;
     }

   const int n = ArraySize(samples);
   if(n <= 0)
      return false;

   ArraySort(samples);
   if((n % 2) == 1)
      out_median = samples[n / 2];
   else
      out_median = 0.5 * (samples[n / 2 - 1] + samples[n / 2]);

   return (out_median > 0.0);
  }

bool Strategy_NoTradeFilter()
  {
   // No Trade Filter: timeframe guard; event-day/time/spread filters live in EntrySignal.
   if((ENUM_TIMEFRAMES)_Period != PERIOD_M30)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const datetime broker_now = TimeCurrent();
   if(!IsScheduledEiaDay(broker_now))
      return false;
   if(!IsConfiguredMinute(broker_now, strategy_final_entry_hour_broker, strategy_final_entry_minute_broker))
      return false;

   const datetime day_start = DayStart(broker_now);
   MqlRates today_rates[];
   ArraySetAsSeries(today_rates, false);
   const int today_count = CopyRates(_Symbol, PERIOD_M30, day_start, broker_now, today_rates); // perf-allowed: one closed-bar cache for event-window OHLC.
   if(today_count <= 0)
      return false;

   MqlRates release_bar;
   if(!FindTodayBar(today_rates, today_count, strategy_release_hour_broker, strategy_release_minute_broker, release_bar))
      return false;
   if(release_bar.open <= 0.0 || release_bar.close <= 0.0)
      return false;

   double pre_entry_range = 0.0;
   if(!TodayRangeBeforeEntry(today_rates, today_count, broker_now, pre_entry_range))
      return false;

   const double daily_atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(daily_atr <= 0.0 || pre_entry_range >= strategy_daily_range_atr_mult * daily_atr)
      return false;

   double median_spread = 0.0;
   if(!HistoricalEiaSpreadMedian(median_spread))
      return false;
   const double current_spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0.0 || current_spread >= strategy_spread_median_mult * median_spread)
      return false;

   const double r_eia30 = (release_bar.close / release_bar.open) - 1.0;
   if(r_eia30 == 0.0)
      return false;

   req.type = (r_eia30 > 0.0) ? QM_BUY : QM_SELL;
   const double entry_price = (req.type == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                                   : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_price <= 0.0)
      return false;

   const double atr_m30 = QM_ATR(_Symbol, PERIOD_M30, strategy_atr_period, 1);
   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry_price, atr_m30, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.tp = 0.0;
   req.reason = (req.type == QM_BUY) ? "EIA30_POS_FINAL_LONG" : "EIA30_NEG_FINAL_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Trade Management: card specifies one position, no scaling, no trailing, no partials.
  }

bool Strategy_ExitSignal()
  {
   // Trade Close: close at the end of the final 30-minute window; no overnight holding.
   const datetime broker_now = TimeCurrent();
   if(!IsScheduledEiaDay(broker_now))
      return false;
   return IsAtOrAfterTodayTime(broker_now, strategy_final_close_hour_broker, strategy_final_close_minute_broker);
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // News Filter Hook: the strategy trades only the deterministic EIA proxy encoded above.
   return false;
  }

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10319\",\"ea\":\"QM5_10319_eia_oil_momo\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
     }
  }

void OnTimer()
  {
   QM_FrameworkOnTimer();
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
