#property strict
#property version   "5.0"
#property description "QM5_12539 ICT London KZ Cable Sweep"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12539;
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
input int    strategy_atr_period          = 14;
input double strategy_atr_buffer_mult     = 0.30;
input double strategy_max_risk_atr_mult   = 2.50;
input int    strategy_mss_max_bars        = 8;
input int    strategy_order_valid_bars    = 8;
input int    strategy_pivot_h1_bars       = 24;
input int    strategy_m15_pivot_lookback  = 96;
input int    strategy_max_spread_points   = 35;

double   g_tp1_price       = 0.0;
double   g_initial_volume  = 0.0;
bool     g_partial_done    = false;
ulong    g_management_position_id = 0;
bool     g_management_state_ready = false;

int Strategy_DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 1000 + dt.day_of_year;
  }

int Strategy_HHMM(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

bool Strategy_InAsiaRange(const datetime t)
  {
   const int hhmm = Strategy_HHMM(t);
   return (hhmm >= 100 && hhmm < 900);
  }

bool Strategy_InLondonKillzone(const datetime t)
  {
   const int hhmm = Strategy_HHMM(t);
   return (hhmm >= 900 && hhmm < 1200);
  }

datetime Strategy_DayStart(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

int Strategy_SecondsUntilLondonKillzoneEnd(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = 12;
   dt.min = 0;
   dt.sec = 0;
   const datetime killzone_end = StructToTime(dt);
   if(killzone_end <= t)
      return 0;
   return (int)(killzone_end - t);
  }

// Align every executable price to SYMBOL_TRADE_TICK_SIZE before geometry is
// judged. For a buy, floor is conservative for the limit, stop and targets;
// for a sell, ceil is the corresponding conservative direction.
bool Strategy_QuantizeDirectionalPrice(const double raw_price,
                                       const double tick_size,
                                       const int direction,
                                       double &quantized_price)
  {
   quantized_price = 0.0;
   if(raw_price <= 0.0 || !MathIsValidNumber(raw_price) ||
      tick_size <= 0.0 || !MathIsValidNumber(tick_size) ||
      (direction != 1 && direction != -1))
      return false;

   const double tick_units = raw_price / tick_size;
   if(!MathIsValidNumber(tick_units))
      return false;

   const double rounded_units = (direction > 0)
                                ? MathFloor(tick_units + 1e-12)
                                : MathCeil(tick_units - 1e-12);
   const double candidate = NormalizeDouble(rounded_units * tick_size, _Digits);
   if(candidate <= 0.0 || !MathIsValidNumber(candidate))
      return false;

   // QM_Entry formats to digits again. Prove that this value remains both on
   // the executable grid and on the requested conservative side.
   const double candidate_units = candidate / tick_size;
   const double side_tolerance = tick_size * 1e-9;
   if(!MathIsValidNumber(candidate_units) ||
      MathAbs(candidate_units - MathRound(candidate_units)) > 1e-8 ||
      (direction > 0 && candidate > raw_price + side_tolerance) ||
      (direction < 0 && candidate < raw_price - side_tolerance))
      return false;

   quantized_price = candidate;
   return true;
  }

void Strategy_ResetManagementState()
  {
   g_tp1_price = 0.0;
   g_initial_volume = 0.0;
   g_partial_done = false;
   g_management_position_id = 0;
   g_management_state_ready = false;
  }

string Strategy_EntryComment(const bool is_long, const double tp1)
  {
   const string prefix = is_long ? "ICTKZL|T1=" : "ICTKZS|T1=";
   return prefix + DoubleToString(tp1, _Digits);
  }

bool Strategy_ParseTP1Comment(const string comment,
                              const bool is_long,
                              double &tp1)
  {
   tp1 = 0.0;
   const string prefix = is_long ? "ICTKZL|T1=" : "ICTKZS|T1=";
   if(StringFind(comment, prefix) != 0)
      return false;

   const string encoded = StringSubstr(comment, StringLen(prefix));
   const double parsed = StringToDouble(encoded);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(parsed <= 0.0 || !MathIsValidNumber(parsed) ||
      tick_size <= 0.0 || !MathIsValidNumber(tick_size))
      return false;

   const double tick_units = parsed / tick_size;
   if(!MathIsValidNumber(tick_units) ||
      MathAbs(tick_units - MathRound(tick_units)) > 1e-8)
      return false;

   tp1 = NormalizeDouble(parsed, _Digits);
   return true;
  }

bool Strategy_LoadRates(const ENUM_TIMEFRAMES tf,
                        const int start_shift,
                        const int count,
                        MqlRates &rates[])
  {
   ArrayResize(rates, 0);
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, tf, start_shift, count, rates); // perf-allowed: bounded ICT structure/FVG scan, called only from framework closed-bar entry hook.
   return (copied == count);
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool Strategy_HasPendingOrder()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_SELL_LIMIT)
         return true;
     }
   return false;
  }

