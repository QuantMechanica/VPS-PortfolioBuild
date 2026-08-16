#property strict
#property version   "5.0"
#property description "QM5_1630 demark-td-sequential-combo-overlay-h4 — DeMark TD Sequential + Combo Overlay (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1630 demark-td-sequential-combo-overlay-h4
// -----------------------------------------------------------------------------
// Source: Jason Perl — DeMark Indicators (Bloomberg Press 2008) ch. 9.
// Card: artifacts/cards_approved/QM5_1630_demark-td-sequential-combo-overlay-h4.md
//       (g0_status APPROVED).
//
// Mechanics:
//   - TD-Sequential setup + countdown (exactly as in QM5_1296).
//   - TD-Combo setup + countdown (running concurrently).
//   - Overlay confluence: The TD-Sequential buy/sell entry signal fires only when:
//     - TD-Sequential countdown-13 is complete.
//     - AND TD-Combo is in countdown phase (bars 5-10) OR has completed countdown
//       within the prior 8 H4 bars.
//     - AND D1 close > SMA(200, D1) (for Long, mirror for Short).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1630;
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
input int    strategy_seq_setup_length  = 9;
input int    strategy_combo_setup_length = 10;
input int    strategy_countdown_length  = 13;
input int    strategy_max_countdown_bars = 200;
input int    strategy_atr_period        = 14;
input double strategy_td_risk_level_multiplier = 1.0;
input int    strategy_time_stop_bars    = 60;
input double strategy_trailing_atr_mult  = 1.5;
input int    strategy_cooldown_bars     = 18;
input double strategy_atr_sl_cap_mult   = 3.0;
input double strategy_spread_atr_limit  = 0.3;

// --- State Variables ---
// Sequential state
int      g_seq_buy_setup_count = 0;
int      g_seq_sell_setup_count = 0;
bool     g_seq_buy_cd_armed = false;
bool     g_seq_sell_cd_armed = false;
int      g_seq_buy_cd_count = 0;
int      g_seq_sell_cd_count = 0;
int      g_seq_buy_cd_age = 0;
int      g_seq_sell_cd_age = 0;
bool     g_seq_buy_cd_complete = false;
bool     g_seq_sell_cd_complete = false;

datetime g_seq_buy_setup_start_time = 0;
datetime g_seq_sell_setup_start_time = 0;
datetime g_buy_sequence_start_time = 0;
datetime g_sell_sequence_start_time = 0;
datetime g_latched_buy_sequence_start_time = 0;
datetime g_latched_sell_sequence_start_time = 0;

// Combo state
int      g_combo_buy_setup_count = 0;
int      g_combo_sell_setup_count = 0;
bool     g_combo_buy_cd_armed = false;
bool     g_combo_sell_cd_armed = false;
int      g_combo_buy_cd_count = 0;
int      g_combo_sell_cd_count = 0;
int      g_combo_buy_cd_age = 0;
int      g_combo_sell_cd_age = 0;
double   g_combo_buy_cd_close[13];
double   g_combo_sell_cd_close[13];
datetime g_combo_buy_cd_completed_time = 0;
datetime g_combo_sell_cd_completed_time = 0;
bool     g_combo_buy_cd_complete = false;
bool     g_combo_sell_cd_complete = false;

// Reversal triggers
bool     g_fire_buy = false;
bool     g_fire_sell = false;
datetime g_fire_seq_start_time = 0;
datetime g_last_buy_entry_time = 0;
datetime g_last_sell_entry_time = 0;

bool     g_buy_setup_began_this_bar = false;
bool     g_sell_setup_began_this_bar = false;

// Position management
int      g_bars_in_trade = 0;
bool     g_sl_moved_to_be = false;
bool     g_partial_close_done = false;
datetime g_entry_bar_time = 0;

// Helper: lowest low / highest high across raw H4 bars
double SetupLowestLow(const int start, const int len)
{
   double lo = iLow(_Symbol, _Period, start); // perf-allowed
   for(int s = start + 1; s < start + len; ++s)
     {
      const double v = iLow(_Symbol, _Period, s); // perf-allowed
      if(v > 0.0 && v < lo)
         lo = v;
     }
   return lo;
}

double SetupHighestHigh(const int start, const int len)
{
   double hi = iHigh(_Symbol, _Period, start); // perf-allowed
   for(int s = start + 1; s < start + len; ++s)
     {
      const double v = iHigh(_Symbol, _Period, s); // perf-allowed
      if(v > hi)
         hi = v;
     }
   return hi;
}

