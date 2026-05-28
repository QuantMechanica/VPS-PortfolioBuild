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
input int    strategy_london_open_hhmm       = 800;
input int    strategy_london_close_hhmm      = 1630;
input int    strategy_ny_overlap_open_hhmm   = 1330;
input int    strategy_ny_overlap_close_hhmm  = 2100;
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

int DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

datetime DateWithHhmm(const datetime base_time, const int hhmm)
  {
   MqlDateTime dt;
   TimeToStruct(base_time, dt);
   dt.hour = hhmm / 100;
   dt.min = hhmm % 100;
   dt.sec = 0;
   return StructToTime(dt);
  }

void ResolveSession(int &open_hhmm, int &close_hhmm)
  {
   const string sym = _Symbol;
   if(sym == "EURUSD.DWX" || sym == "GBPUSD.DWX")
     {
      open_hhmm = strategy_london_open_hhmm;
      close_hhmm = strategy_london_close_hhmm;
      return;
     }

   open_hhmm = strategy_ny_overlap_open_hhmm;
   close_hhmm = strategy_ny_overlap_close_hhmm;
  }

bool IsInsideSession(const int hhmm, const int open_hhmm, const int close_hhmm)
  {
   const int m = HhmmToMinutes(hhmm);
   const int open_m = HhmmToMinutes(open_hhmm);
   const int close_m = HhmmToMinutes(close_hhmm);
   if(open_m <= close_m)
      return (m >= open_m && m < close_m);
   return (m >= open_m || m < close_m);
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

bool FirstWindowStatsForDay(const datetime day_time,
                            const int open_hhmm,
                            double &open_return,
                            double &abs_range)
  {
   open_return = 0.0;
   abs_range = 0.0;

   const datetime first_bar_time = DateWithHhmm(day_time, open_hhmm);
   const int shift = iBarShift(_Symbol, PERIOD_M30, first_bar_time, true);
   if(shift < 1)
      return false;

   const double session_open = iOpen(_Symbol, PERIOD_M30, shift);
   const double first_close = iClose(_Symbol, PERIOD_M30, shift);
   const double first_high = iHigh(_Symbol, PERIOD_M30, shift);
   const double first_low = iLow(_Symbol, PERIOD_M30, shift);
   if(session_open <= 0.0 || first_close <= 0.0 ||
      first_high <= 0.0 || first_low <= 0.0 || first_high <= first_low)
      return false;

   open_return = (first_close / session_open) - 1.0;
   abs_range = first_high - first_low;
   return true;
  }

bool RollingFirstWindowMedians(const int open_hhmm,
                               double &median_abs_return,
                               double &median_abs_range)
  {
   median_abs_return = 0.0;
   median_abs_range = 0.0;

   if(strategy_median_days <= 0)
      return false;

   double returns[];
   double ranges[];
   ArrayResize(returns, strategy_median_days);
   ArrayResize(ranges, strategy_median_days);

   int count = 0;
   const datetime now = TimeCurrent();
   for(int day_back = 1; day_back <= 60 && count < strategy_median_days; ++day_back)
     {
      double r = 0.0;
      double range = 0.0;
      if(!FirstWindowStatsForDay(now - day_back * 86400, open_hhmm, r, range))
         continue;

      returns[count] = MathAbs(r);
      ranges[count] = range;
      ++count;
     }

   if(count < MathMin(strategy_median_days, 10))
      return false;

   return (Median(returns, count, median_abs_return) &&
           Median(ranges, count, median_abs_range));
  }

bool RollingCloseWindowMedianSpread(const int entry_hhmm, double &median_spread)
  {
   median_spread = 0.0;
   if(strategy_median_days <= 0)
      return false;

   double spreads[];
   ArrayResize(spreads, strategy_median_days);

   int count = 0;
   const datetime now = TimeCurrent();
   for(int day_back = 1; day_back <= 60 && count < strategy_median_days; ++day_back)
     {
      const datetime bar_time = DateWithHhmm(now - day_back * 86400, entry_hhmm);
      const int shift = iBarShift(_Symbol, PERIOD_M30, bar_time, true);
      if(shift < 1)
         continue;

      const int spread = iSpread(_Symbol, PERIOD_M30, shift);
      if(spread <= 0)
         continue;

      spreads[count] = (double)spread;
      ++count;
     }

   if(count < MathMin(strategy_median_days, 10))
      return false;

   return Median(spreads, count, median_spread);
  }

bool Strategy_NoTradeFilter()
  {
   // No Trade Filter (time, spread, news): news is handled by the framework
   // and Strategy_NewsFilterHook; this hook applies the cheap card time gate.
   if(HasOurOpenPosition())
      return false;

   int open_hhmm = 0;
   int close_hhmm = 0;
   ResolveSession(open_hhmm, close_hhmm);

   const int now_hhmm = Hhmm(TimeCurrent());
   if(!IsInsideSession(now_hhmm, open_hhmm, close_hhmm))
      return true;

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Trade Entry: first 30-minute session return sign opens in final 30 minutes.
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(_Period != PERIOD_M30)
      return false;

   int open_hhmm = 0;
   int close_hhmm = 0;
   ResolveSession(open_hhmm, close_hhmm);

   const int entry_hhmm = MinutesToHhmm(HhmmToMinutes(close_hhmm) - 30);
   const datetime current_bar = iTime(_Symbol, PERIOD_M30, 0);
   if(current_bar <= 0 || Hhmm(current_bar) != entry_hhmm)
      return false;

   if(HasOurOpenPosition())
      return false;

   if(strategy_spread_median_mult > 0.0)
     {
      double median_spread = 0.0;
      if(!RollingCloseWindowMedianSpread(entry_hhmm, median_spread))
         return false;

      const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(current_spread <= 0 || (double)current_spread > median_spread * strategy_spread_median_mult)
         return false;
     }

   double open_return = 0.0;
   double open_range = 0.0;
   if(!FirstWindowStatsForDay(TimeCurrent(), open_hhmm, open_return, open_range))
      return false;

   double median_abs_return = 0.0;
   double median_abs_range = 0.0;
   if(!RollingFirstWindowMedians(open_hhmm, median_abs_return, median_abs_range))
      return false;

   if(MathAbs(open_return) < strategy_min_return_median_mult * median_abs_return)
      return false;

   const double stop_distance = strategy_stop_range_mult * median_abs_range;
   if(stop_distance <= 0.0)
      return false;

   if(open_return > 0.0)
     {
      req.type = QM_BUY;
      req.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.reason = "FX_OPEN_CLOSE_MOMENTUM_LONG";
     }
   else
     {
      req.type = QM_SELL;
      req.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
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
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults.
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

   // Per-tick: trade management can adjust SL/TP on open positions.
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
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

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
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