bool Strategy_IsEntryLimitType(const ENUM_ORDER_TYPE type)
  {
   return (type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_SELL_LIMIT);
  }

// Restart-persistent one-entry-per-broker-day lock. Active exposure is read
// from the live pools; accepted/finished limit orders and filled entries are
// read from terminal history. A history-read failure blocks a new entry.
bool Strategy_DailyEntryLocked(const datetime broker_now)
  {
   if(Strategy_HasOpenPosition() || Strategy_HasPendingOrder())
      return true;

   const int magic = QM_FrameworkMagic();
   const datetime day_start = Strategy_DayStart(broker_now);
   const int day_key = Strategy_DayKey(broker_now);
   if(magic <= 0 || day_start <= 0 || !HistorySelect(day_start, broker_now))
      return true;

   for(int i = HistoryOrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = HistoryOrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(HistoryOrderGetString(ticket, ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)HistoryOrderGetInteger(ticket, ORDER_MAGIC) != magic)
         continue;
      const datetime setup_time = (datetime)HistoryOrderGetInteger(ticket, ORDER_TIME_SETUP);
      if(Strategy_DayKey(setup_time) != day_key)
         continue;
      const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)HistoryOrderGetInteger(ticket, ORDER_TYPE);
      if(Strategy_IsEntryLimitType(type))
         return true;
     }

   for(int i = HistoryDealsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol)
         continue;
      if((int)HistoryDealGetInteger(ticket, DEAL_MAGIC) != magic)
         continue;
      const datetime deal_time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
      if(Strategy_DayKey(deal_time) != day_key)
         continue;
      const ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry == DEAL_ENTRY_IN || entry == DEAL_ENTRY_INOUT)
         return true;
     }

   return false;
  }

bool Strategy_SpreadOK()
  {
   if(strategy_max_spread_points <= 0)
      return true;
   const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread > 0 && spread <= strategy_max_spread_points);
  }

bool Strategy_PreviousDayLevels(double &pdh, double &pdl)
  {
   pdh = 0.0;
   pdl = 0.0;
   MqlRates d1[];
   if(!Strategy_LoadRates(PERIOD_D1, 1, 1, d1))
      return false;
   pdh = d1[0].high;
   pdl = d1[0].low;
   return (pdh > 0.0 && pdl > 0.0);
  }

// Build the Asia range only from bars that were already closed before this
// sweep bar. The array is series-ordered, so strictly older data starts at
// sweep_shift+1; nothing between the sweep and the later MSS is visible here.
bool Strategy_AsiaRangeBeforeSweep(const MqlRates &m15[],
                                   const int sweep_shift,
                                   double &asia_high,
                                   double &asia_low)
  {
   asia_high = 0.0;
   asia_low = DBL_MAX;
   if(sweep_shift < 0 || sweep_shift + 1 >= ArraySize(m15))
      return false;

   const int day_key = Strategy_DayKey(m15[sweep_shift].time);
   for(int i = sweep_shift + 1; i < ArraySize(m15); ++i)
     {
      if(Strategy_DayKey(m15[i].time) != day_key)
         continue;
      if(!Strategy_InAsiaRange(m15[i].time))
         continue;
      asia_high = MathMax(asia_high, m15[i].high);
      asia_low = MathMin(asia_low, m15[i].low);
     }
   return (asia_high > 0.0 && asia_low < DBL_MAX);
  }

