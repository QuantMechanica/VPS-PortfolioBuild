#property strict
#property version   "5.1"
#property description "QM5_1407 Classical Symmetric Triangle Breakout H4"

#include <QM/QM_Common.mqh>

// Card: D:/QM/strategy_farm/artifacts/cards_approved/QM5_1407_classical-symmetric-triangle-breakout-h4.md

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 1407;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
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
input ENUM_TIMEFRAMES strategy_tf                    = PERIOD_H4;
input int    strategy_atr_period                     = 14;
input int    strategy_fractal_wing_bars              = 2;
input int    strategy_pivot_scan_bars                = 200;
input int    strategy_pattern_min_bars               = 25;
input int    strategy_pattern_max_bars               = 80;
input int    strategy_min_high_pivots                = 3;
input int    strategy_min_low_pivots                 = 3;
input double strategy_slope_min_atr_factor           = 0.30;
input double strategy_slope_max_atr_factor           = 2.00;
input double strategy_slope_symmetry_ratio           = 0.40;
input double strategy_min_amplitude_atr              = 3.00;
input double strategy_apex_max_extension_pct         = 0.30;
input double strategy_boundary_buffer_atr            = 0.20;
input double strategy_breakout_buffer_atr            = 0.50;
input double strategy_sl_buffer_atr                  = 0.30;
input double strategy_sl_cap_atr                     = 3.00;
input double strategy_tp1_ratio                      = 0.50;
input int    strategy_time_stop_bars                 = 36;
input int    strategy_pending_lifetime_bars          = 12;
input int    strategy_reuse_guard_bars               = 20;
input double strategy_reuse_overlap_ratio            = 0.50;
input double strategy_spread_max_atr                 = 0.25;

const int ST_MAX_SIDE_PIVOTS = 6;
const int ST_MAX_PIVOTS = 12;
const int ST_NONE = 0;
const int ST_PENDING = 1;
const int ST_POSITION = 2;
const int ST_STATE_VERSION = 1;
const int ST_NEWS_BLACKOUT_BARS = 2;

struct StrategyPivot
  {
   int shift;
   double price;
   datetime time;
  };

struct SymmetricTrianglePattern
  {
   int reference_shift;
   double highest_high;
   double lowest_low;
   double supply_slope;
   double demand_slope;
   double supply_at_anchor;
   double demand_at_anchor;
   double apex_shift;
   datetime anchor_time;
   datetime apex_time;
   int high_count;
   int low_count;
   datetime high_times[ST_MAX_SIDE_PIVOTS];
   datetime low_times[ST_MAX_SIDE_PIVOTS];
  };

string g_state_prefix = "";
bool g_state_valid = false;
int g_lifecycle = ST_NONE;
datetime g_setup_time = 0;
datetime g_anchor_time = 0;
datetime g_apex_time = 0;
double g_supply_anchor = 0.0;
double g_demand_anchor = 0.0;
double g_supply_slope = 0.0;
double g_demand_slope = 0.0;
int g_active_count = 0;
datetime g_active_pivots[ST_MAX_PIVOTS];
datetime g_reuse_time = 0;
int g_reuse_count = 0;
datetime g_reuse_pivots[ST_MAX_PIVOTS];
bool g_tp1_partial_done = false;
bool g_tp1_break_even_done = false;
bool g_restart_state_missing = false;

double Strategy_NormalizePrice(const double price)
  {
   return QM_StopRulesNormalizePrice(_Symbol, price);
  }

int Strategy_PeriodSeconds()
  {
   const int seconds = PeriodSeconds(strategy_tf);
   return (seconds > 0) ? seconds : 14400;
  }

string Strategy_StateKey(const string suffix)
  {
   return g_state_prefix + suffix;
  }

double Strategy_LoadValue(const string suffix, const double fallback)
  {
   const string key = Strategy_StateKey(suffix);
   return GlobalVariableCheck(key) ? GlobalVariableGet(key) : fallback;
  }

bool Strategy_SaveValue(const string suffix, const double value)
  {
   return (GlobalVariableSet(Strategy_StateKey(suffix), value) != 0);
  }

void Strategy_ResetActiveMemory()
  {
   g_state_valid = false;
   g_lifecycle = ST_NONE;
   g_setup_time = 0;
   g_anchor_time = 0;
   g_apex_time = 0;
   g_supply_anchor = 0.0;
   g_demand_anchor = 0.0;
   g_supply_slope = 0.0;
   g_demand_slope = 0.0;
   g_active_count = 0;
   for(int i = 0; i < ST_MAX_PIVOTS; ++i)
      g_active_pivots[i] = 0;
   g_tp1_partial_done = false;
   g_tp1_break_even_done = false;
   g_restart_state_missing = false;
  }

