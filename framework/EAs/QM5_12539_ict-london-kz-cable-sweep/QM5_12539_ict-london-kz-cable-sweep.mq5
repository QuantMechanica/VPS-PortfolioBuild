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

bool Strategy_AsiaRange(const int day_key, double &asia_high, double &asia_low)
  {
   asia_high = 0.0;
   asia_low = DBL_MAX;

   MqlRates m15[];
   if(!Strategy_LoadRates(PERIOD_M15, 1, 128, m15))
      return false;

   for(int i = 0; i < ArraySize(m15); ++i)
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

bool Strategy_M15PivotPools(const double reference_price,
                            double &nearest_high_above,
                            double &nearest_low_below)
  {
   nearest_high_above = DBL_MAX;
   nearest_low_below = 0.0;

   MqlRates m15[];
   const int bars_needed = MathMax(16, strategy_pivot_h1_bars * 4 + 4);
   if(!Strategy_LoadRates(PERIOD_M15, 1, bars_needed, m15))
      return false;

   for(int i = 1; i < ArraySize(m15) - 1; ++i)
     {
      const bool pivot_high = (m15[i].high > m15[i - 1].high && m15[i].high > m15[i + 1].high);
      const bool pivot_low = (m15[i].low < m15[i - 1].low && m15[i].low < m15[i + 1].low);
      if(pivot_high && m15[i].high > reference_price && m15[i].high < nearest_high_above)
         nearest_high_above = m15[i].high;
      if(pivot_low && m15[i].low < reference_price && m15[i].low > nearest_low_below)
         nearest_low_below = m15[i].low;
     }
   return true;
  }

bool Strategy_LiquidityPools(const double reference_price,
                             const int day_key,
                             double &pool_below,
                             double &pool_above)
  {
   pool_below = 0.0;
   pool_above = DBL_MAX;

   double pdh, pdl;
   if(Strategy_PreviousDayLevels(pdh, pdl))
     {
      if(pdl < reference_price)
         pool_below = MathMax(pool_below, pdl);
      if(pdh > reference_price)
         pool_above = MathMin(pool_above, pdh);
     }

   double asia_high, asia_low;
   if(Strategy_AsiaRange(day_key, asia_high, asia_low))
     {
      if(asia_low < reference_price)
         pool_below = MathMax(pool_below, asia_low);
      if(asia_high > reference_price)
         pool_above = MathMin(pool_above, asia_high);
     }

   double pivot_high, pivot_low;
   if(Strategy_M15PivotPools(reference_price, pivot_high, pivot_low))
     {
      if(pivot_low > 0.0)
         pool_below = MathMax(pool_below, pivot_low);
      if(pivot_high < DBL_MAX)
         pool_above = MathMin(pool_above, pivot_high);
     }

   return (pool_below > 0.0 || pool_above < DBL_MAX);
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
                               const double pool_below,
                               int &sweep_shift,
                               double &sweep_extreme,
                               double &fvg_mid)
  {
   sweep_shift = -1;
   sweep_extreme = 0.0;
   fvg_mid = 0.0;
   if(pool_below <= 0.0)
      return false;

   for(int s = 2; s <= strategy_mss_max_bars && s < ArraySize(m15); ++s)
     {
      if(!Strategy_InLondonKillzone(m15[s].time))
         continue;
      if(m15[s].low < pool_below && m15[s].close > pool_below)
        {
         sweep_shift = s;
         sweep_extreme = m15[s].low;
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
                               const double pool_above,
                               int &sweep_shift,
                               double &sweep_extreme,
                               double &fvg_mid)
  {
   sweep_shift = -1;
   sweep_extreme = 0.0;
   fvg_mid = 0.0;
   if(pool_above >= DBL_MAX)
      return false;

   for(int s = 2; s <= strategy_mss_max_bars && s < ArraySize(m15); ++s)
     {
      if(!Strategy_InLondonKillzone(m15[s].time))
         continue;
      if(m15[s].high > pool_above && m15[s].close < pool_above)
        {
         sweep_shift = s;
         sweep_extreme = m15[s].high;
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
   if(!Strategy_LoadRates(PERIOD_M15, 1, MathMax(128, strategy_m15_pivot_lookback + strategy_mss_max_bars + 8), m15))
      return false;

   if(!Strategy_InLondonKillzone(m15[0].time))
      return false;

   const int day_key = Strategy_DayKey(m15[0].time);
   const datetime broker_now = TimeCurrent();
   if(Strategy_DayKey(broker_now) != day_key || Strategy_DailyEntryLocked(broker_now))
      return false;

   double pool_below, pool_above;
   if(!Strategy_LiquidityPools(m15[0].close, day_key, pool_below, pool_above))
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(atr <= 0.0 || !MathIsValidNumber(atr) ||
      tick_size <= 0.0 || !MathIsValidNumber(tick_size))
      return false;

   int sweep_shift = -1;
   double sweep_extreme = 0.0;
   double entry = 0.0;
   bool is_long = false;

   if(Strategy_FindBullishSetup(m15, pool_below, sweep_shift, sweep_extreme, entry))
      is_long = true;
   else if(!Strategy_FindBearishSetup(m15, pool_above, sweep_shift, sweep_extreme, entry))
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
   double raw_tp1 = raw_rr2;
   if(is_long && pool_above < DBL_MAX)
      raw_tp1 = MathMin(pool_above, raw_rr2);
   if(!is_long && pool_below > 0.0)
      raw_tp1 = MathMax(pool_below, raw_rr2);
   if(is_long && raw_tp1 <= entry)
      raw_tp1 = raw_rr2;
   if(!is_long && raw_tp1 >= entry)
      raw_tp1 = raw_rr2;

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
   req.reason = is_long ? "ICT_LONDON_KZ_SWEEP_FVG_LONG" : "ICT_LONDON_KZ_SWEEP_FVG_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = (requested_expiration < (long)killzone_expiration)
                            ? (int)requested_expiration
                            : killzone_expiration;

   g_tp1_price = tp1;
   g_initial_volume = 0.0;
   g_partial_done = false;
   return true;
  }

void Strategy_ManageOpenPosition()
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

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double sl = PositionGetDouble(POSITION_SL);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      if(g_initial_volume <= 0.0)
         g_initial_volume = volume;
      if(volume < g_initial_volume * 0.75)
         g_partial_done = true;
      if(g_partial_done || sl <= 0.0 || open_price <= 0.0)
         continue;

      const bool is_long = (type == POSITION_TYPE_BUY);
      const double risk = MathAbs(open_price - sl);
      if(risk <= 0.0)
         continue;

      double target = g_tp1_price;
      if(target <= 0.0)
         target = is_long ? (open_price + 2.0 * risk) : (open_price - 2.0 * risk);

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
