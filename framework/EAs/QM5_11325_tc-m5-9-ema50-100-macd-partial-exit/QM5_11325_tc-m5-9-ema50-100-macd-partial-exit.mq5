#property strict
#property version   "5.0"
#property description "QM5_11325 TC-M5 System #9 EMA(50/100) Cascade + MACD Partial Exit"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_11325
// Source: Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)",
//         5 Min Trading System #9. Card: cards_approved/QM5_11325_tc-m5-9-ema50-100-macd-partial-exit.md
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11325;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.5;
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
input int    strategy_ema_fast_period        = 50;
input int    strategy_ema_slow_period        = 100;
input int    strategy_breakout_pips          = 10;
input int    strategy_macd_fast              = 12;
input int    strategy_macd_slow              = 26;
input int    strategy_macd_signal            = 9;
input int    strategy_macd_lookback_bars     = 5;
input int    strategy_sl_lookback_bars       = 5;
input int    strategy_atr_period             = 14;
input double strategy_atr_sl_cap_mult        = 1.5;
input double strategy_partial_tp_rr          = 2.0;
input double strategy_partial_close_fraction = 0.5;
input int    strategy_trail_exit_pips        = 10;
input int    strategy_max_spread_pips        = 15;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool MacdCrossedUpWithin(const int lookback)
{
   for(int i = 1; i <= lookback; i++)
   {
      double m_now  = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, i);
      double m_prev = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, i + 1);
      if(m_prev <= 0.0 && m_now > 0.0)
         return true;
   }
   return false;
}

bool MacdCrossedDownWithin(const int lookback)
{
   for(int i = 1; i <= lookback; i++)
   {
      double m_now  = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, i);
      double m_prev = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, i + 1);
      if(m_prev >= 0.0 && m_now < 0.0)
         return true;
   }
   return false;
}

// Return TRUE to BLOCK trading this tick. Always allows management of an
// already-open position (spread cap applies to fresh entries only).
bool Strategy_NoTradeFilter()
{
   const int magic = QM_FrameworkMagic();
   if(magic > 0)
   {
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && (int)PositionGetInteger(POSITION_MAGIC) == magic)
            return false;
      }
   }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_max_spread_pips);
   if(spread_cap <= 0.0)
      return true;
   if((ask - bid) > spread_cap)
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

   const int magic = QM_FrameworkMagic();
   if(QM_EntryHasOpenPosition(magic, _Symbol))
      return false;

   if(strategy_ema_fast_period < 2 || strategy_ema_slow_period <= strategy_ema_fast_period ||
      strategy_macd_lookback_bars < 1 || strategy_sl_lookback_bars < 1 ||
      strategy_atr_period < 1 || strategy_atr_sl_cap_mult <= 0.0 || strategy_partial_tp_rr <= 0.0)
      return false;

   double ema_fast_1 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   double ema_slow_1 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   double close_1 = iClose(_Symbol, _Period, 1); // perf-allowed
   if(ema_fast_1 <= 0.0 || ema_slow_1 <= 0.0 || close_1 <= 0.0)
      return false;

   double breakout_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_breakout_pips);
   if(breakout_dist <= 0.0)
      return false;

   // Above both EMAs (excludes the "between EMA50 and EMA100" zone by construction)
   // and broken out past EMA50 by the pip threshold.
   bool long_setup  = (close_1 > ema_fast_1) && (close_1 > ema_slow_1) && ((close_1 - ema_fast_1) >= breakout_dist);
   bool short_setup = (close_1 < ema_fast_1) && (close_1 < ema_slow_1) && ((ema_fast_1 - close_1) >= breakout_dist);
   if(!long_setup && !short_setup)
      return false;

   if(long_setup && !MacdCrossedUpWithin(strategy_macd_lookback_bars))
      return false;
   if(short_setup && !MacdCrossedDownWithin(strategy_macd_lookback_bars))
      return false;

   QM_OrderType side = long_setup ? QM_BUY : QM_SELL;
   double entry_price = QM_EntryMarketPrice(side);
   if(entry_price <= 0.0)
      return false;

   // SL = 5-bar structure extreme, capped at ATR(14) x 1.5 (whichever is tighter).
   double structure_sl = QM_StopStructure(_Symbol, side, entry_price, strategy_sl_lookback_bars);
   double atr_sl = QM_StopATR(_Symbol, side, entry_price, strategy_atr_period, strategy_atr_sl_cap_mult);
   if(structure_sl <= 0.0 || atr_sl <= 0.0)
      return false;

   double structure_dist = MathAbs(entry_price - structure_sl);
   double atr_cap_dist = MathAbs(entry_price - atr_sl);
   double sl_price = (structure_dist <= atr_cap_dist) ? structure_sl : atr_sl;

   req.type = side;
   req.price = entry_price;
   req.sl = sl_price;
   req.tp = 0.0; // no fixed TP: half exits at 2R via partial-close, remainder trails on EMA50 break-back
   req.reason = long_setup ? "TC_M5_9_EMA_CASCADE_MACD_LONG" : "TC_M5_9_EMA_CASCADE_MACD_SHORT";
   return true;
}