bool Strategy_PersistState()
  {
   if(g_state_prefix == "")
      return false;
   bool ok = Strategy_SaveValue("ready", 0.0);
   if(!Strategy_SaveValue("ver", ST_STATE_VERSION)) ok = false;
   if(!Strategy_SaveValue("valid", g_state_valid ? 1.0 : 0.0)) ok = false;
   if(!Strategy_SaveValue("phase", g_lifecycle)) ok = false;
   if(!Strategy_SaveValue("setup", g_setup_time)) ok = false;
   if(!Strategy_SaveValue("anchor", g_anchor_time)) ok = false;
   if(!Strategy_SaveValue("apex", g_apex_time)) ok = false;
   if(!Strategy_SaveValue("sup0", g_supply_anchor)) ok = false;
   if(!Strategy_SaveValue("dem0", g_demand_anchor)) ok = false;
   if(!Strategy_SaveValue("sups", g_supply_slope)) ok = false;
   if(!Strategy_SaveValue("dems", g_demand_slope)) ok = false;
   if(!Strategy_SaveValue("ac", g_active_count)) ok = false;
   if(!Strategy_SaveValue("reuse_t", g_reuse_time)) ok = false;
   if(!Strategy_SaveValue("rc", g_reuse_count)) ok = false;
   if(!Strategy_SaveValue("tp1p", g_tp1_partial_done ? 1.0 : 0.0)) ok = false;
   if(!Strategy_SaveValue("tp1b", g_tp1_break_even_done ? 1.0 : 0.0)) ok = false;
   for(int i = 0; i < ST_MAX_PIVOTS; ++i)
     {
      if(!Strategy_SaveValue(StringFormat("ap%d", i), g_active_pivots[i])) ok = false;
      if(!Strategy_SaveValue(StringFormat("rp%d", i), g_reuse_pivots[i])) ok = false;
     }
   if(ok)
      ok = Strategy_SaveValue("ready", 1.0);
   GlobalVariablesFlush();
   if(!ok)
      QM_LogEvent(QM_ERROR, "STATE_PERSIST_FAILED", "{\"ea_id\":1407}");
   return ok;
  }

bool Strategy_LoadState()
  {
   Strategy_ResetActiveMemory();
   g_reuse_time = 0;
   g_reuse_count = 0;
   for(int i = 0; i < ST_MAX_PIVOTS; ++i)
      g_reuse_pivots[i] = 0;
   if(Strategy_LoadValue("ready", 0.0) < 0.5 ||
      (int)MathRound(Strategy_LoadValue("ver", 0.0)) != ST_STATE_VERSION)
      return false;
   g_state_valid = (Strategy_LoadValue("valid", 0.0) > 0.5);
   g_lifecycle = (int)MathRound(Strategy_LoadValue("phase", 0.0));
   g_setup_time = (datetime)MathRound(Strategy_LoadValue("setup", 0.0));
   g_anchor_time = (datetime)MathRound(Strategy_LoadValue("anchor", 0.0));
   g_apex_time = (datetime)MathRound(Strategy_LoadValue("apex", 0.0));
   g_supply_anchor = Strategy_LoadValue("sup0", 0.0);
   g_demand_anchor = Strategy_LoadValue("dem0", 0.0);
   g_supply_slope = Strategy_LoadValue("sups", 0.0);
   g_demand_slope = Strategy_LoadValue("dems", 0.0);
   g_active_count = MathMax(0, MathMin((int)MathRound(Strategy_LoadValue("ac", 0.0)), ST_MAX_PIVOTS));
   g_reuse_time = (datetime)MathRound(Strategy_LoadValue("reuse_t", 0.0));
   g_reuse_count = MathMax(0, MathMin((int)MathRound(Strategy_LoadValue("rc", 0.0)), ST_MAX_PIVOTS));
   g_tp1_partial_done = (Strategy_LoadValue("tp1p", 0.0) > 0.5);
   g_tp1_break_even_done = (Strategy_LoadValue("tp1b", 0.0) > 0.5);
   for(int i = 0; i < ST_MAX_PIVOTS; ++i)
     {
      g_active_pivots[i] = (datetime)MathRound(Strategy_LoadValue(StringFormat("ap%d", i), 0.0));
      g_reuse_pivots[i] = (datetime)MathRound(Strategy_LoadValue(StringFormat("rp%d", i), 0.0));
     }
   if(g_lifecycle < ST_NONE || g_lifecycle > ST_POSITION)
     {
      Strategy_ResetActiveMemory();
      return false;
     }
   return true;
  }

