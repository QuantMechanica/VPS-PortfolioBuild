#property strict
#property version   "5.0"
#property description "QM5_10928 Grimes Yo-Yo Level Breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_10928 grimes-yoyo-break
// -----------------------------------------------------------------------------
// Source: Adam H. Grimes, "How to Trade Support and Resistance Levels".
// Mechanic (card QM5_10928_grimes-yoyo-break): on each closed M30 bar, measure a
// 12-bar "yo-yo" compression around a central level (previous-D1 classic pivot).
// If the bars oscillated tightly around that level (>=8 of 12 closes within
// 0.6*ATR(20), >=4 level crossings, 12-bar range <= 2.2*ATR(20)) and the most
// recent closed bar breaks the compression high/low by 0.15*ATR(20), enter in
// the breakout direction at the next bar open. Stop = compression extreme
// +/- 0.2*ATR(20); target = 2.0R; breakeven at 1.0R; time-exit after 16 bars;
// early-exit if a close returns inside the compression band.
//
// Only the five Strategy_* hooks + strategy inputs below are EA-specific. All
// per-tick scaffolding (risk, magic, news, Friday-close, kill-switch) is the
// framework's. Indicator reads go through the pooled QM_* readers; the bounded
// closed-bar structural scans use CopyRates once per new bar (perf-allowed).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10928;
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
input int    strategy_atr_period            = 20;    // ATR(20) on the base TF (card).
input int    strategy_compression_bars      = 12;    // yo-yo window length in M30 bars.
input int    strategy_min_closes_within     = 8;     // >=8 of 12 closes near the level.
input double strategy_within_atr_mult       = 0.60;  // "near" = within 0.6*ATR of level.
input int    strategy_min_crossings         = 4;     // >=4 level crossings in the window.
input double strategy_max_range_atr_mult    = 2.20;  // 12-bar range cap = 2.2*ATR.
input double strategy_breakout_atr_mult     = 0.15;  // break beyond compression by 0.15*ATR.
input double strategy_stop_buffer_atr_mult  = 0.20;  // stop = compression extreme +/- 0.2*ATR.
input double strategy_max_stop_atr_mult     = 3.00;  // reject if stop distance > 3.0*ATR.
input double strategy_target_r_mult         = 2.00;  // target = 2.0R (nearest-level fallback).
input double strategy_breakeven_r_mult      = 1.00;  // move stop to breakeven at 1.0R.
input int    strategy_time_exit_bars        = 16;    // time exit after 16 M30 bars.
input int    strategy_block_final_hours     = 3;     // no entries in final 3h of broker day.
input double strategy_spread_cap_fraction   = 0.08;  // spread cap = 8% of initial stop distance.

// File-scope cache of the compression band that produced the current entry, so
// Strategy_ExitSignal can apply the "close returns inside the band" early exit
// without re-deriving the window. Set when an entry request is built; only read
// while a position is open (guarded by g_yoyo_band_valid).
double g_yoyo_band_low   = 0.0;
double g_yoyo_band_high  = 0.0;
bool   g_yoyo_band_valid = false;

double StrategyNormalizePrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(digits < 0)
      digits = _Digits;
   return NormalizeDouble(price, digits);
  }

void StrategyInitRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool StrategyHasOpenPosition()
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

// Central level = previous completed D1 classic pivot (H+L+C)/3. The card allows
// "previous D1 high/low or a confirmed H1 pivot level"; the D1 pivot is the most
// literal single-value reading that uses the previous D1 high/low. Cross-TF read
// on the SAME symbol, gated by QM_IsNewBar (entry path only).
bool StrategyCentralLevel(double &level)
  {
   level = 0.0;
   MqlRates d1[];
   ArraySetAsSeries(d1, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, 1, d1); // perf-allowed: one prev-D1 bar for the structural pivot level.
   if(copied < 1)
      return false;
   if(d1[0].high <= 0.0 || d1[0].low <= 0.0 || d1[0].close <= 0.0)
      return false;
   level = (d1[0].high + d1[0].low + d1[0].close) / 3.0;
   return (level > 0.0);
  }

bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return true;

   // No entries during the final N hours of the broker day (card filter).
   if(strategy_block_final_hours > 0)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.hour >= (24 - strategy_block_final_hours))
         return true;
     }

   return false;
  }