// Card pool candidate: the LOWEST confirmed pivot low / HIGHEST confirmed
// pivot high in the preceding 24 H1 = 96 M15 bars (default input). Starting
// at sweep_shift+2 also keeps the pivot's newer confirmation bar strictly
// older than the sweep; a pivot confirmed by the sweep itself is excluded.
bool Strategy_ExtremePivotPoolsBeforeSweep(const MqlRates &m15[],
                                           const int sweep_shift,
                                           double &highest_pivot_high,
                                           double &lowest_pivot_low)
  {
   highest_pivot_high = 0.0;
   lowest_pivot_low = DBL_MAX;
   const int pivot_window_bars = MathMax(4, strategy_pivot_h1_bars * 4);
   const int first_center = sweep_shift + 2;
   const int last_center = MathMin(sweep_shift + pivot_window_bars,
                                   ArraySize(m15) - 2);
   if(first_center > last_center)
      return false;

   for(int i = first_center; i <= last_center; ++i)
     {
      const bool pivot_high = (m15[i].high > m15[i - 1].high &&
                               m15[i].high > m15[i + 1].high);
      const bool pivot_low = (m15[i].low < m15[i - 1].low &&
                              m15[i].low < m15[i + 1].low);
      if(pivot_high)
         highest_pivot_high = MathMax(highest_pivot_high, m15[i].high);
      if(pivot_low)
         lowest_pivot_low = MathMin(lowest_pivot_low, m15[i].low);
     }
   return (highest_pivot_high > 0.0 || lowest_pivot_low < DBL_MAX);
  }

// Freeze both pool classes at the sweep. Entry pools may use the card's
// extreme local pivot; opposite TP1 pools deliberately may NOT. The sweep
// bar open is the causal price reference known before its raid occurs.
bool Strategy_FreezeSweepPools(const MqlRates &m15[],
                               const int sweep_shift,
                               const double pdh,
                               const double pdl,
                               double &entry_pool_below,
                               double &entry_pool_above,
                               double &exit_pool_below,
                               double &exit_pool_above)
  {
   entry_pool_below = 0.0;
   entry_pool_above = DBL_MAX;
   exit_pool_below = 0.0;
   exit_pool_above = DBL_MAX;
   if(sweep_shift < 0 || sweep_shift >= ArraySize(m15))
      return false;

   const double sweep_reference = m15[sweep_shift].open;
   if(sweep_reference <= 0.0 || !MathIsValidNumber(sweep_reference))
      return false;

   double asia_high = 0.0;
   double asia_low = DBL_MAX;
   const bool asia_valid = Strategy_AsiaRangeBeforeSweep(m15,
                                                         sweep_shift,
                                                         asia_high,
                                                         asia_low);

   // PDL/PDH and the completed Asia range serve both as entry liquidity and
   // as the only allowed opposite-pool TP1 candidates.
   if(pdl > 0.0 && pdl < sweep_reference)
     {
      entry_pool_below = MathMax(entry_pool_below, pdl);
      exit_pool_below = MathMax(exit_pool_below, pdl);
     }
   if(pdh > sweep_reference)
     {
      entry_pool_above = MathMin(entry_pool_above, pdh);
      exit_pool_above = MathMin(exit_pool_above, pdh);
     }
   if(asia_valid)
     {
      if(asia_low < sweep_reference)
        {
         entry_pool_below = MathMax(entry_pool_below, asia_low);
         exit_pool_below = MathMax(exit_pool_below, asia_low);
        }
      if(asia_high > sweep_reference)
        {
         entry_pool_above = MathMin(entry_pool_above, asia_high);
         exit_pool_above = MathMin(exit_pool_above, asia_high);
        }
     }

   // The local-pivot candidate participates in ENTRY selection only. Per the
   // card it is the extreme pivot over the window, after which the nearest of
   // Asia / previous-day / extreme-pivot pools is selected around the sweep.
   double highest_pivot_high = 0.0;
   double lowest_pivot_low = DBL_MAX;
   if(Strategy_ExtremePivotPoolsBeforeSweep(m15,
                                            sweep_shift,
                                            highest_pivot_high,
                                            lowest_pivot_low))
     {
      if(lowest_pivot_low < sweep_reference)
         entry_pool_below = MathMax(entry_pool_below, lowest_pivot_low);
      if(highest_pivot_high > sweep_reference)
         entry_pool_above = MathMin(entry_pool_above, highest_pivot_high);
     }

   return (entry_pool_below > 0.0 || entry_pool_above < DBL_MAX);
  }