bool Strategy_IsPendingStop(const ENUM_ORDER_TYPE type)
  {
   return (type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP);
  }

bool Strategy_SelectOurPosition(ulong &ticket, ENUM_POSITION_TYPE &type)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      ticket = candidate;
      type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }
   ticket = 0;
   return false;
  }

int Strategy_PendingCount()
  {
   const int magic = QM_FrameworkMagic();
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) == _Symbol &&
         (int)OrderGetInteger(ORDER_MAGIC) == magic &&
         Strategy_IsPendingStop((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         ++count;
     }
   return count;
  }

bool Strategy_RemovePending(const string reason)
  {
   bool all_ok = true;
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol ||
         (int)OrderGetInteger(ORDER_MAGIC) != magic ||
         !Strategy_IsPendingStop((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;
      if(!QM_TM_RemovePendingOrder(ticket, reason))
         all_ok = false;
     }
   return all_ok;
  }

bool Strategy_LoadRates(MqlRates &rates[])
  {
   ArrayResize(rates, 0);
   ArraySetAsSeries(rates, true);
   const int wing = MathMax(1, strategy_fractal_wing_bars);
   const int requested = MathMin(260, MathMax(strategy_pivot_scan_bars, strategy_pattern_max_bars) + wing + 2);
   const int copied = CopyRates(_Symbol, strategy_tf, 0, requested, rates); // perf-allowed: bounded card lookback, once per H4 entry/revalidation.
   const int size = ArraySize(rates);
   const int minimum = strategy_pattern_min_bars + 2 * wing + 2;
   return (copied >= minimum && size >= copied && size >= minimum);
  }

void Strategy_FindFractals(const MqlRates &rates[], StrategyPivot &highs[], StrategyPivot &lows[])
  {
   ArrayResize(highs, 0);
   ArrayResize(lows, 0);
   const int size = ArraySize(rates);
   const int wing = MathMax(1, strategy_fractal_wing_bars);
   const int last = MathMin(MathMin(strategy_pivot_scan_bars, 250), size - wing - 1);
   for(int shift = wing + 1; shift <= last; ++shift)
     {
      if(shift - wing < 0 || shift + wing >= size)
         continue;
      bool high = (rates[shift].high > 0.0);
      bool low = (rates[shift].low > 0.0);
      for(int side = 1; side <= wing; ++side)
        {
         if(rates[shift].high <= rates[shift - side].high || rates[shift].high <= rates[shift + side].high) high = false;
         if(rates[shift].low >= rates[shift - side].low || rates[shift].low >= rates[shift + side].low) low = false;
        }
      if(high)
        {
         const int count = ArraySize(highs);
         ArrayResize(highs, count + 1);
         highs[count].shift = shift;
         highs[count].price = rates[shift].high;
         highs[count].time = rates[shift].time;
        }
      if(low)
        {
         const int count = ArraySize(lows);
         ArrayResize(lows, count + 1);
         lows[count].shift = shift;
         lows[count].price = rates[shift].low;
         lows[count].time = rates[shift].time;
        }
     }
  }

bool Strategy_Regression(const StrategyPivot &pivots[], const int reference,
                         double &slope, double &intercept)
  {
   const int count = ArraySize(pivots);
   if(count < 2)
      return false;
   double sx = 0.0, sy = 0.0, sxx = 0.0, sxy = 0.0;
   for(int i = 0; i < count; ++i)
     {
      const double x = reference - pivots[i].shift;
      sx += x;
      sy += pivots[i].price;
      sxx += x * x;
      sxy += x * pivots[i].price;
     }
   const double denominator = count * sxx - sx * sx;
   if(MathAbs(denominator) <= 1e-12)
      return false;
   slope = (count * sxy - sx * sy) / denominator;
   intercept = (sy - slope * sx) / count;
   return true;
  }

bool Strategy_FindPattern(const MqlRates &rates[], const double atr_h4,
                          const double atr_d1, SymmetricTrianglePattern &pat)
  {
   ZeroMemory(pat);
   const int rates_size = ArraySize(rates);
   if(atr_h4 <= 0.0 || atr_d1 <= 0.0 || rates_size < strategy_pattern_min_bars + 4)
      return false;
   StrategyPivot highs[], lows[];
   Strategy_FindFractals(rates, highs, lows);
   const int high_size = ArraySize(highs);
   const int low_size = ArraySize(lows);
   if(high_size < strategy_min_high_pivots || low_size < strategy_min_low_pivots)
      return false;
   const int max_h = MathMin(MathMin(high_size, ST_MAX_SIDE_PIVOTS), strategy_min_high_pivots + 3);
   const int max_l = MathMin(MathMin(low_size, ST_MAX_SIDE_PIVOTS), strategy_min_low_pivots + 3);
   for(int hc = strategy_min_high_pivots; hc <= max_h; ++hc)
     {
      for(int lc = strategy_min_low_pivots; lc <= max_l; ++lc)
        {
         StrategyPivot ph[], pl[];
         ArrayResize(ph, hc);
         ArrayResize(pl, lc);
         if(ArraySize(ph) < hc || ArraySize(pl) < lc)
            continue;
         for(int i = 0; i < hc; ++i) ph[i] = highs[i];
         for(int i = 0; i < lc; ++i) pl[i] = lows[i];
         bool descending = true, ascending = true;
         for(int i = 1; i < hc; ++i)
            if(ph[i - 1].price > ph[i].price + strategy_boundary_buffer_atr * atr_h4) descending = false;
         for(int i = 1; i < lc; ++i)
            if(pl[i - 1].price < pl[i].price - strategy_boundary_buffer_atr * atr_h4) ascending = false;
         if(!descending || !ascending)
            continue;
         const int reference = MathMax(ph[hc - 1].shift, pl[lc - 1].shift);
         const int length = reference - 1;
         if(length < strategy_pattern_min_bars || length > strategy_pattern_max_bars || reference >= rates_size)
            continue;
         double ss = 0.0, si = 0.0, ds = 0.0, di = 0.0;
         if(!Strategy_Regression(ph, reference, ss, si) || !Strategy_Regression(pl, reference, ds, di))
            continue;
         const double scale = atr_d1 / 50.0;
         if(scale <= 0.0 || ss > -strategy_slope_min_atr_factor * scale ||
            ss < -strategy_slope_max_atr_factor * scale ||
            ds < strategy_slope_min_atr_factor * scale || ds > strategy_slope_max_atr_factor * scale)
            continue;
         const double slope_sum = MathAbs(ss) + MathAbs(ds);
         if(slope_sum <= 0.0 || MathAbs(ss + ds) / slope_sum > strategy_slope_symmetry_ratio)
            continue;
         double highest = -DBL_MAX, lowest = DBL_MAX;
         for(int shift = 1; shift <= reference; ++shift)
           {
            if(shift < 0 || shift >= rates_size) continue;
            highest = MathMax(highest, rates[shift].high);
            lowest = MathMin(lowest, rates[shift].low);
           }
         if(lowest <= 0.0 || highest - lowest < strategy_min_amplitude_atr * atr_h4)
            continue;
         const double apex_denominator = ds - ss;
         if(apex_denominator <= 1e-12)
            continue;
         const double apex_shift = reference - (si - di) / apex_denominator;
         // Shift 0 is current: zero/positive is already at-or-beyond the apex.
         if(apex_shift >= 0.0 || apex_shift < -strategy_apex_max_extension_pct * length)
            continue;
         bool prior_break = false;
         for(int shift = 2; shift <= reference; ++shift)
           {
            if(shift < 0 || shift >= rates_size) continue;
            const double x = reference - shift;
            if(rates[shift].close > si + ss * x + strategy_boundary_buffer_atr * atr_h4 ||
               rates[shift].close < di + ds * x - strategy_boundary_buffer_atr * atr_h4)
               prior_break = true;
           }
         if(prior_break)
            continue;
         pat.reference_shift = reference;
         pat.highest_high = highest;
         pat.lowest_low = lowest;
         pat.supply_slope = ss;
         pat.demand_slope = ds;
         pat.supply_at_anchor = si + ss * reference;
         pat.demand_at_anchor = di + ds * reference;
         pat.apex_shift = apex_shift;
         pat.anchor_time = rates[0].time;
         pat.apex_time = (datetime)((long)rates[0].time + (long)MathCeil(-apex_shift * Strategy_PeriodSeconds()));
         pat.high_count = hc;
         pat.low_count = lc;
         for(int i = 0; i < hc && i < ST_MAX_SIDE_PIVOTS; ++i) pat.high_times[i] = ph[i].time;
         for(int i = 0; i < lc && i < ST_MAX_SIDE_PIVOTS; ++i) pat.low_times[i] = pl[i].time;
         return true;
        }
     }
   return false;
  }

bool Strategy_PatternHasTime(const SymmetricTrianglePattern &pat, const datetime value)
  {
   for(int i = 0; i < pat.high_count && i < ST_MAX_SIDE_PIVOTS; ++i)
      if(pat.high_times[i] == value) return true;
   for(int i = 0; i < pat.low_count && i < ST_MAX_SIDE_PIVOTS; ++i)
      if(pat.low_times[i] == value) return true;
   return false;
  }

double Strategy_Overlap(const SymmetricTrianglePattern &pat, const datetime &pivots[], const int count)
  {
   const int denominator = MathMin(pat.high_count, ST_MAX_SIDE_PIVOTS) + MathMin(pat.low_count, ST_MAX_SIDE_PIVOTS);
   if(denominator <= 0)
      return 0.0;
   int shared = 0;
   const int pivot_size = ArraySize(pivots);
   for(int i = 0; i < count && i < pivot_size; ++i)
      if(Strategy_PatternHasTime(pat, pivots[i])) ++shared;
   return (double)shared / denominator;
  }

bool Strategy_ReuseBlocks(const SymmetricTrianglePattern &pat)
  {
   if(strategy_reuse_guard_bars <= 0 || g_reuse_time <= 0 || g_reuse_count <= 0)
      return false;
   if(TimeCurrent() >= g_reuse_time + (long)strategy_reuse_guard_bars * Strategy_PeriodSeconds())
      return false;
   return (Strategy_Overlap(pat, g_reuse_pivots, g_reuse_count) > strategy_reuse_overlap_ratio);
  }

void Strategy_RecordReuse(const datetime event_time)
  {
   if(!g_state_valid || g_active_count <= 0)
      return;
   g_reuse_time = (event_time > 0) ? event_time : TimeCurrent();
   g_reuse_count = MathMin(g_active_count, ST_MAX_PIVOTS);
   for(int i = 0; i < ST_MAX_PIVOTS; ++i)
      g_reuse_pivots[i] = (i < g_reuse_count) ? g_active_pivots[i] : 0;
  }

void Strategy_ClearActive()
  {
   Strategy_ResetActiveMemory();
   Strategy_PersistState();
  }

void Strategy_Invalidate(const string reason)
  {
   Strategy_RemovePending(reason);
   Strategy_RecordReuse(TimeCurrent());
   Strategy_ClearActive();
   QM_LogEvent(QM_INFO, "PATTERN_INVALIDATED", StringFormat("{\"reason\":\"%s\"}", QM_LoggerEscapeJson(reason)));
  }

void Strategy_CommitPattern(const SymmetricTrianglePattern &pat)
  {
   Strategy_ResetActiveMemory();
   g_state_valid = true;
   g_lifecycle = ST_PENDING;
   g_setup_time = pat.anchor_time;
   g_anchor_time = pat.anchor_time;
   g_apex_time = pat.apex_time;
   g_supply_anchor = pat.supply_at_anchor;
   g_demand_anchor = pat.demand_at_anchor;
   g_supply_slope = pat.supply_slope;
   g_demand_slope = pat.demand_slope;
   int index = 0;
   for(int i = 0; i < pat.high_count && i < ST_MAX_SIDE_PIVOTS; ++i) g_active_pivots[index++] = pat.high_times[i];
   for(int i = 0; i < pat.low_count && i < ST_MAX_SIDE_PIVOTS && index < ST_MAX_PIVOTS; ++i) g_active_pivots[index++] = pat.low_times[i];
   g_active_count = index;
   Strategy_PersistState();
  }

bool Strategy_SpreadAllows(const double atr)
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   return (atr > 0.0 && strategy_spread_max_atr > 0.0 && ask > bid &&
           ask - bid <= strategy_spread_max_atr * atr);
  }

