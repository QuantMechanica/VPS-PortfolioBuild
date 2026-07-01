#property strict
#property version   "5.0"
#property description "QM5_12832 DAX Range Breakout - GDAXI overnight range (Balke transfer)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12832: DAX Range Breakout (Balke transfer to GDAXI)
// -----------------------------------------------------------------------------
// Rene Balke style applied to GDAXI (Frankfurt index):
//   1. Range: High/Low over overnight [range_start_hour, range_end_hour) window
//      in broker time, handling midnight wrap (default 22:00 -> 08:00).
//   2. Breakout: completed-bar close beyond locked range edge, confirmed by close.
//   3. Filters: range-size vs daily-ATR band, volume surge, spread cap.
//   4. Exit: opposite range edge SL, RR take-profit, OR forced flat at exit_hour.
//   5. One trade per day cycle, single position per magic.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id              = 12832;
input int    qm_magic_slot_offset  = 0;
input uint   qm_rng_seed           = 42;

input group "Risk"
input double RISK_PERCENT          = 0.0;
input double RISK_FIXED            = 1000.0;
input double PORTFOLIO_WEIGHT      = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal    = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance  = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours               = 336;
input string qm_news_min_impact                    = "high";
input QM_NewsMode qm_news_mode_legacy              = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled               = true;
input int    qm_friday_close_hour_broker           = 21;

input group "Stress"
input double qm_stress_reject_probability          = 0.0;

input group "Strategy"
// Overnight range window in broker time (DXZ: GMT+2 outside US DST, GMT+3 during US DST).
// GDAXI default: 22:00 -> 08:00 broker (overnight pre-open), breakout at DAX cash open.
// range_start_hour > range_end_hour => overnight window spanning midnight.
input int    range_start_hour   = 22;    // range accumulation start (broker)
input int    range_end_hour     = 8;     // range lock time (broker, DAX pre-open)
input int    exit_hour          = 17;    // forced flat before DAX cash close (broker)
input int    exit_min           = 0;
input double entry_buffer_atr   = 0.0;   // breakout buffer (x ATR), 0=at range edge
input bool   use_vol_filter     = true;
input double vol_mult           = 1.5;
input double strategy_rr        = 2.5;
input int    strategy_atr_period = 14;
input double atr_sl_mult        = 1.5;   // fallback SL multiplier if range edge invalid
input double min_range_atr_mult = 0.60;  // reject range < N x daily ATR (cost-robustness)
input double max_range_atr_mult = 2.50;  // reject range > N x daily ATR
input int    spread_cap_points  = 30;

// ---- state ----
double   g_range_high    = 0.0;
double   g_range_low     = 0.0;
bool     g_range_locked  = false;
datetime g_cur_day       = 0;
datetime g_trade_day     = 0;

datetime DayStart(const datetime t) { return (datetime)((long)t / 86400 * 86400); }

// True when the range window wraps midnight (start > end, e.g. 22 > 8).
bool RangeWraps() { return range_start_hour > range_end_hour; }

// Compute the "trading day" key for a given broker time.
// For overnight ranges (22->08): hours from 22:00 today map to "next calendar day"
// so that 22:xx (day D) and 00:xx-07:xx (day D+1) share one cycle key (D+1).
// This ensures the range reset fires at the START of the next overnight window (22:00),
// not at midnight, and the locked range remains valid through the full entry window.
datetime RangeTradingDay(const datetime now, const int hour)
  {
   const datetime day = DayStart(now);
   if(RangeWraps() && hour >= range_start_hour)
      return (datetime)(day + 86400);
   return day;
  }

bool IsRangeBuildHour(const int hour)
  {
   if(!RangeWraps())
      return (hour >= range_start_hour && hour < range_end_hour);
   return (hour >= range_start_hour || hour < range_end_hour);
  }

bool IsEntryHour(const int hour)
  {
   if(!RangeWraps())
      return (hour >= range_end_hour && hour < exit_hour);
   return (hour >= range_end_hour && hour < exit_hour && hour < range_start_hour);
  }

