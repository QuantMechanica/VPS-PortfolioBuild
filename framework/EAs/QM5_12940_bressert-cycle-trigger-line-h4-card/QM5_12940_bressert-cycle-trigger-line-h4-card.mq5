#property strict
#property version   "5.0"
#property description "QM5_12940 Bressert Cycle-Trigger-Line on DSS (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_12940
// Slug: bressert-cycle-trigger-line-h4-card
// Card: artifacts/cards_approved/QM5_12940_bressert-cycle-trigger-line-h4-card.md
// Source: Walter Bressert 1991 / 1995 / FF thread/187693 / 277401
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 12940;
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
input int    strategy_dss_stoch_period    = 13;     // DSS raw stochastic lookback (%K)
input int    strategy_dss_inner_ema       = 8;      // DSS first EMA smoothing
input int    strategy_dss_outer_ema       = 8;      // DSS second EMA smoothing
input int    strategy_trigger_period      = 3;      // Trigger line SMA period on DSS
input double strategy_dss_os_zone         = 30.0;   // Oversold zone gate for BUY
input double strategy_dss_ob_zone         = 70.0;   // Overbought zone gate for SELL
input int    strategy_d1_ema_period       = 50;     // Higher-TF (D1) trend filter EMA period
input int    strategy_momentum_window     = 5;      // Prior bars extreme comparison window
input int    strategy_atr_period          = 14;     // ATR period for stops and targets
input double strategy_atr_sl_mult         = 1.5;    // Stop loss multiplier in ATR
input double strategy_atr_tp_mult         = 1.5;    // T1 partial take profit multiplier in ATR
input double strategy_trail_atr_mult      = 1.0;    // Trailing stop distance in ATR after T1
input int    strategy_max_hold_bars       = 24;     // Time stop: max holding period in H4 bars
input int    strategy_cooldown_bars       = 12;     // Cooldown between entries in H4 bars
input double strategy_spread_max_atr_mult = 0.3;    // Maximum spread threshold in ATR

struct StrategyTradeState
{
   ulong    ticket;
   ulong    position_id;
   bool     t1_hit;
   double   t1_price;
   double   initial_volume;
};

// -----------------------------------------------------------------------------
// File-scope cached state (advanced once per closed H4 bar)
// -----------------------------------------------------------------------------
double             g_dss_1 = 0.0;
double             g_dss_2 = 0.0;
double             g_trigger_1 = 0.0;
double             g_trigger_2 = 0.0;
double             g_atr_1 = 0.0;
bool               g_long_signal = false;
bool               g_short_signal = false;
double             g_long_sl = 0.0;
double             g_long_t1 = 0.0;
double             g_short_sl = 0.0;
double             g_short_t1 = 0.0;
bool               g_long_exit_signal = false;
bool               g_short_exit_signal = false;
bool               g_state_ready = false;
int                g_bars_since_last_long = 100;
int                g_bars_since_last_short = 100;
StrategyTradeState g_trade_state;

// -----------------------------------------------------------------------------
// Durable entry/management state
// -----------------------------------------------------------------------------

void Strategy_ResetTradeState()
{
   ZeroMemory(g_trade_state);
}

string Strategy_EntryComment(const bool is_long, const double t1_price)
{
   const string prefix = is_long ? "BCTL|T1=" : "BCTS|T1=";
   return prefix + DoubleToString(t1_price, _Digits);
}

bool Strategy_ParseT1Comment(const string comment,
                             const bool is_long,
                             double &t1_price)
{
   t1_price = 0.0;
   const string prefix = is_long ? "BCTL|T1=" : "BCTS|T1=";
   if(StringFind(comment, prefix) != 0)
      return false;

   const double parsed = StringToDouble(StringSubstr(comment, StringLen(prefix)));
   if(parsed <= 0.0 || !MathIsValidNumber(parsed))
      return false;

   t1_price = NormalizeDouble(parsed, _Digits);
   return true;
}

int Strategy_BarsSinceEntry(const datetime entry_time)
{
   if(entry_time <= 0)
      return 1000000;
   const int shift = iBarShift(_Symbol, _Period, entry_time); // perf-allowed
   return (shift >= 0) ? shift : 0;
}