double Strategy_MostRecentPivotHigh(const MqlRates &rates[])
  {
   const int max_i = MathMin(ArraySize(rates) - 2, strategy_m15_pivot_lookback);
   for(int i = 2; i <= max_i; ++i)
     {
      if(rates[i].high > rates[i - 1].high && rates[i].high > rates[i + 1].high)
         return rates[i].high;
     }
   return 0.0;
  }

double Strategy_MostRecentPivotLow(const MqlRates &rates[])
  {
   const int max_i = MathMin(ArraySize(rates) - 2, strategy_m15_pivot_lookback);
   for(int i = 2; i <= max_i; ++i)
     {
      if(rates[i].low < rates[i - 1].low && rates[i].low < rates[i + 1].low)
         return rates[i].low;
     }
   return 0.0;
  }

bool Strategy_FindBullishSetup(const MqlRates &m15[],
                               const double pdh,
                               const double pdl,
                               int &sweep_shift,
                               double &sweep_extreme,
                               double &fvg_mid,
                               double &opposite_exit_pool)
  {
   sweep_shift = -1;
   sweep_extreme = 0.0;
   fvg_mid = 0.0;
   opposite_exit_pool = 0.0;

   for(int s = 2; s <= strategy_mss_max_bars && s < ArraySize(m15); ++s)
     {
      if(!Strategy_InLondonKillzone(m15[s].time))
         continue;

      double entry_pool_below = 0.0;
      double entry_pool_above = DBL_MAX;
      double exit_pool_below = 0.0;
      double exit_pool_above = DBL_MAX;
      if(!Strategy_FreezeSweepPools(m15,
                                    s,
                                    pdh,
                                    pdl,
                                    entry_pool_below,
                                    entry_pool_above,
                                    exit_pool_below,
                                    exit_pool_above))
         continue;
      if(entry_pool_below <= 0.0 || exit_pool_above >= DBL_MAX)
         continue;

      if(m15[s].low < entry_pool_below && m15[s].close > entry_pool_below)
        {
         sweep_shift = s;
         sweep_extreme = m15[s].low;
         opposite_exit_pool = exit_pool_above;
         break;
        }
     }
   if(sweep_shift < 0)
      return false;

   const double pivot_high = Strategy_MostRecentPivotHigh(m15);
   if(pivot_high <= 0.0 || m15[0].close <= pivot_high)
      return false;

   for(int newer = 0; newer <= sweep_shift - 2; ++newer)
     {
      const int older = newer + 2;
      if(older >= ArraySize(m15))
         continue;
      if(m15[older].high < m15[newer].low)
        {
         fvg_mid = (m15[older].high + m15[newer].low) * 0.5;
         return true;
        }
     }
   return false;
  }

bool Strategy_FindBearishSetup(const MqlRates &m15[],
                               const double pdh,
                               const double pdl,
                               int &sweep_shift,
                               double &sweep_extreme,
                               double &fvg_mid,
                               double &opposite_exit_pool)
  {
   sweep_shift = -1;
   sweep_extreme = 0.0;
   fvg_mid = 0.0;
   opposite_exit_pool = 0.0;

   for(int s = 2; s <= strategy_mss_max_bars && s < ArraySize(m15); ++s)
     {
      if(!Strategy_InLondonKillzone(m15[s].time))
         continue;

      double entry_pool_below = 0.0;
      double entry_pool_above = DBL_MAX;
      double exit_pool_below = 0.0;
      double exit_pool_above = DBL_MAX;
      if(!Strategy_FreezeSweepPools(m15,
                                    s,
                                    pdh,
                                    pdl,
                                    entry_pool_below,
                                    entry_pool_above,
                                    exit_pool_below,
                                    exit_pool_above))
         continue;
      if(entry_pool_above >= DBL_MAX || exit_pool_below <= 0.0)
         continue;

      if(m15[s].high > entry_pool_above && m15[s].close < entry_pool_above)
        {
         sweep_shift = s;
         sweep_extreme = m15[s].high;
         opposite_exit_pool = exit_pool_below;
         break;
        }
     }
   if(sweep_shift < 0)
      return false;

   const double pivot_low = Strategy_MostRecentPivotLow(m15);
   if(pivot_low <= 0.0 || m15[0].close >= pivot_low)
      return false;

   for(int newer = 0; newer <= sweep_shift - 2; ++newer)
     {
      const int older = newer + 2;
      if(older >= ArraySize(m15))
         continue;
      if(m15[older].low > m15[newer].high)
        {
         fvg_mid = (m15[older].low + m15[newer].high) * 0.5;
         return true;
        }
     }
   return false;
  }