bool Strategy_EntryNewsAllows(const datetime broker_time)
  {
   datetime utc = QM_BrokerToUTC(broker_time);
   if(utc <= 0) utc = TimeGMT();
   if(utc <= 0) return false;
   if(QM_NewsInWindow(utc, _Symbol, 480, 480, qm_news_min_impact)) return false;
   if(qm_news_compliance != QM_NEWS_COMPLIANCE_NONE &&
      !QM_NewsComplianceAllows(_Symbol, utc, qm_news_compliance)) return false;
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   return (_Period != strategy_tf || strategy_tf != PERIOD_H4 ||
           strategy_atr_period < 2 || strategy_fractal_wing_bars != 2 ||
           strategy_pivot_scan_bars < strategy_pattern_max_bars ||
           strategy_pattern_min_bars < 10 || strategy_pattern_max_bars < strategy_pattern_min_bars ||
           strategy_min_high_pivots < 3 || strategy_min_high_pivots > ST_MAX_SIDE_PIVOTS ||
           strategy_min_low_pivots < 3 || strategy_min_low_pivots > ST_MAX_SIDE_PIVOTS ||
           strategy_slope_min_atr_factor <= 0.0 || strategy_slope_max_atr_factor < strategy_slope_min_atr_factor ||
           strategy_slope_symmetry_ratio < 0.0 || strategy_slope_symmetry_ratio > 1.0 ||
           strategy_min_amplitude_atr <= 0.0 || strategy_apex_max_extension_pct <= 0.0 ||
           strategy_boundary_buffer_atr < 0.0 || strategy_breakout_buffer_atr <= 0.0 ||
           strategy_sl_buffer_atr < 0.0 || strategy_sl_cap_atr <= 0.0 ||
           strategy_tp1_ratio <= 0.0 || strategy_tp1_ratio >= 1.0 ||
           strategy_time_stop_bars <= 0 || strategy_pending_lifetime_bars <= 0 ||
           strategy_reuse_guard_bars < 0 || strategy_reuse_overlap_ratio < 0.0 ||
           strategy_reuse_overlap_ratio > 1.0 || strategy_spread_max_atr <= 0.0);
  }