void Strategy_RestoreCooldownState()
{
   g_bars_since_last_long = 1000000;
   g_bars_since_last_short = 1000000;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || !HistorySelect(0, TimeCurrent()))
   {
      // History uncertainty must not bypass the card's directional cooldown.
      g_bars_since_last_long = 0;
      g_bars_since_last_short = 0;
      return;
   }

   datetime last_long_entry = 0;
   datetime last_short_entry = 0;
   for(int i = HistoryDealsTotal() - 1; i >= 0; --i)
   {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0 || HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      if((int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic)
         continue;

      const ENUM_DEAL_ENTRY entry =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_IN && entry != DEAL_ENTRY_INOUT)
         continue;

      const datetime deal_time = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
      const ENUM_DEAL_TYPE deal_type =
         (ENUM_DEAL_TYPE)HistoryDealGetInteger(deal, DEAL_TYPE);
      if(deal_type == DEAL_TYPE_BUY && deal_time > last_long_entry)
         last_long_entry = deal_time;
      if(deal_type == DEAL_TYPE_SELL && deal_time > last_short_entry)
         last_short_entry = deal_time;
   }

   g_bars_since_last_long = Strategy_BarsSinceEntry(last_long_entry);
   g_bars_since_last_short = Strategy_BarsSinceEntry(last_short_entry);
}

// -----------------------------------------------------------------------------
// DSS computation helpers (closed-bar, bounded)
// -----------------------------------------------------------------------------

double DSS_RawStochAtShift(const int period, const int end_shift)
{
   if(period <= 0 || end_shift < 0)
      return 0.0;

   double hh = -DBL_MAX;
   double ll =  DBL_MAX;
   for(int s = end_shift; s < end_shift + period; ++s)
   {
      const double h = iHigh(_Symbol, _Period, s);   // perf-allowed
      const double l = iLow(_Symbol, _Period, s);    // perf-allowed
      if(h > hh) hh = h;
      if(l < ll) ll = l;
   }
   const double c = iClose(_Symbol, _Period, end_shift); // perf-allowed
   const double rng = hh - ll;
   if(rng <= 0.0)
      return 50.0;
   return 100.0 * (c - ll) / rng;
}

double DSS_EMAofSeries(const double &arr[], const int count, const int period)
{
   if(count <= 0 || period <= 0 || count > ArraySize(arr))
      return 0.0;
   const double k = 2.0 / (period + 1.0);
   double ema = arr[count - 1];
   for(int i = count - 2; i >= 0; --i)
      ema = arr[i] * k + ema * (1.0 - k);
   return ema;
}

double DSS_ComputeAtShift(const int end_shift)
{
   const int p1 = strategy_dss_stoch_period;
   const int p2 = strategy_dss_inner_ema;
   const int p3 = strategy_dss_stoch_period;
   const int p4 = strategy_dss_outer_ema;

   double k1[128];
   double rawk[64];
   double rawk2[64];

   if(end_shift < 0 || p1 <= 0 || p2 <= 0 || p3 <= 0 || p4 <= 0)
      return 0.0;

   const int rawk_len = p2 + 10;
   const int rawk2_len = p4 + 10;
   const int k1_count = rawk2_len + p3 + 10;
   if(rawk_len > ArraySize(rawk) ||
      rawk2_len > ArraySize(rawk2) ||
      k1_count > ArraySize(k1))
      return 0.0;

   for(int j = 0; j < k1_count; ++j)
   {
      if(j < 0 || j >= ArraySize(k1))
         return 0.0;
      const int base = end_shift + j;
      for(int r = 0; r < rawk_len; ++r)
      {
         if(r < 0 || r >= ArraySize(rawk))
            return 0.0;
         rawk[r] = DSS_RawStochAtShift(p1, base + r);
      }
      k1[j] = DSS_EMAofSeries(rawk, rawk_len, p2);
   }

   for(int m = 0; m < rawk2_len; ++m)
   {
      if(m < 0 || m >= ArraySize(rawk2) || m >= k1_count || m >= ArraySize(k1))
         return 0.0;
      double hh = -DBL_MAX;
      double ll =  DBL_MAX;
      for(int s = m; s < m + p3; ++s)
      {
         if(s < 0 || s >= k1_count || s >= ArraySize(k1))
            return 0.0;
         const double v = k1[s];
         if(v > hh) hh = v;
         if(v < ll) ll = v;
      }
      const double cc = k1[m];
      const double rng = hh - ll;
      rawk2[m] = (rng <= 0.0) ? 50.0 : 100.0 * (cc - ll) / rng;
   }

   return DSS_EMAofSeries(rawk2, rawk2_len, p4);
}

double DSS_ComputeTriggerAtShift(const int shift, const int trigger_period)
{
   const int period = MathMax(1, trigger_period);
   double sum = 0.0;
   for(int i = 0; i < period; ++i)
   {
      sum += DSS_ComputeAtShift(shift + i);
   }
   return sum / (double)period;
}