bool Strategy_NoTradeFilter()
  {
   if(Strategy_HasOpenPosition() || Strategy_HasPendingOrder())
      return true;
   if(!Strategy_InLondonKillzone(TimeCurrent()))
      return true;
   if(!Strategy_SpreadOK())
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

   if(_Period != PERIOD_M15)
      return false;
   if(!Strategy_SpreadOK())
      return false;
   if(Strategy_HasOpenPosition() || Strategy_HasPendingOrder())
      return false;

   MqlRates m15[];
   const int sweep_pool_bars = MathMax(4, strategy_pivot_h1_bars * 4) +
                               strategy_mss_max_bars + 3;
   const int mss_scan_bars = strategy_m15_pivot_lookback +
                             strategy_mss_max_bars + 8;
   const int bars_needed = MathMax(128, MathMax(sweep_pool_bars, mss_scan_bars));
   if(!Strategy_LoadRates(PERIOD_M15, 1, bars_needed, m15))
      return false;

   if(!Strategy_InLondonKillzone(m15[0].time))
      return false;

   const int day_key = Strategy_DayKey(m15[0].time);
   const datetime broker_now = TimeCurrent();
   if(Strategy_DayKey(broker_now) != day_key || Strategy_DailyEntryLocked(broker_now))
      return false;

   // Previous-day D1 levels were complete before every same-day London sweep.
   // A missing D1 bar does not invent a level; Asia/extreme-pivot entry pools
   // and the Asia opposite target may still form a fully specified setup.
   double pdh = 0.0;
   double pdl = 0.0;
   Strategy_PreviousDayLevels(pdh, pdl);

   const double atr = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(atr <= 0.0 || !MathIsValidNumber(atr) ||
      tick_size <= 0.0 || !MathIsValidNumber(tick_size))
      return false;

   int sweep_shift = -1;
   double sweep_extreme = 0.0;
   double entry = 0.0;
   double opposite_exit_pool = 0.0;
   bool is_long = false;

   if(Strategy_FindBullishSetup(m15,
                                pdh,
                                pdl,
                                sweep_shift,
                                sweep_extreme,
                                entry,
                                opposite_exit_pool))
      is_long = true;
   else if(!Strategy_FindBearishSetup(m15,
                                      pdh,
                                      pdl,
                                      sweep_shift,
                                      sweep_extreme,
                                      entry,
                                      opposite_exit_pool))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const int direction = is_long ? 1 : -1;
   double entry_price = 0.0;
   if(!Strategy_QuantizeDirectionalPrice(entry, tick_size, direction, entry_price))
      return false;
   entry = entry_price;
   if(is_long && entry >= ask)
      return false;
   if(!is_long && entry <= bid)
      return false;

   const double raw_sl = is_long
                         ? (sweep_extreme - atr * strategy_atr_buffer_mult)
                         : (sweep_extreme + atr * strategy_atr_buffer_mult);
   double sl = 0.0;
   if(!Strategy_QuantizeDirectionalPrice(raw_sl, tick_size, direction, sl))
      return false;

   const double risk = MathAbs(entry - sl);
   const bool stop_geometry_valid = is_long ? (sl < entry) : (sl > entry);
   if(!stop_geometry_valid || risk <= 0.0 || risk > atr * strategy_max_risk_atr_mult)
      return false;

   const double raw_rr2 = is_long ? (entry + 2.0 * risk) : (entry - 2.0 * risk);
   const double raw_rr3 = is_long ? (entry + 3.0 * risk) : (entry - 3.0 * risk);
   if(opposite_exit_pool <= 0.0 || !MathIsValidNumber(opposite_exit_pool))
      return false;
   // Card exit: ONLY the frozen opposite Asia/previous-day pool, capped at
   // 2R. There is deliberately no pivot target and no 2R fallback when the
   // opposite pool is no longer beyond the executable entry.
   const double raw_tp1 = is_long
                          ? MathMin(opposite_exit_pool, raw_rr2)
                          : MathMax(opposite_exit_pool, raw_rr2);
   if((is_long && raw_tp1 <= entry) || (!is_long && raw_tp1 >= entry))
      return false;

   double tp1 = 0.0;
   double tp3 = 0.0;
   if(!Strategy_QuantizeDirectionalPrice(raw_tp1, tick_size, direction, tp1) ||
      !Strategy_QuantizeDirectionalPrice(raw_rr3, tick_size, direction, tp3))
      return false;
   const bool target_geometry_valid = is_long
                                      ? (tp1 > entry && tp3 > entry)
                                      : (tp1 < entry && tp3 < entry);
   if(!target_geometry_valid)
      return false;

   const long requested_expiration = (long)strategy_order_valid_bars *
                                     (long)PeriodSeconds(PERIOD_M15);
   const int killzone_expiration = Strategy_SecondsUntilLondonKillzoneEnd(broker_now);
   if(requested_expiration <= 0 || killzone_expiration <= 0)
      return false;

   req.type = is_long ? QM_BUY_LIMIT : QM_SELL_LIMIT;
   req.price = entry;
   req.sl = sl;
   req.tp = tp3;
   req.reason = Strategy_EntryComment(is_long, tp1);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = (requested_expiration < (long)killzone_expiration)
                            ? (int)requested_expiration
                            : killzone_expiration;

   g_tp1_price = tp1;
   g_initial_volume = 0.0;
   g_partial_done = false;
   g_management_position_id = 0;
   g_management_state_ready = false;
   return true;
  }

