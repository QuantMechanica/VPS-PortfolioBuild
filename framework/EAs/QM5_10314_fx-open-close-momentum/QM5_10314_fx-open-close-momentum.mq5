#property strict
#property version   "5.0"
#property description "QM5_10314 FX Open Close Momentum"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 10314;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
// Session hours in DXZ BROKER time (GMT+2 outside US DST, GMT+3 during US DST).
// London: broker 10:00-18:30 (UTC 08:00-16:30). NY overlap: broker 15:30-20:00.
input int    strategy_london_open_hhmm       = 1000;
input int    strategy_london_close_hhmm      = 1830;
input int    strategy_ny_overlap_open_hhmm   = 1530;
input int    strategy_ny_overlap_close_hhmm  = 2000;
input int    strategy_median_days            = 20;
input double strategy_min_return_median_mult = 0.10;
input double strategy_stop_range_mult        = 0.75;
input double strategy_spread_median_mult     = 1.50;

int HhmmToMinutes(const int hhmm)
  {
   return (hhmm / 100) * 60 + (hhmm % 100);
  }

int MinutesToHhmm(int minutes)
  {
   while(minutes < 0)
      minutes += 1440;
   minutes %= 1440;
   return (minutes / 60) * 100 + (minutes % 60);
  }

int Hhmm(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

datetime DateWithHhmm(const datetime base_time, const int hhmm)
  {
   MqlDateTime dt;
   TimeToStruct(base_time, dt);
   dt.hour = hhmm / 100;
   dt.min  = hhmm % 100;
   dt.sec  = 0;
   return StructToTime(dt);
  }

void ResolveSession(int &open_hhmm, int &close_hhmm)
  {
   const string sym = _Symbol;
   if(sym == "EURUSD.DWX" || sym == "GBPUSD.DWX")
     {
      open_hhmm  = strategy_london_open_hhmm;
      close_hhmm = strategy_london_close_hhmm;
      return;
     }
   open_hhmm  = strategy_ny_overlap_open_hhmm;
   close_hhmm = strategy_ny_overlap_close_hhmm;
  }

bool HasOurOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

void SortAscending(double &values[], const int count)
  {
   for(int i = 1; i < count; ++i)
     {
      const double key = values[i];
      int j = i - 1;
      while(j >= 0 && values[j] > key)
        {
         values[j + 1] = values[j];
         --j;
        }
      values[j + 1] = key;
     }
  }

bool Median(double &values[], const int count, double &median)
  {
   median = 0.0;
   if(count <= 0)
      return false;
   SortAscending(values, count);
   if((count % 2) == 1)
      median = values[count / 2];
   else
      median = 0.5 * (values[count / 2 - 1] + values[count / 2]);
   return (median > 0.0);
  }

// perf-allowed: bespoke per-session first-bar OHLC lookup; no QM helper for session-anchor shifts.
bool FirstWindowStatsForDay(const datetime day_time,
                            const int open_hhmm,
                            double &open_return,
                            double &abs_range)
  {
   open_return = 0.0;
   abs_range   = 0.0;

   const datetime first_bar_time = DateWithHhmm(day_time, open_hhmm);
   const int shift = iBarShift(_Symbol, PERIOD_M30, first_bar_time, true); // perf-allowed
   if(shift < 1)
      return false;

   const double session_open = iOpen(_Symbol, PERIOD_M30, shift);   // perf-allowed
   const double first_close  = iClose(_Symbol, PERIOD_M30, shift);  // perf-allowed
   const double first_high   = iHigh(_Symbol, PERIOD_M30, shift);   // perf-allowed
   const double first_low    = iLow(_Symbol, PERIOD_M30, shift);    // perf-allowed
   if(session_open <= 0.0 || first_close <= 0.0 ||
      first_high <= 0.0 || first_low <= 0.0 || first_high <= first_low)
      return false;

   open_return = (first_close / session_open) - 1.0;
   abs_range   = first_high - first_low;
   return true;
  }

// perf-allowed: rolls 20-day medians for momentum threshold and stop; runs once per day at entry_hhmm.
bool RollingFirstWindowMedians(const int open_hhmm,
                               double &median_abs_return,
                               double &median_abs_range)
  {
   median_abs_return = 0.0;
   median_abs_range  = 0.0;

   if(strategy_median_days <= 0)
      return false;

   double returns[];
   double ranges[];
   ArrayResize(returns, strategy_median_days);
   ArrayResize(ranges,  strategy_median_days);

   int count = 0;
   const datetime now = TimeCurrent();
   for(int day_back = 1; day_back <= 60 && count < strategy_median_days; ++day_back)
     {
      double r     = 0.0;
      double range = 0.0;
      if(!FirstWindowStatsForDay(now - (datetime)(day_back * 86400), open_hhmm, r, range))
         continue;
      returns[count] = MathAbs(r);
      ranges[count]  = range;
      ++count;
     }

   if(count < MathMin(strategy_median_days, 10))
      return false;

   return (Median(returns, count, median_abs_return) &&
           Median(ranges, count, median_abs_range));
  }

// Returns false when no usable historical spread data exists (e.g. DWX tester spread=0).
// Caller must treat false as "skip filter" not "block trade".
bool RollingCloseWindowMedianSpread(const int entry_hhmm, double &median_spread_pts)
  {
   median_spread_pts = 0.0;
   if(strategy_median_days <= 0)
      return false;

   double spreads[];
   ArrayResize(spreads, strategy_median_days);

   int count = 0;
   const datetime now = TimeCurrent();
   for(int day_back = 1; day_back <= 60 && count < strategy_median_days; ++day_back)
     {
      const datetime bar_time = DateWithHhmm(now - (datetime)(day_back * 86400), entry_hhmm);
      const int shift = iBarShift(_Symbol, PERIOD_M30, bar_time, true); // perf-allowed
      if(shift < 1)
         continue;
      const int spread = iSpread(_Symbol, PERIOD_M30, shift); // perf-allowed
      if(spread <= 0)
         continue; // DWX tester: all historical spreads = 0; count stays 0
      spreads[count] = (double)spread;
      ++count;
     }

   if(count < MathMin(strategy_median_days, 10))
      return false; // not enough non-zero spread samples

   return Median(spreads, count, median_spread_pts);
  }

bool Strategy_NoTradeFilter()
  {
   // No Trade Filter: block if outside the configured session window.
   // If a position is already open, pass through so ExitSignal can fire.
   if(HasOurOpenPosition())
      return false;

   int open_hhmm = 0;
   int close_hhmm = 0;
   ResolveSession(open_hhmm, close_hhmm);

   const int now_hhmm = Hhmm(TimeCurrent());
   const int open_m   = HhmmToMinutes(open_hhmm);
   const int close_m  = HhmmToMinutes(close_hhmm);
   const int now_m    = HhmmToMinutes(now_hhmm);

   bool inside;
   if(open_m <= close_m)
      inside = (now_m >= open_m && now_m < close_m);
   else
      inside = (now_m >= open_m || now_m < close_m);

   return !inside;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Trade Entry: at the opening of the last 30-minute session window, go long
   // if the first-half-hour return was positive, short if negative.
   req.type             = QM_BUY;
   req.price            = 0.0;
   req.sl               = 0.0;
   req.tp               = 0.0;
   req.reason           = "";
   req.symbol_slot      = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(_Period != PERIOD_M30)
      return false;

   int open_hhmm = 0;
   int close_hhmm = 0;
   ResolveSession(open_hhmm, close_hhmm);

   const int entry_hhmm = MinutesToHhmm(HhmmToMinutes(close_hhmm) - 30);

   // perf-allowed: read current M30 bar open time to gate entry on the final window bar.
   const datetime current_bar = iTime(_Symbol, PERIOD_M30, 0); // perf-allowed
   if(current_bar <= 0 || Hhmm(current_bar) != entry_hhmm)
      return false;

   if(HasOurOpenPosition())
      return false;

   // Spread filter — DWX-safe: only apply if historical spread data exists (median > 0).
   // DWX tester quotes spread=0 so the rolling median will be unavailable; we skip
   // the filter rather than blocking all entries (DWX backtest invariant #1).
   if(strategy_spread_median_mult > 0.0)
     {
      double median_spread_pts = 0.0;
      if(RollingCloseWindowMedianSpread(entry_hhmm, median_spread_pts) && median_spread_pts > 0.0)
        {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         const double pt  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         if(ask > 0.0 && bid > 0.0 && ask > bid && pt > 0.0)
           {
            const double cur_spread_pts = (ask - bid) / pt;
            if(cur_spread_pts > median_spread_pts * strategy_spread_median_mult)
               return false;
           }
        }
      // If no median data (DWX zero-spread tester), spread filter is skipped.
     }

   double open_return = 0.0;
   double open_range  = 0.0;
   if(!FirstWindowStatsForDay(TimeCurrent(), open_hhmm, open_return, open_range))
      return false;

   double median_abs_return = 0.0;
   double median_abs_range  = 0.0;
   if(!RollingFirstWindowMedians(open_hhmm, median_abs_return, median_abs_range))
      return false;

   if(MathAbs(open_return) < strategy_min_return_median_mult * median_abs_return)
      return false;

   const double stop_distance = strategy_stop_range_mult * median_abs_range;
   if(stop_distance <= 0.0)
      return false;

   if(open_return > 0.0)
     {
      req.type   = QM_BUY;
      req.price  = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.reason = "FX_OPEN_CLOSE_MOMENTUM_LONG";
     }
   else
     {
      req.type   = QM_SELL;
      req.price  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      req.reason = "FX_OPEN_CLOSE_MOMENTUM_SHORT";
     }

   if(req.price <= 0.0)
      return false;

   req.sl = QM_StopRulesStopFromDistance(_Symbol, req.type, req.price, stop_distance);
   req.tp = 0.0;
   return (req.sl > 0.0);
  }

void Strategy_ManageOpenPosition()
  {
   // Trade Management: card specifies one position per symbol/magic and no
   // trailing, partial close, break-even, or add-on logic.
  }

bool Strategy_ExitSignal()
  {
   // Trade Close: close at the end of the final 30-minute session window.
   if(!HasOurOpenPosition())
      return false;

   int open_hhmm = 0;
   int close_hhmm = 0;
   ResolveSession(open_hhmm, close_hhmm);

   return (Hhmm(TimeCurrent()) >= close_hhmm);
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // News Filter Hook: no card-specific override beyond the framework filter.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10314\",\"strategy\":\"fx_open_close_momentum\"}");
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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
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