void AdvanceState_OnNewBar()
{
   g_long_signal = false;
   g_short_signal = false;
   g_long_exit_signal = false;
   g_short_exit_signal = false;

   g_bars_since_last_long++;
   g_bars_since_last_short++;

   const int needed_bars = strategy_dss_stoch_period * 3 + strategy_dss_inner_ema + strategy_dss_outer_ema + strategy_trigger_period + 40;
   if(iBars(_Symbol, _Period) < needed_bars || iBars(_Symbol, PERIOD_D1) < strategy_d1_ema_period + 10) // perf-allowed
   {
      g_state_ready = false;
      return;
   }

   const double dss1 = DSS_ComputeAtShift(1);
   const double dss2 = DSS_ComputeAtShift(2);

   const double trig1 = DSS_ComputeTriggerAtShift(1, strategy_trigger_period);
   const double trig2 = DSS_ComputeTriggerAtShift(2, strategy_trigger_period);

   g_dss_1 = dss1;
   g_dss_2 = dss2;
   g_trigger_1 = trig1;
   g_trigger_2 = trig2;

   g_atr_1 = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(g_atr_1 <= 0.0)
   {
      g_state_ready = false;
      return;
   }
   g_state_ready = true;

   // Opposite crossover exit signals (cycle completion)
   if(dss2 >= trig2 && dss1 < trig1)
      g_long_exit_signal = true;
   if(dss2 <= trig2 && dss1 > trig1)
      g_short_exit_signal = true;

   // Bullish crossover in oversold zone (DSS < 30)
   const bool bull_cross = (dss2 <= trig2 && dss1 > trig1 && dss1 < strategy_dss_os_zone);
   // Bearish crossover in overbought zone (DSS > 70)
   const bool bear_cross = (dss2 >= trig2 && dss1 < trig1 && dss1 > strategy_dss_ob_zone);

   // Higher TF D1 trend filter
   const double d1_close = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed
   const double d1_ema   = QM_EMA(_Symbol, PERIOD_D1, strategy_d1_ema_period, 1);

   // Momentum confirmation on H4 closed bar (shift 1)
   const double h4_open1  = iOpen(_Symbol, _Period, 1);   // perf-allowed
   const double h4_close1 = iClose(_Symbol, _Period, 1);  // perf-allowed

   double prior_hh = -DBL_MAX;
   double prior_ll =  DBL_MAX;
   for(int k = 2; k < 2 + strategy_momentum_window; ++k)
   {
      const double h = iHigh(_Symbol, _Period, k); // perf-allowed
      const double l = iLow(_Symbol, _Period, k);  // perf-allowed
      if(h > prior_hh) prior_hh = h;
      if(l < prior_ll) prior_ll = l;
   }

   const bool bull_momentum = (h4_close1 > h4_open1 && h4_close1 > prior_hh);
   const bool bear_momentum = (h4_close1 < h4_open1 && h4_close1 < prior_ll);

   if(bull_cross && d1_close > d1_ema && bull_momentum && g_bars_since_last_long >= strategy_cooldown_bars)
   {
      g_long_signal = true;
      const double bar_low = iLow(_Symbol, _Period, 1); // perf-allowed
      g_long_sl = bar_low - strategy_atr_sl_mult * g_atr_1;
      g_long_t1 = h4_close1 + strategy_atr_tp_mult * g_atr_1;
   }

   if(bear_cross && d1_close < d1_ema && bear_momentum && g_bars_since_last_short >= strategy_cooldown_bars)
   {
      g_short_signal = true;
      const double bar_high = iHigh(_Symbol, _Period, 1); // perf-allowed
      g_short_sl = bar_high + strategy_atr_sl_mult * g_atr_1;
      g_short_t1 = h4_close1 - strategy_atr_tp_mult * g_atr_1;
   }
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   if(!g_state_ready) return true;
   const double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   if(g_atr_1 > 0.0 && spread > strategy_spread_max_atr_mult * g_atr_1)
      return true;
   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   ZeroMemory(req);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_state_ready) return false;

   if(g_long_signal)
   {
      req.type = QM_BUY;
      req.reason = Strategy_EntryComment(true, g_long_t1);
      req.price = 0.0;
      req.sl = NormalizeDouble(g_long_sl, _Digits);
      req.tp = 0.0;
      return true;
   }

   if(g_short_signal)
   {
      req.type = QM_SELL;
      req.reason = Strategy_EntryComment(false, g_short_t1);
      req.price = 0.0;
      req.sl = NormalizeDouble(g_short_sl, _Digits);
      req.tp = 0.0;
      return true;
   }

   return false;
}