// Half position exits at strategy_partial_tp_rr, remainder moves to breakeven.
void Strategy_ManageOpenPosition()
{
   static ulong  scale_ticket = 0;
   static double scale_initial_volume = 0.0;
   static bool   scale_partial_done = false;

   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   double open_price = 0.0;
   double sl = 0.0;
   double volume = 0.0;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   bool found = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong pos_ticket = PositionGetTicket(i);
      if(pos_ticket == 0 || !PositionSelectByTicket(pos_ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = pos_ticket;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      sl = PositionGetDouble(POSITION_SL);
      volume = PositionGetDouble(POSITION_VOLUME);
      found = true;
      break;
   }

   if(!found)
   {
      scale_ticket = 0;
      scale_initial_volume = 0.0;
      scale_partial_done = false;
      return;
   }

   if(ticket != scale_ticket)
   {
      scale_ticket = ticket;
      scale_initial_volume = volume;
      scale_partial_done = false;
   }

   if(open_price <= 0.0 || sl <= 0.0)
      return;

   const double stop_distance = MathAbs(open_price - sl);
   if(stop_distance <= 0.0)
      return;

   const bool is_buy = (position_type == POSITION_TYPE_BUY);
   const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(market_price <= 0.0)
      return;

   const double profit_distance = is_buy ? (market_price - open_price) : (open_price - market_price);
   const double r_multiple = profit_distance / stop_distance;

   const double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   const double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(min_lot <= 0.0 || step <= 0.0)
      return;

   if(!scale_partial_done && r_multiple >= strategy_partial_tp_rr)
   {
      const double requested_lots = scale_initial_volume * strategy_partial_close_fraction;
      const double close_lots = NormalizeDouble(MathFloor(requested_lots / step) * step, 8);
      if(close_lots > 0.0 && volume - close_lots >= min_lot && QM_TM_PartialClose(ticket, close_lots, QM_EXIT_PARTIAL))
         scale_partial_done = true;
      else if(close_lots <= 0.0 || volume - close_lots < min_lot)
         scale_partial_done = true; // nothing meaningful left to scale out; fall through to BE move
   }

   if(scale_partial_done)
   {
      if(!PositionSelectByTicket(ticket))
         return;
      sl = PositionGetDouble(POSITION_SL);
      const bool at_be = is_buy ? (sl >= open_price - _Point * 0.5) : (sl <= open_price + _Point * 0.5);
      if(!at_be)
         QM_TM_MoveSL(ticket, open_price, "partial_tp_move_to_be");
   }
}

// Remainder exits when price breaks back below/above EMA50 by the trail threshold.
bool Strategy_ExitSignal()
{
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

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
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      found = true;
      break;
   }
   if(!found)
      return false;

   double ema_fast_1 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   double close_1 = iClose(_Symbol, _Period, 1); // perf-allowed
   if(ema_fast_1 <= 0.0 || close_1 <= 0.0)
      return false;

   double trail_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_trail_exit_pips);
   if(trail_dist <= 0.0)
      return false;

   if(position_type == POSITION_TYPE_BUY && (ema_fast_1 - close_1) >= trail_dist)
      return true;
   if(position_type == POSITION_TYPE_SELL && (close_1 - ema_fast_1) >= trail_dist)
      return true;

   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
{
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { QM_FrameworkShutdown(); }

void OnTick()
{
   if(!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;
   
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;
   
   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
   {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
   }

   if(!QM_IsNewBar()) return;
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
   {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
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