void Strategy_InitRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = strategy_pending_lifetime_bars * Strategy_PeriodSeconds();
  }

bool Strategy_EntrySignal(QM_EntryRequest &sell_request)
  {
   Strategy_InitRequest(sell_request);
   ulong position = 0;
   ENUM_POSITION_TYPE type = POSITION_TYPE_BUY;
   if(Strategy_SelectOurPosition(position, type) || Strategy_PendingCount() > 0 || g_state_valid)
      return false;
   const double atr_h4 = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(!Strategy_SpreadAllows(atr_h4)) return false;
   MqlRates rates[];
   if(!Strategy_LoadRates(rates) || ArraySize(rates) < 2) return false;
   SymmetricTrianglePattern pat;
   if(!Strategy_FindPattern(rates, atr_h4, atr_d1, pat) || Strategy_ReuseBlocks(pat)) return false;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double height = pat.highest_high - pat.lowest_low;
   const double buy_entry = Strategy_NormalizePrice(pat.supply_at_anchor + strategy_breakout_buffer_atr * atr_h4);
   const double sell_entry = Strategy_NormalizePrice(pat.demand_at_anchor - strategy_breakout_buffer_atr * atr_h4);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0 || height <= 0.0 ||
      buy_entry <= ask + point || sell_entry >= bid - point || buy_entry <= sell_entry) return false;
   const double buy_sl = Strategy_NormalizePrice(MathMax(pat.lowest_low - strategy_sl_buffer_atr * atr_h4,
                                                          buy_entry - strategy_sl_cap_atr * atr_h4));
   const double sell_sl = Strategy_NormalizePrice(MathMin(pat.highest_high + strategy_sl_buffer_atr * atr_h4,
                                                           sell_entry + strategy_sl_cap_atr * atr_h4));
   const double buy_tp = Strategy_NormalizePrice(buy_entry + height);
   const double sell_tp = Strategy_NormalizePrice(sell_entry - height);
   if(buy_sl <= 0.0 || buy_sl >= buy_entry || buy_tp <= buy_entry ||
      sell_sl <= sell_entry || sell_tp <= 0.0 || sell_tp >= sell_entry) return false;
   QM_EntryRequest buy_request;
   ZeroMemory(buy_request);
   Strategy_InitRequest(buy_request);
   buy_request.type = QM_BUY_STOP;
   buy_request.price = buy_entry;
   buy_request.sl = buy_sl;
   buy_request.tp = buy_tp;
   buy_request.reason = "SYMMETRIC_TRIANGLE_BUY_STOP";
   sell_request.type = QM_SELL_STOP;
   sell_request.price = sell_entry;
   sell_request.sl = sell_sl;
   sell_request.tp = sell_tp;
   sell_request.reason = "SYMMETRIC_TRIANGLE_SELL_STOP";
   ulong buy_ticket = 0;
   if(!QM_TM_OpenPosition(buy_request, buy_ticket)) return false;
   Strategy_CommitPattern(pat);
   return true;
  }