// State Machine Update
void AdvanceState()
{
   g_fire_buy = false;
   g_fire_sell = false;
   g_buy_setup_began_this_bar = false;
   g_sell_setup_began_this_bar = false;

   const double open1  = iOpen(_Symbol, _Period, 1); // perf-allowed
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed

   // --- 1) Confirmation bar check for Sequential countdown completion --------
   if(g_seq_buy_cd_complete && close1 > 0.0 && open1 > 0.0)
     {
      if(close1 > open1) // bullish reversal candle confirms
        {
         // Verify TD-Combo Overlay condition
         bool combo_ok = false;
         if(g_combo_buy_cd_armed && g_combo_buy_cd_count >= 5 && g_combo_buy_cd_count <= 10)
           {
            combo_ok = true;
           }
         else if(g_combo_buy_cd_completed_time > 0)
           {
            int shift = iBarShift(_Symbol, PERIOD_H4, g_combo_buy_cd_completed_time, false);
            if(shift >= 0 && shift <= 8)
               combo_ok = true;
           }

         if(combo_ok)
           {
            g_fire_buy = true;
            g_fire_seq_start_time = g_latched_buy_sequence_start_time;
           }
        }
      g_seq_buy_cd_complete = false;
      g_seq_buy_cd_armed = false;
      g_seq_buy_cd_count = 0;
     }

   if(g_seq_sell_cd_complete && close1 > 0.0 && open1 > 0.0)
     {
      if(close1 < open1) // bearish reversal candle confirms
        {
         bool combo_ok = false;
         if(g_combo_sell_cd_armed && g_combo_sell_cd_count >= 5 && g_combo_sell_cd_count <= 10)
           {
            combo_ok = true;
           }
         else if(g_combo_sell_cd_completed_time > 0)
           {
            int shift = iBarShift(_Symbol, PERIOD_H4, g_combo_sell_cd_completed_time, false);
            if(shift >= 0 && shift <= 8)
               combo_ok = true;
           }

         if(combo_ok)
           {
            g_fire_sell = true;
            g_fire_seq_start_time = g_latched_sell_sequence_start_time;
           }
        }
      g_seq_sell_cd_complete = false;
      g_seq_sell_cd_armed = false;
      g_seq_sell_cd_count = 0;
     }

   // --- 2) TD-Sequential Setup running counts -------------------------------
   const double close_ref = iClose(_Symbol, _Period, 5); // perf-allowed: lookback = 4
   if(close1 > 0.0 && close_ref > 0.0)
     {
      if(close1 < close_ref)
        {
         g_seq_buy_setup_count++;
         if(g_seq_buy_setup_count == 1)
           {
            g_seq_buy_setup_start_time = iTime(_Symbol, _Period, 1); // perf-allowed
            g_buy_setup_began_this_bar = true;
           }
         g_seq_sell_setup_count = 0;
        }
      else if(close1 > close_ref)
        {
         g_seq_sell_setup_count++;
         if(g_seq_sell_setup_count == 1)
           {
            g_seq_sell_setup_start_time = iTime(_Symbol, _Period, 1); // perf-allowed
            g_sell_setup_began_this_bar = true;
           }
         g_seq_buy_setup_count = 0;
        }
      else
        {
         g_seq_buy_setup_count = 0;
         g_seq_sell_setup_count = 0;
        }
     }

   // --- 3) TD-Sequential Setup completion -----------------------------------
   if(g_seq_buy_setup_count >= strategy_seq_setup_length)
     {
      g_seq_buy_cd_armed = true;
      g_seq_buy_cd_count = 0;
      g_seq_buy_cd_age = 0;
      g_seq_buy_cd_complete = false;
      g_buy_sequence_start_time = g_seq_buy_setup_start_time;
      g_seq_buy_setup_count = 0;
     }
   if(g_seq_sell_setup_count >= strategy_seq_setup_length)
     {
      g_seq_sell_cd_armed = true;
      g_seq_sell_cd_count = 0;
      g_seq_sell_cd_age = 0;
      g_seq_sell_cd_complete = false;
      g_sell_sequence_start_time = g_seq_sell_setup_start_time;
      g_seq_sell_setup_count = 0;
     }

   // --- 4) TD-Sequential Countdown progression -------------------------------
   const double low_ref_3  = iLow(_Symbol, _Period, 3);  // perf-allowed: ref = 2
   const double high_ref_3 = iHigh(_Symbol, _Period, 3); // perf-allowed: ref = 2

   if(g_seq_buy_cd_armed && !g_seq_buy_cd_complete)
     {
      g_seq_buy_cd_age++;
      if(close1 > 0.0 && low_ref_3 > 0.0 && close1 <= low_ref_3)
         g_seq_buy_cd_count++;
      if(g_seq_buy_cd_count >= strategy_countdown_length)
        {
         g_seq_buy_cd_complete = true;
         g_latched_buy_sequence_start_time = g_buy_sequence_start_time;
        }
      else if(g_seq_buy_cd_age > strategy_max_countdown_bars)
        {
         g_seq_buy_cd_armed = false;
         g_seq_buy_cd_count = 0;
        }
     }
   if(g_seq_sell_cd_armed && !g_seq_sell_cd_complete)
     {
      g_seq_sell_cd_age++;
      if(close1 > 0.0 && high_ref_3 > 0.0 && close1 >= high_ref_3)
         g_seq_sell_cd_count++;
      if(g_seq_sell_cd_count >= strategy_countdown_length)
        {
         g_seq_sell_cd_complete = true;
         g_latched_sell_sequence_start_time = g_sell_sequence_start_time;
        }
      else if(g_seq_sell_cd_age > strategy_max_countdown_bars)
        {
         g_seq_sell_cd_armed = false;
         g_seq_sell_cd_count = 0;
        }
     }

   // --- 5) TD-Combo Setup running counts ------------------------------------
   if(close1 > 0.0 && low_ref_3 > 0.0)
     {
      const double low1 = iLow(_Symbol, _Period, 1); // perf-allowed
      if(close1 <= low_ref_3 && low1 <= low_ref_3)
        {
         g_combo_buy_setup_count++;
         g_combo_sell_setup_count = 0;
        }
      else
         g_combo_buy_setup_count = 0;
     }
   if(close1 > 0.0 && high_ref_3 > 0.0)
     {
      const double high1 = iHigh(_Symbol, _Period, 1); // perf-allowed
      if(close1 >= high_ref_3 && high1 >= high_ref_3)
        {
         g_combo_sell_setup_count++;
         g_combo_buy_setup_count = 0;
        }
      else
         g_combo_sell_setup_count = 0;
     }

   // --- 6) TD-Combo Setup completion ----------------------------------------
   if(g_combo_buy_setup_count >= strategy_combo_setup_length)
     {
      g_combo_buy_cd_armed = true;
      g_combo_buy_cd_count = 0;
      g_combo_buy_cd_age = 0;
      g_combo_buy_cd_complete = false;
      g_combo_buy_setup_count = 0;
     }
   if(g_combo_sell_setup_count >= strategy_combo_setup_length)
     {
      g_combo_sell_cd_armed = true;
      g_combo_sell_cd_count = 0;
      g_combo_sell_cd_age = 0;
      g_combo_sell_cd_complete = false;
      g_combo_sell_setup_count = 0;
     }

   // --- 7) TD-Combo Countdown progression ------------------------------------
   const double low_ref_2  = iLow(_Symbol, _Period, 2);   // perf-allowed
   const double high_ref_2 = iHigh(_Symbol, _Period, 2);  // perf-allowed
   const double close_ref_2 = iClose(_Symbol, _Period, 2); // perf-allowed

   if(g_combo_buy_cd_armed)
     {
      g_combo_buy_cd_age++;
      const double low1 = iLow(_Symbol, _Period, 1); // perf-allowed
      bool qual = (close1 <= low_ref_3 && low1 < low_ref_2 && close1 < close_ref_2);
      if(qual && g_combo_buy_cd_count > 0)
        {
         if(close1 >= g_combo_buy_cd_close[g_combo_buy_cd_count - 1])
            qual = false;
        }

      if(qual)
        {
         g_combo_buy_cd_close[g_combo_buy_cd_count] = close1;
         g_combo_buy_cd_count++;
         if(g_combo_buy_cd_count >= strategy_countdown_length)
           {
            g_combo_buy_cd_completed_time = iTime(_Symbol, _Period, 1); // perf-allowed
            g_combo_buy_cd_complete = true;
            g_combo_buy_cd_armed = false;
            g_combo_buy_cd_count = 0;
           }
        }
      else if(g_combo_buy_cd_age > strategy_max_countdown_bars)
        {
         g_combo_buy_cd_armed = false;
         g_combo_buy_cd_count = 0;
        }
     }

   if(g_combo_sell_cd_armed)
     {
      g_combo_sell_cd_age++;
      const double high1 = iHigh(_Symbol, _Period, 1); // perf-allowed
      bool qual = (close1 >= high_ref_3 && high1 > high_ref_2 && close1 > close_ref_2);
      if(qual && g_combo_sell_cd_count > 0)
        {
         if(close1 <= g_combo_sell_cd_close[g_combo_sell_cd_count - 1])
            qual = false;
        }

      if(qual)
        {
         g_combo_sell_cd_close[g_combo_sell_cd_count] = close1;
         g_combo_sell_cd_count++;
         if(g_combo_sell_cd_count >= strategy_countdown_length)
           {
            g_combo_sell_cd_completed_time = iTime(_Symbol, _Period, 1); // perf-allowed
            g_combo_sell_cd_complete = true;
            g_combo_sell_cd_armed = false;
            g_combo_sell_cd_count = 0;
           }
        }
      else if(g_combo_sell_cd_age > strategy_max_countdown_bars)
        {
         g_combo_sell_cd_armed = false;
         g_combo_sell_cd_count = 0;
        }
     }

   // --- 8) Advance open position time stop ---
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      g_bars_in_trade++;
   else
      g_bars_in_trade = 0;
}