// Called once per new M15 bar (gated by QM_IsNewBar in OnTick).
// Accumulates closed-bar High/Low during the overnight window and locks the
// range at range_end_hour. Resets the cycle at the next range_start_hour.
void UpdateRange()
  {
   MqlDateTime dt;
   const datetime now = TimeCurrent();
   TimeToStruct(now, dt);
   const datetime day = RangeTradingDay(now, dt.hour);

   if(day != g_cur_day)
     {
      g_cur_day = day;
      g_range_high = 0.0; g_range_low = DBL_MAX;
      g_range_locked = false;
     }

   if(!g_range_locked && IsRangeBuildHour(dt.hour))
     {
      const double h = iHigh(_Symbol, _Period, 1);   // perf-allowed: closed-bar range high
      const double l = iLow(_Symbol, _Period, 1);    // perf-allowed: closed-bar range low
      if(h > 0.0 && h > g_range_high) g_range_high = h;
      if(l > 0.0 && l < g_range_low)  g_range_low  = l;
     }
   else if(!g_range_locked && IsEntryHour(dt.hour) &&
           g_range_high > 0.0 && g_range_low < DBL_MAX && g_range_low < g_range_high)
     {
      g_range_locked = true;
     }
  }

bool HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic) return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Spread cap: block only genuinely wide spread; 0 spread (DWX tester) is OK.
bool Strategy_NoTradeFilter()
  {
   const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread_cap_points > 0 && spread > spread_cap_points) return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   UpdateRange();
   if(HasOpenPosition()) return false;
   if(!g_range_locked) return false;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(!IsEntryHour(dt.hour)) return false;
   if(g_trade_day == g_cur_day) return false;    // one trade/day cycle

   // Range-size vs daily ATR filter (cost-robustness: bigger range = wider stop = smaller lots = cheaper)
   const double datr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double range = g_range_high - g_range_low;
   if(datr > 0.0)
     {
      if(range < min_range_atr_mult * datr) return false;
      if(range > max_range_atr_mult * datr) return false;
     }

   // Volume surge filter: breakout bar volume > average of last 20 bars
   if(use_vol_filter)
     {
      const long vol_1 = iVolume(_Symbol, _Period, 1); // perf-allowed: closed-bar tick-volume
      double vol_sum = 0;
      for(int i = 1; i <= 20; ++i) vol_sum += (double)iVolume(_Symbol, _Period, i); // perf-allowed: bounded 20-bar vol avg
      const double vol_ma = vol_sum / 20.0;
      if(vol_ma <= 0 || (double)vol_1 < vol_ma * vol_mult) return false;
     }

   const double atr    = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   const double buf    = entry_buffer_atr * atr;
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: closed-bar breakout confirmation

   if(close1 > g_range_high + buf)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      req.type = QM_BUY; req.price = 0.0;
      req.symbol_slot = qm_magic_slot_offset; req.expiration_seconds = 0;
      req.sl = g_range_low;
      if(req.sl >= bid) req.sl = bid - atr * atr_sl_mult;
      req.tp = QM_TakeRR(_Symbol, req.type, bid, req.sl, strategy_rr);
      req.reason = "DAX_RANGE_LONG";
      if(req.sl > 0.0 && req.tp > 0.0) { g_trade_day = g_cur_day; return true; }
      return false;
     }

   if(close1 < g_range_low - buf)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.type = QM_SELL; req.price = 0.0;
      req.symbol_slot = qm_magic_slot_offset; req.expiration_seconds = 0;
      req.sl = g_range_high;
      if(req.sl <= ask) req.sl = ask + atr * atr_sl_mult;
      req.tp = QM_TakeRR(_Symbol, req.type, ask, req.sl, strategy_rr);
      req.reason = "DAX_RANGE_SHORT";
      if(req.sl > 0.0 && req.tp > 0.0) { g_trade_day = g_cur_day; return true; }
      return false;
     }

   return false;
  }

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.hour > exit_hour || (dt.hour == exit_hour && dt.min >= exit_min)) return true;
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;  // defer to QM_NewsAllowsTrade / QM_NewsAllowsTrade2
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

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
   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
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
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
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
