#property strict
#property version   "5.0"
#property description "QM5_10828 TradingView Prison Escape Breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10828;
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
input int    strategy_pivot_depth          = 5;
input int    strategy_selected_first_pivot = 0;      // A=0, B=1, C=2, D=3.
input int    strategy_selected_last_pivot  = 3;
input int    strategy_confirm_closes       = 2;
input int    strategy_atr_period           = 14;
input double strategy_min_range_atr_mult   = 0.50;
input double strategy_max_range_atr_mult   = 3.00;
input double strategy_fvg_atr_mult         = 0.00;   // 0.0 disables optional FVG filter.
input double strategy_rr_target            = 1.00;
input int    strategy_entry_start_hhmm     = 830;    // America/Chicago.
input int    strategy_entry_end_hhmm       = 1030;   // America/Chicago.
input int    strategy_flat_hhmm            = 1230;   // America/Chicago.
input bool   strategy_one_trade_per_day    = true;
input int    strategy_max_spread_points    = 0;      // 0 disables.

// -----------------------------------------------------------------------------
// Strategy hooks and helpers.
// -----------------------------------------------------------------------------

#define STRATEGY_MAX_PIVOTS 8

int      g_strategy_day_key = 0;
bool     g_strategy_trade_taken_today = false;
int      g_strategy_pivot_count = 0;
double   g_strategy_pivot_values[STRATEGY_MAX_PIVOTS];
datetime g_strategy_pivot_times[STRATEGY_MAX_PIVOTS];
bool     g_strategy_range_ready = false;
double   g_strategy_range_high = 0.0;
double   g_strategy_range_low = 0.0;

datetime Strategy_BrokerToChicago(const datetime broker_time)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   const int offset_hours = QM_IsUSDSTUTC(utc) ? -5 : -6;
   return utc + offset_hours * 3600;
  }

int Strategy_HhmmFromTime(const datetime t)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

int Strategy_HhmmToMinutes(const int hhmm)
  {
   return (hhmm / 100) * 60 + (hhmm % 100);
  }

bool Strategy_HhmmInWindow(const int hhmm, const int start_hhmm, const int end_hhmm)
  {
   const int now_m = Strategy_HhmmToMinutes(hhmm);
   const int start_m = Strategy_HhmmToMinutes(start_hhmm);
   const int end_m = Strategy_HhmmToMinutes(end_hhmm);
   if(start_m == end_m)
      return true;
   if(start_m < end_m)
      return (now_m >= start_m && now_m < end_m);
   return (now_m >= start_m || now_m < end_m);
  }

int Strategy_DayKeyFromTime(const datetime t)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

void Strategy_ResetDay(const int day_key)
  {
   g_strategy_day_key = day_key;
   g_strategy_trade_taken_today = false;
   g_strategy_pivot_count = 0;
   g_strategy_range_ready = false;
   g_strategy_range_high = 0.0;
   g_strategy_range_low = 0.0;
   for(int i = 0; i < STRATEGY_MAX_PIVOTS; ++i)
     {
      g_strategy_pivot_values[i] = 0.0;
      g_strategy_pivot_times[i] = 0;
     }
  }

void Strategy_EnsureDay(const datetime broker_time)
  {
   const int day_key = Strategy_DayKeyFromTime(Strategy_BrokerToChicago(broker_time));
   if(day_key != g_strategy_day_key)
      Strategy_ResetDay(day_key);
  }

bool Strategy_SpreadAllows()
  {
   if(strategy_max_spread_points <= 0)
      return true;
   const int spread_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread_points <= strategy_max_spread_points);
  }

bool Strategy_HasOurOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

double Strategy_NormalizePrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
  }