// Calculate TD Risk Levels (TP/SL)
bool CalculateTDRiskLevel(datetime seq_start_time, bool is_long, double entry_price, double atr_val, double &tp, double &sl)
{
   if(seq_start_time <= 0)
      return false;
   int start_shift = iBarShift(_Symbol, PERIOD_H4, seq_start_time, false);
   if(start_shift < 1)
      return false;

   double max_tr = -1.0;
   int max_tr_shift = -1;
   for(int s = 1; s <= start_shift; ++s)
     {
      double prev_c = iClose(_Symbol, PERIOD_H4, s + 1); // perf-allowed
      double h = iHigh(_Symbol, PERIOD_H4, s); // perf-allowed
      double l = iLow(_Symbol, PERIOD_H4, s); // perf-allowed
      if(prev_c <= 0.0 || h <= 0.0 || l <= 0.0)
         continue;
      double tr = MathMax(h, prev_c) - MathMin(l, prev_c);
      if(tr > max_tr)
        {
         max_tr = tr;
         max_tr_shift = s;
        }
     }

   if(max_tr_shift < 1)
      return false;

   double h_max = iHigh(_Symbol, PERIOD_H4, max_tr_shift); // perf-allowed
   double l_max = iLow(_Symbol, PERIOD_H4, max_tr_shift);  // perf-allowed

   if(is_long)
     {
      tp = h_max + strategy_td_risk_level_multiplier * max_tr;
      sl = l_max - strategy_td_risk_level_multiplier * max_tr;
      double max_sl_dist = strategy_atr_sl_cap_mult * atr_val;
      if(entry_price - sl > max_sl_dist)
         sl = entry_price - max_sl_dist;
     }
   else
     {
      tp = l_max - strategy_td_risk_level_multiplier * max_tr;
      sl = h_max + strategy_td_risk_level_multiplier * max_tr;
      double max_sl_dist = strategy_atr_sl_cap_mult * atr_val;
      if(sl - entry_price > max_sl_dist)
         sl = entry_price + max_sl_dist;
     }

   tp = QM_TM_NormalizePrice(_Symbol, tp);
   sl = QM_TM_NormalizePrice(_Symbol, sl);
   return (tp > 0.0 && sl > 0.0);
}