void Strategy_ReconcileTp1(const ulong ticket)
  {
   if(!PositionSelectByTicket(ticket)) return;
   const double open = PositionGetDouble(POSITION_PRICE_OPEN);
   const double sl = PositionGetDouble(POSITION_SL);
   const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(sl > 0.0 && ((type == POSITION_TYPE_BUY && sl >= open - point * 0.5) ||
                   (type == POSITION_TYPE_SELL && sl <= open + point * 0.5)))
      g_tp1_break_even_done = true;
   const ulong position_id = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
   const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
   if(position_id == 0 || opened <= 0 || !HistorySelect(opened, TimeCurrent())) return;
   const int magic = QM_FrameworkMagic();
   for(int i = HistoryDealsTotal() - 1; i >= 0; --i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0 || (ulong)HistoryDealGetInteger(deal, DEAL_POSITION_ID) != position_id ||
         (int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic) continue;
      const ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT) { g_tp1_partial_done = true; break; }
     }
  }

void Strategy_ManageOpenPosition()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE type = POSITION_TYPE_BUY;
   if(!Strategy_SelectOurPosition(ticket, type)) return;
   Strategy_RemovePending("oco_opposite_after_first_fill");
   if(!g_state_valid) { g_restart_state_missing = true; return; }
   if(g_lifecycle != ST_POSITION)
     {
      g_lifecycle = ST_POSITION;
      Strategy_RecordReuse((datetime)PositionGetInteger(POSITION_TIME));
      Strategy_ReconcileTp1(ticket);
      Strategy_PersistState();
     }
   if(!PositionSelectByTicket(ticket)) return;
   const bool buy = (type == POSITION_TYPE_BUY);
   const double open = PositionGetDouble(POSITION_PRICE_OPEN);
   const double tp = PositionGetDouble(POSITION_TP);
   const double market = buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double volume = PositionGetDouble(POSITION_VOLUME);
   if(open <= 0.0 || tp <= 0.0 || market <= 0.0 || volume <= 0.0) return;
   const double tp1 = buy ? open + strategy_tp1_ratio * (tp - open)
                          : open - strategy_tp1_ratio * (open - tp);
   if(buy ? market < tp1 : market > tp1) return;
   if(!g_tp1_partial_done)
     {
      const double lots = QM_TM_NormalizeVolume(_Symbol, volume * strategy_tp1_ratio);
      if(lots > 0.0 && lots < volume && QM_TM_PartialClose(ticket, lots, QM_EXIT_PARTIAL))
        { g_tp1_partial_done = true; Strategy_PersistState(); }
     }
   if(!g_tp1_break_even_done && PositionSelectByTicket(ticket) &&
      QM_TM_MoveSL(ticket, Strategy_NormalizePrice(open), "triangle_tp1_break_even"))
     { g_tp1_break_even_done = true; Strategy_PersistState(); }
  }