void Strategy_ResetRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool Strategy_AppendPivot(const datetime pivot_time, const double value)
  {
   if(value <= 0.0 || g_strategy_pivot_count >= STRATEGY_MAX_PIVOTS)
      return false;

   for(int i = 0; i < g_strategy_pivot_count; ++i)
      if(g_strategy_pivot_times[i] == pivot_time && MathAbs(g_strategy_pivot_values[i] - value) < _Point)
         return false;

   g_strategy_pivot_values[g_strategy_pivot_count] = value;
   g_strategy_pivot_times[g_strategy_pivot_count] = pivot_time;
   g_strategy_pivot_count++;
   return true;
  }

bool Strategy_IsPivotHigh(const int shift, const int depth)
  {
   const double candidate = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, shift); // perf-allowed
   if(candidate <= 0.0)
      return false;

   for(int i = 1; i <= depth; ++i)
     {
      const double newer_high = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, shift - i); // perf-allowed
      const double older_high = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, shift + i); // perf-allowed
      if(newer_high <= 0.0 || older_high <= 0.0)
         return false;
      if(candidate <= newer_high || candidate < older_high)
         return false;
     }
   return true;
  }

bool Strategy_IsPivotLow(const int shift, const int depth)
  {
   const double candidate = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, shift); // perf-allowed
   if(candidate <= 0.0)
      return false;

   for(int i = 1; i <= depth; ++i)
     {
      const double newer_low = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, shift - i); // perf-allowed
      const double older_low = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, shift + i); // perf-allowed
      if(newer_low <= 0.0 || older_low <= 0.0)
         return false;
      if(candidate >= newer_low || candidate > older_low)
         return false;
     }
   return true;
  }

bool Strategy_RebuildRange()
  {
   const int first = MathMax(0, MathMin(strategy_selected_first_pivot, STRATEGY_MAX_PIVOTS - 1));
   const int last = MathMax(first, MathMin(strategy_selected_last_pivot, STRATEGY_MAX_PIVOTS - 1));
   if(g_strategy_pivot_count <= last)
      return false;

   double hi = -DBL_MAX;
   double lo = DBL_MAX;
   for(int i = first; i <= last; ++i)
     {
      hi = MathMax(hi, g_strategy_pivot_values[i]);
      lo = MathMin(lo, g_strategy_pivot_values[i]);
     }

   if(hi <= 0.0 || lo <= 0.0 || hi <= lo)
      return false;

   g_strategy_range_high = hi;
   g_strategy_range_low = lo;
   g_strategy_range_ready = true;
   return true;
  }

void Strategy_AdvancePivotState()
  {
   const int depth = MathMax(1, MathMin(strategy_pivot_depth, 20));
   const int shift = depth + 1;
   const datetime pivot_broker_time = iTime(_Symbol, (ENUM_TIMEFRAMES)_Period, shift); // perf-allowed
   if(pivot_broker_time <= 0)
      return;

   const datetime chicago_time = Strategy_BrokerToChicago(pivot_broker_time);
   const int hhmm = Strategy_HhmmFromTime(chicago_time);
   if(hhmm < strategy_entry_start_hhmm || hhmm >= strategy_entry_end_hhmm)
      return;

   if(Strategy_IsPivotHigh(shift, depth))
      Strategy_AppendPivot(pivot_broker_time, iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, shift)); // perf-allowed
   if(Strategy_IsPivotLow(shift, depth))
      Strategy_AppendPivot(pivot_broker_time, iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, shift)); // perf-allowed

   Strategy_RebuildRange();
  }

bool Strategy_RangeWidthAllows()
  {
   if(!g_strategy_range_ready)
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, MathMax(1, strategy_atr_period), 1);
   if(atr <= 0.0)
      return false;

   const double width = g_strategy_range_high - g_strategy_range_low;
   return (width >= atr * MathMax(0.0, strategy_min_range_atr_mult) &&
           width <= atr * MathMax(strategy_min_range_atr_mult, strategy_max_range_atr_mult));
  }