// Strategy Hooks
bool Strategy_NoTradeFilter()
{
   if(Period() != PERIOD_H4)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > 0.0 && spread > strategy_spread_atr_limit * atr_value)
      return true;

   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(!g_fire_buy && !g_fire_sell)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double sma200_d1 = QM_SMA(_Symbol, PERIOD_D1, 200, 1);
   const double close_d1 = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed
   if(sma200_d1 <= 0.0 || close_d1 <= 0.0)
      return false;

   if(g_fire_buy)
     {
      if(g_last_buy_entry_time > 0)
        {
         int bars_since = iBarShift(_Symbol, _Period, g_last_buy_entry_time);
         if(bars_since >= 0 && bars_since < strategy_cooldown_bars)
            return false;
        }

      if(close_d1 <= sma200_d1)
         return false;

      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;

      double tp = 0.0, sl = 0.0;
      if(!CalculateTDRiskLevel(g_fire_seq_start_time, true, entry, atr_value, tp, sl))
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "overlay_buy";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      g_last_buy_entry_time = iTime(_Symbol, _Period, 0); // perf-allowed
      return true;
     }

   if(g_fire_sell)
     {
      if(g_last_sell_entry_time > 0)
        {
         int bars_since = iBarShift(_Symbol, _Period, g_last_sell_entry_time);
         if(bars_since >= 0 && bars_since < strategy_cooldown_bars)
            return false;
        }

      if(close_d1 >= sma200_d1)
         return false;

      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;

      double tp = 0.0, sl = 0.0;
      if(!CalculateTDRiskLevel(g_fire_seq_start_time, false, entry, atr_value, tp, sl))
         return false;

      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "overlay_sell";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      g_last_sell_entry_time = iTime(_Symbol, _Period, 0); // perf-allowed
      return true;
     }

   return false;
}

