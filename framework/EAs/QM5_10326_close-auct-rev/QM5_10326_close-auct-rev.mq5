#property strict
#property version   "5.0"
#property description "QM5_10326 Closing Auction Pressure Reversal"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10326;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
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
input double strategy_pressure_atr_mult       = 0.75;
input double strategy_stop_atr_mult           = 0.75;
input double strategy_retrace_fraction        = 0.50;
input int    strategy_hold_bars               = 4;
input int    strategy_prior_bar_hhmm_broker   = 2230;
input int    strategy_final_bar_hhmm_broker   = 2245;
input int    strategy_volume_lookback_days    = 60;
input double strategy_volume_percentile       = 70.0;
input int    strategy_spread_lookback_bars    = 960;
input double strategy_spread_percentile       = 80.0;
input int    strategy_min_percentile_samples  = 20;
input bool   strategy_skip_news_days          = true;
input bool   strategy_skip_us_early_closes    = true;
input int    strategy_overnight_stop_hhmm     = 1330;

int    g_last_attempt_day_key = 0;
double g_retrace_price        = 0.0;

int Strategy_Hhmm(const datetime t)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(t, dt);
   return (dt.hour * 100 + dt.min);
  }

int Strategy_DateKey(const datetime t)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(t, dt);
   return (dt.year * 10000 + dt.mon * 100 + dt.day);
  }

int Strategy_NthWeekdayOfMonth(const int year, const int month, const int day_of_week, const int nth)
  {
   int hits = 0;
   for(int day = 1; day <= 31; ++day)
     {
      MqlDateTime dt;
      ZeroMemory(dt);
      dt.year = year;
      dt.mon  = month;
      dt.day  = day;
      datetime t = StructToTime(dt);
      MqlDateTime checked;
      ZeroMemory(checked);
      TimeToStruct(t, checked);
      if(checked.mon != month)
         break;
      if(checked.day_of_week != day_of_week)
         continue;
      hits++;
      if(hits == nth)
         return day;
     }
   return -1;
  }

bool Strategy_IsUSEarlyCloseDate(const datetime broker_time)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(broker_time, dt);

   if(dt.mon == 7 && dt.day == 3)
      return true;
   if(dt.mon == 12 && dt.day == 24)
      return true;

   const int thanksgiving = Strategy_NthWeekdayOfMonth(dt.year, 11, 4, 4);
   if(dt.mon == 11 && thanksgiving > 0 && dt.day == thanksgiving + 1)
      return true;

   return false;
  }

double Strategy_Percentile(double &values[], const int count, const double percentile)
  {
   if(count <= 0)
      return 0.0;

   ArrayResize(values, count);
   ArraySort(values);

   double p = percentile / 100.0;
   if(p < 0.0)
      p = 0.0;
   if(p > 1.0)
      p = 1.0;

   const int idx = (int)MathFloor((double)(count - 1) * p);
   return values[idx];
  }

bool Strategy_CopyRates(const int count, MqlRates &rates[])
  {
   if(count <= 0)
      return false;

   ArrayResize(rates, count);
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_M15, 1, count, rates); // perf-allowed: closed-bar M15 auction-window cache
   return (copied == count);
  }

bool Strategy_GetOurPosition(ENUM_POSITION_TYPE &ptype, datetime &opened, double &open_price)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ptype      = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      opened     = (datetime)PositionGetInteger(POSITION_TIME);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      return true;
     }
   return false;
  }

bool Strategy_LoadAuctionBars(MqlRates &final_bar, MqlRates &prior_bar)
  {
   MqlRates recent[];
   if(!Strategy_CopyRates(3, recent))
      return false;

   final_bar = recent[0];
   prior_bar = recent[1];

   if(Strategy_Hhmm(final_bar.time) != strategy_final_bar_hhmm_broker)
      return false;
   if(Strategy_Hhmm(prior_bar.time) != strategy_prior_bar_hhmm_broker)
      return false;
   if(Strategy_DateKey(final_bar.time) != Strategy_DateKey(prior_bar.time))
      return false;

   return true;
  }