void Strategy_ManagePending(const bool new_bar)
  {
   ulong position = 0;
   ENUM_POSITION_TYPE type = POSITION_TYPE_BUY;
   if(Strategy_SelectOurPosition(position, type)) return;
   const int count = Strategy_PendingCount();
   if(count <= 0)
     {
      if(g_state_valid && g_lifecycle == ST_PENDING) Strategy_Invalidate("pending_bracket_missing_or_expired");
      else if(g_state_valid && g_lifecycle == ST_POSITION) Strategy_ClearActive();
      return;
     }
   if(!g_state_valid || g_lifecycle != ST_PENDING) { Strategy_RemovePending("orphan_pending_without_state"); return; }
   if(count != 2) { Strategy_Invalidate("incomplete_oco_bracket"); return; }
   if(g_setup_time <= 0 || TimeCurrent() >= g_setup_time + (long)strategy_pending_lifetime_bars * Strategy_PeriodSeconds())
     { Strategy_Invalidate("twelve_h4_bar_expiry"); return; }
   if(!new_bar) return;
   MqlRates rates[];
   if(!Strategy_LoadRates(rates) || ArraySize(rates) < 2) return;
   if(g_apex_time <= 0 || rates[0].time >= g_apex_time)
     { Strategy_Invalidate("apex_at_or_behind_current_bar"); return; }
   const double atr_h4 = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   SymmetricTrianglePattern current;
   if(!Strategy_FindPattern(rates, atr_h4, atr_d1, current) ||
      Strategy_Overlap(current, g_active_pivots, g_active_count) <= strategy_reuse_overlap_ratio)
      Strategy_Invalidate("per_bar_structural_revalidation_failed");
  }