void Strategy_ManageOpenPosition()
{
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) == 0)
     {
      g_sl_moved_to_be = false;
      g_partial_close_done = false;
      return;
     }

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double sl = PositionGetDouble(POSITION_SL);
      const double tp = PositionGetDouble(POSITION_TP);
      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double atr_val = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
      if(entry <= 0.0 || volume <= 0.0 || atr_val <= 0.0)
         continue;

      // 1) Move SL to BE + spread
      if(!g_sl_moved_to_be)
        {
         bool cond = (ptype == POSITION_TYPE_BUY) ? (bid >= entry + strategy_trailing_atr_mult * atr_val)
                                                  : (ask <= entry - strategy_trailing_atr_mult * atr_val);
         if(cond)
           {
            double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double new_sl = (ptype == POSITION_TYPE_BUY) ? entry + spread : entry - spread;
            new_sl = QM_TM_NormalizePrice(_Symbol, new_sl);
            bool sl_improves = (ptype == POSITION_TYPE_BUY) ? (new_sl > sl || sl == 0.0) : (new_sl < sl || sl == 0.0);
            if(sl_improves)
              {
               if(QM_TM_MoveSL(ticket, new_sl, "trail_be_spread"))
                  g_sl_moved_to_be = true;
              }
           }
        }

      // 2) Close 50% at TP-50%
      if(!g_partial_close_done && tp > 0.0)
        {
         double tp_50 = entry + 0.5 * (tp - entry);
         bool cond = (ptype == POSITION_TYPE_BUY) ? (bid >= tp_50) : (ask <= tp_50);
         if(cond)
           {
            double lots_to_close = volume * 0.5;
            lots_to_close = MathMax(lots_to_close, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN));
            lots_to_close = QM_TM_NormalizeVolume(_Symbol, lots_to_close);
            if(lots_to_close > 0.0 && lots_to_close < volume)
              {
               if(QM_TM_PartialClose(ticket, lots_to_close, QM_EXIT_PARTIAL))
                  g_partial_close_done = true;
              }
           }
        }
     }
}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   bool is_long = false;
   bool have_pos = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      is_long  = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      have_pos = true;
      break;
     }
   if(!have_pos)
      return false;

   // Time Stop
   if(g_bars_in_trade >= strategy_time_stop_bars)
      return true;

   // Counter-signal exit
   if(is_long && g_fire_sell)
      return true;
   if(!is_long && g_fire_buy)
      return true;

   // Recycle exit
   if(g_bars_in_trade <= 18)
     {
      if(is_long && g_buy_setup_began_this_bar)
         return true;
      if(!is_long && g_sell_setup_began_this_bar)
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

   g_seq_buy_setup_count = 0;
   g_seq_sell_setup_count = 0;
   g_seq_buy_cd_armed = false;
   g_seq_sell_cd_armed = false;
   g_seq_buy_cd_count = 0;
   g_seq_sell_cd_count = 0;
   g_seq_buy_cd_age = 0;
   g_seq_sell_cd_age = 0;
   g_seq_buy_cd_complete = false;
   g_seq_sell_cd_complete = false;

   g_combo_buy_setup_count = 0;
   g_combo_sell_setup_count = 0;
   g_combo_buy_cd_armed = false;
   g_combo_sell_cd_armed = false;
   g_combo_buy_cd_count = 0;
   g_combo_sell_cd_count = 0;
   g_combo_buy_cd_age = 0;
   g_combo_sell_cd_age = 0;
   g_combo_buy_cd_completed_time = 0;
   g_combo_sell_cd_completed_time = 0;
   g_combo_buy_cd_complete = false;
   g_combo_sell_cd_complete = false;

   g_bars_in_trade = 0;
   g_sl_moved_to_be = false;
   g_partial_close_done = false;

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

   const bool new_bar = QM_IsNewBar();
   if(new_bar)
      AdvanceState();

   if(!new_bar)
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      if(QM_TM_OpenPosition(req, out_ticket))
        {
         g_entry_bar_time = iTime(_Symbol, _Period, 0); // perf-allowed
         g_bars_in_trade = 0;
         g_sl_moved_to_be = false;
         g_partial_close_done = false;
        }
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