bool Strategy_LoadRollingThresholds(double &volume_threshold, double &spread_threshold)
  {
   const int bars_per_day = 96;
   const int count = MathMax(200, strategy_volume_lookback_days * bars_per_day + 8);

   MqlRates rates[];
   if(!Strategy_CopyRates(count, rates))
      return false;

   double volumes[];
   double spreads[];
   ArrayResize(volumes, strategy_volume_lookback_days);
   ArrayResize(spreads, strategy_spread_lookback_bars);

   int volume_count = 0;
   for(int i = 2; i < count - 1 && volume_count < strategy_volume_lookback_days; ++i)
     {
      if(Strategy_Hhmm(rates[i].time) != strategy_final_bar_hhmm_broker)
         continue;
      if(Strategy_Hhmm(rates[i + 1].time) != strategy_prior_bar_hhmm_broker)
         continue;
      if(Strategy_DateKey(rates[i].time) != Strategy_DateKey(rates[i + 1].time))
         continue;

      volumes[volume_count] = (double)rates[i].tick_volume + (double)rates[i + 1].tick_volume;
      volume_count++;
     }

   if(volume_count < strategy_min_percentile_samples)
      return false;

   int spread_count = 0;
   for(int i = 2; i < count && spread_count < strategy_spread_lookback_bars; ++i)
     {
      if(rates[i].spread <= 0)
         continue;
      spreads[spread_count] = (double)rates[i].spread;
      spread_count++;
     }

   volume_threshold = Strategy_Percentile(volumes, volume_count, strategy_volume_percentile);
   spread_threshold = (spread_count >= strategy_min_percentile_samples)
                      ? Strategy_Percentile(spreads, spread_count, strategy_spread_percentile)
                      : DBL_MAX;
   return (volume_threshold > 0.0 && spread_threshold > 0.0);
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_M15)
      return true;

   if(strategy_skip_us_early_closes && Strategy_IsUSEarlyCloseDate(TimeCurrent()))
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

   ENUM_POSITION_TYPE ptype;
   datetime opened;
   double open_price;
   if(Strategy_GetOurPosition(ptype, opened, open_price))
      return false;

   MqlRates final_bar;
   MqlRates prior_bar;
   if(!Strategy_LoadAuctionBars(final_bar, prior_bar))
      return false;

   const int day_key = Strategy_DateKey(final_bar.time);
   if(g_last_attempt_day_key == day_key)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1);
   if(atr <= 0.0 || final_bar.close <= 0.0 || prior_bar.open <= 0.0)
      return false;

   double volume_threshold = 0.0;
   double spread_threshold = 0.0;
   if(!Strategy_LoadRollingThresholds(volume_threshold, spread_threshold))
      return false;

   const double final_volume = (double)final_bar.tick_volume + (double)prior_bar.tick_volume;
   if(final_volume <= volume_threshold)
      return false;

   if(final_bar.spread > 0 && (double)final_bar.spread > spread_threshold)
      return false;

   const double close_ret = (final_bar.close / prior_bar.open) - 1.0;
   const double threshold = strategy_pressure_atr_mult * atr / final_bar.close;
   if(MathAbs(close_ret) < threshold)
      return false;

   const double entry = (close_ret > 0.0) ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                          : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   req.type = (close_ret > 0.0) ? QM_SELL : QM_BUY;
   req.price = 0.0;
   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry, atr, strategy_stop_atr_mult);
   req.tp = 0.0;
   req.reason = (close_ret > 0.0) ? "CLOSE_AUCT_PRESSURE_SHORT" : "CLOSE_AUCT_PRESSURE_LONG";

   if(req.sl <= 0.0)
      return false;

   g_retrace_price = prior_bar.open + (strategy_retrace_fraction * (final_bar.close - prior_bar.open));
   g_last_attempt_day_key = day_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, averaging, or grid management.
  }

bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype;
   datetime opened;
   double open_price;
   if(!Strategy_GetOurPosition(ptype, opened, open_price))
      return false;

   if(g_retrace_price > 0.0)
     {
      if(ptype == POSITION_TYPE_BUY && SymbolInfoDouble(_Symbol, SYMBOL_BID) >= g_retrace_price)
         return true;
      if(ptype == POSITION_TYPE_SELL && SymbolInfoDouble(_Symbol, SYMBOL_ASK) <= g_retrace_price)
         return true;
     }

   const int max_hold_seconds = strategy_hold_bars * PeriodSeconds(PERIOD_M15);
   if(max_hold_seconds > 0 && TimeCurrent() - opened >= max_hold_seconds)
      return true;

   if(Strategy_DateKey(TimeCurrent()) != Strategy_DateKey(opened) &&
      Strategy_Hhmm(TimeCurrent()) >= strategy_overnight_stop_hhmm)
      return true;

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(strategy_skip_us_early_closes && Strategy_IsUSEarlyCloseDate(broker_time))
      return true;

   if(strategy_skip_news_days && !QM_NewsAllowsTrade(_Symbol, broker_time, QM_NEWS_SKIP_DAY))
      return true;

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10326_close-auct-rev\"}");
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