bool Strategy_ConsecutiveClosesOutside(const bool want_long)
  {
   const int confirms = MathMax(1, MathMin(strategy_confirm_closes, 4));
   for(int shift = 1; shift <= confirms; ++shift)
     {
      const double close_price = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, shift); // perf-allowed
      if(close_price <= 0.0)
         return false;
      if(want_long && close_price <= g_strategy_range_high)
         return false;
      if(!want_long && close_price >= g_strategy_range_low)
         return false;
     }
   return true;
  }

bool Strategy_FVGAllows(const bool want_long)
  {
   if(strategy_fvg_atr_mult <= 0.0)
      return true;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, MathMax(1, strategy_atr_period), 1);
   if(atr <= 0.0)
      return false;

   if(want_long)
     {
      const double low_1 = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, 1); // perf-allowed
      const double high_3 = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, 3); // perf-allowed
      return (low_1 > high_3 && (low_1 - high_3) >= atr * strategy_fvg_atr_mult);
     }

   const double high_1 = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, 1); // perf-allowed
   const double low_3 = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, 3); // perf-allowed
   return (high_1 < low_3 && (low_3 - high_1) >= atr * strategy_fvg_atr_mult);
  }

bool Strategy_BuildBreakoutRequest(const bool want_long, QM_EntryRequest &req)
  {
   const double entry = want_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                  : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0 || !g_strategy_range_ready)
      return false;

   const double sl = want_long ? g_strategy_range_low : g_strategy_range_high;
   if(sl <= 0.0)
      return false;
   if(want_long && sl >= entry)
      return false;
   if(!want_long && sl <= entry)
      return false;

   const double tp = QM_TakeRR(_Symbol, want_long ? QM_BUY : QM_SELL, entry, sl, MathMax(0.1, strategy_rr_target));
   if(tp <= 0.0)
      return false;

   req.type = want_long ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = Strategy_NormalizePrice(sl);
   req.tp = Strategy_NormalizePrice(tp);
   req.reason = want_long ? "TV_PRISON_ESCAPE_LONG" : "TV_PRISON_ESCAPE_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   Strategy_EnsureDay(TimeCurrent());

   if(Strategy_HasOurOpenPosition())
      return false;
   if(!Strategy_SpreadAllows())
      return true;

   const int hhmm = Strategy_HhmmFromTime(Strategy_BrokerToChicago(TimeCurrent()));
   if(!Strategy_HhmmInWindow(hhmm, strategy_entry_start_hhmm, strategy_entry_end_hhmm))
      return true;

   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_ResetRequest(req);
   Strategy_EnsureDay(TimeCurrent());
   Strategy_AdvancePivotState();

   if(Strategy_HasOurOpenPosition())
     {
      g_strategy_trade_taken_today = true;
      return false;
     }
   if(strategy_one_trade_per_day && g_strategy_trade_taken_today)
      return false;
   if(!Strategy_RangeWidthAllows())
      return false;

   const int hhmm = Strategy_HhmmFromTime(Strategy_BrokerToChicago(TimeCurrent()));
   if(!Strategy_HhmmInWindow(hhmm, strategy_entry_start_hhmm, strategy_entry_end_hhmm))
      return false;

   if(Strategy_ConsecutiveClosesOutside(true) &&
      Strategy_FVGAllows(true) &&
      Strategy_BuildBreakoutRequest(true, req))
     {
      g_strategy_trade_taken_today = true;
      return true;
     }

   if(Strategy_ConsecutiveClosesOutside(false) &&
      Strategy_FVGAllows(false) &&
      Strategy_BuildBreakoutRequest(false, req))
     {
      g_strategy_trade_taken_today = true;
      return true;
     }

   return false;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card baseline has no trailing, break-even, partial close, or add-on logic.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   const int hhmm = Strategy_HhmmFromTime(Strategy_BrokerToChicago(TimeCurrent()));
   if(hhmm < strategy_flat_hhmm)
      return false;

   return Strategy_HasOurOpenPosition();
  }

// News Filter Hook
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
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