// Reconstruct every partial-management fact from the live position plus its
// broker/tester position history. Unknown history or a missing persisted TP1
// suppresses the partial fail-closed; it never falls back to a different pool.
bool Strategy_RebuildManagementState(const ulong ticket)
  {
   if(ticket == 0 || !PositionSelectByTicket(ticket))
      return false;

   const int magic = QM_FrameworkMagic();
   if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
      (int)PositionGetInteger(POSITION_MAGIC) != magic)
      return false;

   const ulong position_id = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
   const ENUM_POSITION_TYPE position_type =
      (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const bool is_long = (position_type == POSITION_TYPE_BUY);
   double reconstructed_tp1 = 0.0;
   bool tp1_found = Strategy_ParseTP1Comment(PositionGetString(POSITION_COMMENT),
                                             is_long,
                                             reconstructed_tp1);

   if(position_id == 0 || !HistorySelectByPosition(position_id))
      return false;

   double opening_volume = 0.0;
   double closing_volume = 0.0;
   const int deal_total = HistoryDealsTotal();
   for(int i = 0; i < deal_total; ++i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0 || HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;

      const double deal_volume = HistoryDealGetDouble(deal, DEAL_VOLUME);
      const ENUM_DEAL_ENTRY entry =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry == DEAL_ENTRY_IN || entry == DEAL_ENTRY_INOUT)
        {
         opening_volume += deal_volume;
         if(!tp1_found)
            tp1_found = Strategy_ParseTP1Comment(HistoryDealGetString(deal, DEAL_COMMENT),
                                                 is_long,
                                                 reconstructed_tp1);
         if(!tp1_found)
           {
            const ulong order = (ulong)HistoryDealGetInteger(deal, DEAL_ORDER);
            if(order > 0)
               tp1_found = Strategy_ParseTP1Comment(HistoryOrderGetString(order, ORDER_COMMENT),
                                                    is_long,
                                                    reconstructed_tp1);
           }
        }
      if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY || entry == DEAL_ENTRY_INOUT)
         closing_volume += deal_volume;
     }

   // Some venues do not propagate the pending comment to the position/deal.
   // The original accepted order remains the third deterministic source.
   if(!tp1_found)
     {
      for(int i = HistoryOrdersTotal() - 1; i >= 0; --i)
        {
         const ulong order = HistoryOrderGetTicket(i);
         if(order == 0 || HistoryOrderGetString(order, ORDER_SYMBOL) != _Symbol)
            continue;
         if((int)HistoryOrderGetInteger(order, ORDER_MAGIC) != magic)
            continue;
         const ENUM_ORDER_TYPE order_type =
            (ENUM_ORDER_TYPE)HistoryOrderGetInteger(order, ORDER_TYPE);
         if(!Strategy_IsEntryLimitType(order_type))
            continue;
         if(Strategy_ParseTP1Comment(HistoryOrderGetString(order, ORDER_COMMENT),
                                     is_long,
                                     reconstructed_tp1))
           {
            tp1_found = true;
            break;
           }
        }
     }

   // Defensive reselect: position-history selection must not be allowed to
   // leave stale live-position properties in the management path.
   if(!PositionSelectByTicket(ticket) ||
      (ulong)PositionGetInteger(POSITION_IDENTIFIER) != position_id)
      return false;

   const double current_volume = PositionGetDouble(POSITION_VOLUME);
   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   const double volume_tolerance = MathMax(1e-8, volume_step * 0.25);
   if(opening_volume <= volume_tolerance)
      opening_volume = current_volume + closing_volume;

   const bool target_geometry_valid = is_long
                                      ? (reconstructed_tp1 > open_price)
                                      : (reconstructed_tp1 < open_price);
   if(!tp1_found || !target_geometry_valid ||
      current_volume <= 0.0 || opening_volume + volume_tolerance < current_volume)
      return false;

   g_management_position_id = position_id;
   g_tp1_price = reconstructed_tp1;
   g_initial_volume = opening_volume;
   g_partial_done = (closing_volume > volume_tolerance ||
                     current_volume + volume_tolerance < opening_volume);
   g_management_state_ready = true;
   return true;
  }