bool Strategy_RebuildTradeState(const ulong ticket)
{
   if(ticket == 0 || !PositionSelectByTicket(ticket))
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 ||
      PositionGetString(POSITION_SYMBOL) != _Symbol ||
      (int)PositionGetInteger(POSITION_MAGIC) != magic)
      return false;

   const ulong position_id = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
   const ENUM_POSITION_TYPE position_type =
      (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const bool is_long = (position_type == POSITION_TYPE_BUY);
   double t1_price = 0.0;
   bool t1_found = Strategy_ParseT1Comment(PositionGetString(POSITION_COMMENT),
                                           is_long,
                                           t1_price);

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
      if((int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic)
         continue;

      const double deal_volume = HistoryDealGetDouble(deal, DEAL_VOLUME);
      const ENUM_DEAL_ENTRY entry =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry == DEAL_ENTRY_IN || entry == DEAL_ENTRY_INOUT)
      {
         opening_volume += deal_volume;
         if(!t1_found)
            t1_found = Strategy_ParseT1Comment(HistoryDealGetString(deal, DEAL_COMMENT),
                                              is_long,
                                              t1_price);
         if(!t1_found)
         {
            const ulong order = (ulong)HistoryDealGetInteger(deal, DEAL_ORDER);
            if(order > 0)
               t1_found = Strategy_ParseT1Comment(HistoryOrderGetString(order, ORDER_COMMENT),
                                                 is_long,
                                                 t1_price);
         }
      }
      if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY || entry == DEAL_ENTRY_INOUT)
         closing_volume += deal_volume;
   }

   // Some venues omit the entry comment from the live position and deal.
   // The accepted order remains a deterministic third reconstruction source.
   if(!t1_found)
   {
      for(int i = HistoryOrdersTotal() - 1; i >= 0; --i)
      {
         const ulong order = HistoryOrderGetTicket(i);
         if(order == 0 || HistoryOrderGetString(order, ORDER_SYMBOL) != _Symbol)
            continue;
         if((int)HistoryOrderGetInteger(order, ORDER_MAGIC) != magic)
            continue;
         if(Strategy_ParseT1Comment(HistoryOrderGetString(order, ORDER_COMMENT),
                                    is_long,
                                    t1_price))
         {
            t1_found = true;
            break;
         }
      }
   }

   // History selection must not leave stale live-position properties behind.
   if(!PositionSelectByTicket(ticket) ||
      (ulong)PositionGetInteger(POSITION_IDENTIFIER) != position_id)
      return false;

   const double current_volume = PositionGetDouble(POSITION_VOLUME);
   const double volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   const double volume_tolerance = MathMax(1e-8, volume_step * 0.25);
   if(opening_volume <= volume_tolerance)
      opening_volume = current_volume + closing_volume;

   if(!t1_found || t1_price <= 0.0 || !MathIsValidNumber(t1_price) ||
      current_volume <= 0.0 || opening_volume + volume_tolerance < current_volume)
      return false;

   g_trade_state.ticket = ticket;
   g_trade_state.position_id = position_id;
   g_trade_state.t1_price = t1_price;
   g_trade_state.initial_volume = opening_volume;
   g_trade_state.t1_hit = (closing_volume > volume_tolerance ||
                           current_volume + volume_tolerance < opening_volume);
   return true;
}

bool Strategy_EnsureTradeState(const ulong ticket)
{
   if(ticket == 0 || !PositionSelectByTicket(ticket))
      return false;

   const ulong position_id = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
   const double current_volume = PositionGetDouble(POSITION_VOLUME);
   if(g_trade_state.position_id == position_id &&
      g_trade_state.ticket == ticket &&
      g_trade_state.t1_price > 0.0 &&
      g_trade_state.initial_volume > 0.0)
   {
      const double volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      const double volume_tolerance = MathMax(1e-8, volume_step * 0.25);
      if(current_volume + volume_tolerance < g_trade_state.initial_volume)
         g_trade_state.t1_hit = true;
      return true;
   }

   Strategy_ResetTradeState();
   return Strategy_RebuildTradeState(ticket);
}

