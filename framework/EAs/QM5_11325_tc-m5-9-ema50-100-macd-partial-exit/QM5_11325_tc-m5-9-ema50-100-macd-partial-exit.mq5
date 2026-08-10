#property strict
#property version   "5.0"
#property description "QM5_11325 TC-M5 System #9 — EMA(50/100) Cascade + MACD + Partial Exit"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11325;
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
input double strategy_partial_close_rr       = 2.0;
input double strategy_partial_close_pct      = 50.0;
input int    strategy_trail_exit_pips        = 10;
input int    strategy_max_spread_pips        = 15;

// -----------------------------------------------------------------------------
// Card: 20 Forex Trading Strategies (5 Minute Time Frame), Thomas Carter,
// 5 Min Trading System #9. Source: D:/QM/strategy_farm/artifacts/cards_approved/
// QM5_11325_tc-m5-9-ema50-100-macd-partial-exit.md
//
// Entry (LONG, SHORT mirrored): Close breaks above (below) both EMA(fast) and
// EMA(slow) by >= breakout_pips, measured off EMA(fast); MACD main crossed
// through zero in the trade direction within the last macd_lookback_bars
// closed bars. SL = lowest(highest) low/high of the last sl_lookback_bars
// bars, capped to atr_sl_cap_mult * ATR(atr_period) if that is tighter.
//
// Exit: at partial_close_rr * initial risk, close partial_close_pct% of the
// position and move SL on the remainder to breakeven (state is inferred from
// SL==open_price, no separate flag, mirrors QM5_1554 bressert idiom). Once at
// breakeven, the remainder exits when price closes back across EMA(fast) by
// trail_exit_pips against the trade.
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   if(strategy_ema_fast_period <= 0 ||
      strategy_ema_slow_period <= strategy_ema_fast_period ||
      strategy_breakout_pips <= 0 ||
      strategy_macd_fast <= 0 ||
      strategy_macd_slow <= strategy_macd_fast ||
      strategy_macd_signal <= 0 ||
      strategy_macd_lookback_bars <= 0 ||
      strategy_sl_lookback_bars <= 0 ||
      strategy_atr_period <= 0 ||
      strategy_atr_sl_cap_mult <= 0.0 ||
      strategy_partial_close_rr <= 0.0 ||
      strategy_partial_close_pct <= 0.0 || strategy_partial_close_pct >= 100.0 ||
      strategy_trail_exit_pips <= 0)
      return true;

   if(strategy_max_spread_pips > 0)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double max_spread_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_max_spread_pips);
      if(ask > bid && max_spread_dist > 0.0 && (ask - bid) > max_spread_dist)
         return true;
     }
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
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;

   const double close_1   = iClose(_Symbol, PERIOD_CURRENT, 1);
   const double ema_fast_1 = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_fast_period, 1, PRICE_CLOSE);
   const double ema_slow_1 = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_slow_period, 1, PRICE_CLOSE);
   if(close_1 <= 0.0 || ema_fast_1 <= 0.0 || ema_slow_1 <= 0.0)
      return false;

   const double breakout_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_breakout_pips);
   if(breakout_dist <= 0.0)
      return false;

   const bool long_setup  = (close_1 > ema_fast_1) && (close_1 > ema_slow_1) &&
                            ((close_1 - ema_fast_1) >= breakout_dist);
   const bool short_setup = (close_1 < ema_fast_1) && (close_1 < ema_slow_1) &&
                            ((ema_fast_1 - close_1) >= breakout_dist);
   if(!long_setup && !short_setup)
      return false;

   bool macd_cross_up = false;
   bool macd_cross_down = false;
   for(int s = 1; s <= strategy_macd_lookback_bars; ++s)
     {
      const double macd_new = QM_MACD_Main(_Symbol, PERIOD_CURRENT, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, s, PRICE_CLOSE);
      const double macd_old = QM_MACD_Main(_Symbol, PERIOD_CURRENT, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, s + 1, PRICE_CLOSE);
      if(macd_new > 0.0 && macd_old <= 0.0)
         macd_cross_up = true;
      if(macd_new < 0.0 && macd_old >= 0.0)
         macd_cross_down = true;
     }

   const bool go_long  = long_setup && macd_cross_up;
   const bool go_short = short_setup && macd_cross_down;
   if(!go_long && !go_short)
      return false;

   const QM_OrderType side = go_long ? QM_BUY : QM_SELL;
   const double entry = go_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double structure_sl = QM_StopStructure(_Symbol, side, entry, strategy_sl_lookback_bars);
   if(structure_sl <= 0.0)
      return false;

   double atr_value = 0.0;
   if(!QM_StopRulesReadATRValue(_Symbol, strategy_atr_period, 1, atr_value) || atr_value <= 0.0)
      return false;

   const double structure_dist = MathAbs(entry - structure_sl);
   const double atr_cap_dist   = atr_value * strategy_atr_sl_cap_mult;
   const double final_dist     = MathMin(structure_dist, atr_cap_dist);
   if(final_dist <= 0.0)
      return false;

   const double sl_price = go_long ? (entry - final_dist) : (entry + final_dist);

   req.type = side;
   req.price = 0.0;
   req.sl = NormalizeDouble(sl_price, _Digits);
   req.tp = 0.0;
   req.reason = go_long ? "TC_M5_9_EMA_MACD_PARTIAL_LONG" : "TC_M5_9_EMA_MACD_PARTIAL_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// Per-tick: at +partial_close_rr R, bank partial_close_pct% and move the