bool Strategy_EnsureManagementState(const ulong ticket)
  {
   if(ticket == 0 || !PositionSelectByTicket(ticket))
      return false;

   const ulong position_id = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
   const double current_volume = PositionGetDouble(POSITION_VOLUME);
   if(g_management_state_ready && position_id == g_management_position_id)
     {
      const double volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      const double volume_tolerance = MathMax(1e-8, volume_step * 0.25);
      if(current_volume + volume_tolerance < g_initial_volume)
         g_partial_done = true;
      return true;
     }

   Strategy_ResetManagementState();
   return Strategy_RebuildManagementState(ticket);
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   bool found = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      found = true;
      if(!Strategy_EnsureManagementState(ticket) || !PositionSelectByTicket(ticket))
         continue;

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double sl = PositionGetDouble(POSITION_SL);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      if(g_partial_done || sl <= 0.0 || open_price <= 0.0)
         continue;

      const bool is_long = (type == POSITION_TYPE_BUY);
      const double risk = MathAbs(open_price - sl);
      if(risk <= 0.0)
         continue;

      const double target = g_tp1_price;
      if(target <= 0.0)
         continue;

      const double px = is_long ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(px <= 0.0)
         continue;
      if((is_long && px >= target) || (!is_long && px <= target))
        {
         if(QM_TM_PartialClose(ticket, volume * 0.5, QM_EXIT_PARTIAL))
            g_partial_done = true;
        }
     }

   if(!found)
      Strategy_ResetManagementState();
  }

bool Strategy_ExitSignal()
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
      if(Strategy_HHMM(TimeCurrent()) >= 1700)
         return true;
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
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

   // Module-local only: every init/test run starts empty and reconstructs an
   // existing position from broker history. No Terminal GlobalVariable state.
   Strategy_ResetManagementState();
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12539_ict-london-kz-cable-sweep\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   if(QM_FrameworkHandleFridayClose())
      return;

   // Management and hard exits are safety paths, not entry paths. They must
   // continue through news blackouts and outside the London entry window.
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

   if(Strategy_NoTradeFilter())
      return;

   // News suppresses NEW orders only. QM_Entry repeats the same check at the
   // send boundary, retaining fail-closed protection against an intra-call
   // calendar-state change.
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