void Strategy_ManageOpenPosition()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0) return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int bars_open = iBarShift(_Symbol, _Period, open_time); // perf-allowed

      // Time stop exit: 24 H4 bars
      if(bars_open >= strategy_max_hold_bars)
      {
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
         continue;
      }

      // Opposite reverse crossover exit
      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY && g_long_exit_signal)
      {
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
         continue;
      }
      else if(pos_type == POSITION_TYPE_SELL && g_short_exit_signal)
      {
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
         continue;
      }

      // T1/partial state must be recoverable from the accepted trade record.
      // If history/comment evidence is unavailable, partial management stays
      // fail-closed while the server-side initial stop remains active.
      if(!Strategy_EnsureTradeState(ticket))
         continue;

      const double current_vol = PositionGetDouble(POSITION_VOLUME);

      if(pos_type == POSITION_TYPE_BUY)
      {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         // T1 partial close: 50% at 1.5 ATR
         if(!g_trade_state.t1_hit && g_trade_state.t1_price > 0.0 && bid >= g_trade_state.t1_price)
         {
            const double half_vol = QM_TM_NormalizeVolume(_Symbol, current_vol * 0.5);
            if(half_vol > 0.0 && half_vol < current_vol)
            {
               if(QM_TM_PartialClose(ticket, half_vol, QM_EXIT_PARTIAL))
                  g_trade_state.t1_hit = true;
            }
         }

         // Post-T1 ATR trail: trail SL at ATR(14) * 1.0 below bar 1 low
         if(g_trade_state.t1_hit)
         {
            const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
            if(atr > 0.0)
            {
               const double bar_low = iLow(_Symbol, _Period, 1); // perf-allowed
               const double trail_sl = QM_TM_NormalizePrice(_Symbol, bar_low - atr * strategy_trail_atr_mult);
               const double current_sl = PositionGetDouble(POSITION_SL);
               const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
               if(trail_sl > current_sl + point * 0.5 && trail_sl < bid)
               {
                  QM_TM_MoveSL(ticket, trail_sl, "bressert_cycle_post_t1_atr_trail");
               }
            }
         }
      }
      else if(pos_type == POSITION_TYPE_SELL)
      {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         // T1 partial close: 50% at 1.5 ATR
         if(!g_trade_state.t1_hit && g_trade_state.t1_price > 0.0 && ask <= g_trade_state.t1_price)
         {
            const double half_vol = QM_TM_NormalizeVolume(_Symbol, current_vol * 0.5);
            if(half_vol > 0.0 && half_vol < current_vol)
            {
               if(QM_TM_PartialClose(ticket, half_vol, QM_EXIT_PARTIAL))
                  g_trade_state.t1_hit = true;
            }
         }

         // Post-T1 ATR trail: trail SL at ATR(14) * 1.0 above bar 1 high
         if(g_trade_state.t1_hit)
         {
            const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
            if(atr > 0.0)
            {
               const double bar_high = iHigh(_Symbol, _Period, 1); // perf-allowed
               const double trail_sl = QM_TM_NormalizePrice(_Symbol, bar_high + atr * strategy_trail_atr_mult);
               const double current_sl = PositionGetDouble(POSITION_SL);
               const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
               if((current_sl <= 0.0 || trail_sl < current_sl - point * 0.5) && trail_sl > ask)
               {
                  QM_TM_MoveSL(ticket, trail_sl, "bressert_cycle_post_t1_atr_trail");
               }
            }
         }
      }
   }
}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0) return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if((ptype == POSITION_TYPE_BUY && (g_short_signal || g_long_exit_signal)) ||
         (ptype == POSITION_TYPE_SELL && (g_long_signal || g_short_exit_signal)))
         return true;
   }
   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
{
   Strategy_ResetTradeState();
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;

   Strategy_RestoreCooldownState();
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12940_bressert-cycle-trigger-line-h4-card\"}");
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

   if(!QM_KillSwitchCheck()) return;

   const datetime broker_now = TimeCurrent();
   if(QM_FrameworkHandleFridayClose()) return;

   const bool is_new_bar = QM_IsNewBar(_Symbol, _Period);
   if(is_new_bar)
   {
      AdvanceState_OnNewBar();
      QM_EquityStreamOnNewBar();
   }

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
   {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

         const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         if((ptype == POSITION_TYPE_BUY && (g_short_signal || g_long_exit_signal)) ||
            (ptype == POSITION_TYPE_SELL && (g_long_signal || g_short_exit_signal)))
         {
            QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
         }
      }
   }

   if(!is_new_bar) return;
   if(Strategy_NoTradeFilter()) return;

   if(Strategy_NewsFilterHook(broker_now)) return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) == 0)
   {
      QM_EntryRequest req;
      ZeroMemory(req);
      if(Strategy_EntrySignal(req))
      {
         ulong ticket = 0;
         if(QM_TM_OpenPosition(req, ticket))
         {
            if(req.type == QM_BUY)
               g_bars_since_last_long = 0;
            else if(req.type == QM_SELL)
               g_bars_since_last_short = 0;
            Strategy_ResetTradeState();
         }
      }
   }
}

void OnTimer() { QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