double Strategy_ProjectedLine(const bool supply, const datetime evaluation)
  {
   if(!g_state_valid || g_anchor_time <= 0 || evaluation < g_anchor_time) return 0.0;
   const double elapsed = (double)(evaluation - g_anchor_time) / Strategy_PeriodSeconds();
   return supply ? g_supply_anchor + g_supply_slope * elapsed
                 : g_demand_anchor + g_demand_slope * elapsed;
  }

bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE type = POSITION_TYPE_BUY;
   if(!Strategy_SelectOurPosition(ticket, type)) return false;
   if(g_restart_state_missing || !g_state_valid)
     { QM_LogEvent(QM_ERROR, "RESTART_STATE_MISSING", "{\"action\":\"fail_closed_exit\"}"); return true; }
   if(!PositionSelectByTicket(ticket)) return false;
   const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
   const int bars = iBarShift(_Symbol, strategy_tf, opened, false); // perf-allowed: one position-age query per new H4 exit check.
   if(bars >= strategy_time_stop_bars) return true;
   MqlRates closed[];
   ArraySetAsSeries(closed, true);
   const int copied = CopyRates(_Symbol, strategy_tf, 1, 1, closed); // perf-allowed: one closed H4 bar per new-bar exit check.
   if(copied < 1 || ArraySize(closed) < 1) return false;
   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   if(atr <= 0.0 || closed[0].close <= 0.0) return false;
   if(type == POSITION_TYPE_BUY)
     {
      const double line = Strategy_ProjectedLine(true, closed[0].time);
      return (line > 0.0 && closed[0].close < line + strategy_boundary_buffer_atr * atr);
     }
   const double line = Strategy_ProjectedLine(false, closed[0].time);
   return (line > 0.0 && closed[0].close > line - strategy_boundary_buffer_atr * atr);
  }

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED,
                        PORTFOLIO_WEIGHT, qm_news_mode_legacy,
                        qm_friday_close_enabled, qm_friday_close_hour_broker,
                        480, 480, qm_news_stale_max_hours,
                        qm_news_min_impact, qm_rng_seed, qm_stress_reject_probability,
                        qm_news_temporal, qm_news_compliance)) return INIT_FAILED;
   g_state_prefix = StringFormat("QM5.1407.%I64d.%d.", AccountInfoInteger(ACCOUNT_LOGIN), QM_FrameworkMagic());
   const bool loaded = Strategy_LoadState();
   ulong position = 0;
   ENUM_POSITION_TYPE type = POSITION_TYPE_BUY;
   const bool has_position = Strategy_SelectOurPosition(position, type);
   const int pending = Strategy_PendingCount();
   if(has_position && (!loaded || !g_state_valid))
     { g_restart_state_missing = true; QM_LogEvent(QM_ERROR, "RESTART_STATE_MISSING", "{\"object\":\"position\"}"); }
   else if(pending > 0 && (!loaded || !g_state_valid)) Strategy_RemovePending("restart_orphan_pending_without_state");
   else if(!has_position && pending == 0 && g_state_valid)
     { if(g_lifecycle == ST_PENDING) Strategy_RecordReuse(TimeCurrent()); Strategy_ClearActive(); }
   else if(has_position)
     { g_lifecycle = ST_POSITION; Strategy_ReconcileTp1(position); Strategy_PersistState(); }
   else if(!loaded) Strategy_PersistState();
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1407\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   Strategy_PersistState();
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   QM_FrameworkTrackOpenPositionMae();
   if(!QM_KillSwitchCheck() || QM_FrameworkHandleFridayClose()) return;
   const bool new_bar = QM_IsNewBar(_Symbol, strategy_tf);
   Strategy_ManagePending(new_bar);
   Strategy_ManageOpenPosition();
   if(new_bar && Strategy_ExitSignal())
     {
      ulong ticket = 0;
      ENUM_POSITION_TYPE type = POSITION_TYPE_BUY;
      if(Strategy_SelectOurPosition(ticket, type)) QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      return;
     }
   if(!new_bar) return;
   QM_EquityStreamOnNewBar();
   if(Strategy_NoTradeFilter() || !Strategy_EntryNewsAllows(TimeCurrent())) return;
   QM_EntryRequest sell_request;
   ZeroMemory(sell_request);
   Strategy_InitRequest(sell_request);
   if(Strategy_EntrySignal(sell_request))
     {
      ulong sell_ticket = 0;
      if(!QM_TM_OpenPosition(sell_request, sell_ticket)) Strategy_Invalidate("oco_second_leg_rejected");
     }
  }

void OnTimer() { QM_FrameworkOnTimer(); }

void OnTradeTransaction(const MqlTradeTransaction &transaction,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   QM_FrameworkOnTradeTransaction(transaction, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