// remainder's SL to breakeven. Completion is inferred from SL==open_price
// (no separate state flag), same idiom as QM5_1554_bressert-double-cycle.
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

      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (ptype == POSITION_TYPE_BUY);
      if(open_price <= 0.0 || current_sl <= 0.0)
         continue;

      const bool be_done = is_buy ? (current_sl >= open_price) : (current_sl <= open_price);
      if(be_done)
         continue;

      const double risk_distance = MathAbs(open_price - current_sl);
      if(risk_distance <= 0.0)
         continue;

      const double target_price = is_buy ? (open_price + strategy_partial_close_rr * risk_distance)
                                         : (open_price - strategy_partial_close_rr * risk_distance);
      const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(market_price <= 0.0)
         continue;

      const bool target_hit = is_buy ? (market_price >= target_price) : (market_price <= target_price);
      if(!target_hit)
         continue;

      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double close_lots = QM_TM_NormalizeVolume(_Symbol, volume * strategy_partial_close_pct / 100.0);
      if(close_lots <= 0.0 || close_lots >= volume)
         continue;

      if(QM_TM_PartialClose(ticket, close_lots, QM_EXIT_PARTIAL))
         QM_TM_MoveSL(ticket, open_price, "partial_rr_move_to_breakeven");
     }
  }

// Remainder trail-exit: once the breakeven step above has run, close the
// rest when price closes back across EMA(fast) by trail_exit_pips.
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

      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (ptype == POSITION_TYPE_BUY);
      if(open_price <= 0.0 || current_sl <= 0.0)
         continue;

      const bool be_done = is_buy ? (current_sl >= open_price) : (current_sl <= open_price);
      if(!be_done)
         continue;

      const double ema_fast_1 = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_fast_period, 1, PRICE_CLOSE);
      const double trail_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_trail_exit_pips);
      const double close_1 = iClose(_Symbol, PERIOD_CURRENT, 1);
      if(ema_fast_1 <= 0.0 || trail_dist <= 0.0 || close_1 <= 0.0)
         continue;

      if(is_buy && close_1 <= (ema_fast_1 - trail_dist))
         return true;
      if(!is_buy && close_1 >= (ema_fast_1 + trail_dist))
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
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED,
                        PORTFOLIO_WEIGHT, qm_news_mode_legacy, qm_friday_close_enabled,
                        qm_friday_close_hour_broker, 30, 30, qm_news_stale_max_hours,
                        qm_news_min_impact, qm_rng_seed, qm_stress_reject_probability,
                        qm_news_temporal, qm_news_compliance))
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
         const ulong ticket = PositionGetTicket(i);
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