bool StrategyBuildRequest(const bool want_long,
                          const double comp_high,
                          const double comp_low,
                          const double atr,
                          QM_EntryRequest &req)
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid || atr <= 0.0)
      return false;
   const double spread = ask - bid;

   if(want_long)
     {
      const double entry = ask;
      const double sl = StrategyNormalizePrice(comp_low - strategy_stop_buffer_atr_mult * atr);
      if(sl <= 0.0 || sl >= entry)
         return false;
      const double stop_dist = entry - sl;
      if(stop_dist <= 0.0 || stop_dist > strategy_max_stop_atr_mult * atr)
         return false;
      if(spread > strategy_spread_cap_fraction * stop_dist)
         return false;
      const double tp = StrategyNormalizePrice(entry + strategy_target_r_mult * stop_dist);
      if(tp <= entry)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl;
      req.tp = tp;
      req.reason = "GRIMES_YOYO_BREAK_LONG";
     }
   else
     {
      const double entry = bid;
      const double sl = StrategyNormalizePrice(comp_high + strategy_stop_buffer_atr_mult * atr);
      if(sl <= 0.0 || sl <= entry)
         return false;
      const double stop_dist = sl - entry;
      if(stop_dist <= 0.0 || stop_dist > strategy_max_stop_atr_mult * atr)
         return false;
      if(spread > strategy_spread_cap_fraction * stop_dist)
         return false;
      const double tp = StrategyNormalizePrice(entry - strategy_target_r_mult * stop_dist);
      if(tp <= 0.0 || tp >= entry)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl;
      req.tp = tp;
      req.reason = "GRIMES_YOYO_BREAK_SHORT";
     }

   // Cache the compression band for the early-exit rule (close back inside band).
   g_yoyo_band_low   = comp_low;
   g_yoyo_band_high  = comp_high;
   g_yoyo_band_valid = true;
   return true;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   StrategyInitRequest(req);

   if(StrategyHasOpenPosition())
      return false;
   if(strategy_atr_period < 2 || strategy_compression_bars < 4 ||
      strategy_min_closes_within < 1 || strategy_min_closes_within > strategy_compression_bars ||
      strategy_within_atr_mult <= 0.0 || strategy_min_crossings < 1 ||
      strategy_max_range_atr_mult <= 0.0 || strategy_breakout_atr_mult < 0.0 ||
      strategy_stop_buffer_atr_mult < 0.0 || strategy_max_stop_atr_mult <= 0.0 ||
      strategy_target_r_mult <= 0.0)
      return false;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double atr = QM_ATR(_Symbol, tf, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   double level = 0.0;
   if(!StrategyCentralLevel(level))
      return false;

   // Compression window = the strategy_compression_bars closed bars that PRECEDE
   // the just-closed breakout bar (shift 1). Window occupies shifts [2 .. N+1].
   const int win_first = 2;
   const int win_last  = strategy_compression_bars + 1;
   const int need_bars = win_last + 2;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, tf, 0, need_bars, rates); // perf-allowed: bounded closed-bar scan for the yo-yo compression window.
   if(copied < need_bars)
      return false;

   const double close1 = rates[1].close;
   if(close1 <= 0.0)
      return false;

   const double within_band = strategy_within_atr_mult * atr;
   int    closes_within = 0;
   int    crossings     = 0;
   double comp_high     = -DBL_MAX;
   double comp_low      = DBL_MAX;
   int    prev_sign     = 0;

   for(int s = win_first; s <= win_last; ++s)
     {
      const double c = rates[s].close;
      const double h = rates[s].high;
      const double l = rates[s].low;
      if(c <= 0.0 || h <= 0.0 || l <= 0.0)
         return false;

      comp_high = MathMax(comp_high, h);
      comp_low  = MathMin(comp_low, l);

      if(MathAbs(c - level) <= within_band)
         ++closes_within;

      const double diff = c - level;
      const int sign = (diff > 0.0) ? 1 : ((diff < 0.0) ? -1 : 0);
      if(sign != 0)
        {
         if(prev_sign != 0 && sign != prev_sign)
            ++crossings;
         prev_sign = sign;
        }
     }

   if(comp_high <= 0.0 || comp_low <= 0.0 || comp_high <= comp_low)
      return false;

   const double comp_range = comp_high - comp_low;
   if(comp_range > strategy_max_range_atr_mult * atr)
      return false;
   if(closes_within < strategy_min_closes_within)
      return false;
   if(crossings < strategy_min_crossings)
      return false;

   const double break_pad = strategy_breakout_atr_mult * atr;
   if(close1 > comp_high + break_pad)
      return StrategyBuildRequest(true, comp_high, comp_low, atr, req);
   if(close1 < comp_low - break_pad)
      return StrategyBuildRequest(false, comp_high, comp_low, atr, req);

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || strategy_breakeven_r_mult <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || current_sl <= 0.0)
         continue;

      const bool is_buy = (pos_type == POSITION_TYPE_BUY);
      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(market <= 0.0 || point <= 0.0)
         continue;

      const bool already_be = is_buy ? (current_sl >= open_price - point * 0.5)
                                     : (current_sl <= open_price + point * 0.5);
      if(already_be)
         continue;

      const double initial_risk = MathAbs(open_price - current_sl);
      if(initial_risk <= 0.0)
         continue;
      const double moved = is_buy ? (market - open_price) : (open_price - market);
      if(moved >= strategy_breakeven_r_mult * initial_risk)
        {
         const double be_sl = StrategyNormalizePrice(open_price);
         QM_TM_MoveSL(ticket, be_sl, "grimes_yoyo_break_1r_breakeven");
        }
     }
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const int period_seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read for the back-inside-band exit.

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      // Time exit after N base-TF bars.
      if(strategy_time_exit_bars > 0 && period_seconds > 0)
        {
         const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
         if(open_time > 0 && (TimeCurrent() - open_time) >= strategy_time_exit_bars * period_seconds)
            return true;
        }

      // Early exit: a closed bar returns inside the compression band that set up
      // the breakout (band cached at entry).
      if(g_yoyo_band_valid && g_yoyo_band_high > g_yoyo_band_low && close1 > 0.0 &&
         close1 >= g_yoyo_band_low && close1 <= g_yoyo_band_high)
         return true;
     }

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10928_grimes_yoyo_break\"}");
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
