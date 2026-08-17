#property strict
#property version   "5.0"
#property description "QM5_35002 Huck Loves Her Bucks (HLHB) Trend-Catcher System"
// Strategy Card: QM5_35002 (hlhb-trend-catcher-system), G0 APPROVED 2026-08-15.

#include <QM/QM_Common.mqh>
#include <Trade/Trade.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_35002
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 35002;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.5;
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
input int    strategy_fast_ema            = 5;      // Fast EMA period (H1)
input int    strategy_slow_ema            = 10;     // Slow EMA period (H1)
input int    strategy_rsi_period          = 10;     // RSI period (H1)
input int    strategy_adx_period          = 14;     // ADX period (H1)
input double strategy_adx_min             = 25.0;   // Minimum ADX trend strength threshold
input double strategy_sl_pips             = 50.0;   // Initial Stop Loss distance in pips
input double strategy_trail_trigger_pips  = 30.0;   // Trailing trigger profit in pips
input double strategy_trail_dist_pips     = 50.0;   // Trailing Stop distance in pips
input double strategy_tp_rr_mult          = 2.0;    // 1:2.0 Risk:Reward multiplier for TP
input int    strategy_atr_period          = 14;     // ATR period for spread/fallback
input double strategy_spread_atr_mult     = 1.8;    // Spread filter ATR multiplier

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

int GetBarHhmm(const datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.hour * 100 + dt.min);
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   const datetime now = TimeCurrent();
   const int hhmm = GetBarHhmm(now);
   if(hhmm >= 2355 || hhmm < 5)
      return true;

   const double atr_1 = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask > 0.0 && bid > 0.0 && ask > bid && point > 0.0 && atr_1 > 0.0)
   {
      const double spread_pts = (ask - bid) / point;
      const double atr_pts = atr_1 / point;
      if(spread_pts > strategy_spread_atr_mult * atr_pts)
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
   if(magic <= 0)
      return false;

   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   // 1. Evaluate H1 Indicators on completed bars (Shift = 1 and Shift = 2)
   const double fast_ema_1 = QM_EMA(_Symbol, PERIOD_H1, strategy_fast_ema, 1);
   const double slow_ema_1 = QM_EMA(_Symbol, PERIOD_H1, strategy_slow_ema, 1);
   const double fast_ema_2 = QM_EMA(_Symbol, PERIOD_H1, strategy_fast_ema, 2);
   const double slow_ema_2 = QM_EMA(_Symbol, PERIOD_H1, strategy_slow_ema, 2);

   if(fast_ema_1 <= 0.0 || slow_ema_1 <= 0.0 || fast_ema_2 <= 0.0 || slow_ema_2 <= 0.0)
      return false;

   const double rsi_1 = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, 1);
   if(rsi_1 <= 0.0)
      return false;

   const double adx_1      = QM_ADX(_Symbol, PERIOD_H1, strategy_adx_period, 1);
   const double plus_di_1  = QM_ADX_PlusDI(_Symbol, PERIOD_H1, strategy_adx_period, 1);
   const double minus_di_1 = QM_ADX_MinusDI(_Symbol, PERIOD_H1, strategy_adx_period, 1);

   if(adx_1 < strategy_adx_min)
      return false;

   const bool ema_cross_buy  = (fast_ema_1 > slow_ema_1 && fast_ema_2 <= slow_ema_2);
   const bool ema_cross_sell = (fast_ema_1 < slow_ema_1 && fast_ema_2 >= slow_ema_2);

   const double pip_size = QM_StopRulesPipsToPriceDistance(_Symbol, 1.0);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(pip_size <= 0.0 || point <= 0.0)
      return false;

   const double atr_1 = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   const double min_sl_dist = (atr_1 > 0.0) ? (0.5 * atr_1) : (10.0 * pip_size);
   const double max_sl_dist = (atr_1 > 0.0) ? (3.5 * atr_1) : (150.0 * pip_size);

   double base_sl_dist = strategy_sl_pips * pip_size;
   if(base_sl_dist < min_sl_dist)
      base_sl_dist = min_sl_dist;
   else if(base_sl_dist > max_sl_dist)
      base_sl_dist = max_sl_dist;

   // 2. Long Entry Evaluation
   if(ema_cross_buy && rsi_1 > 50.0 && plus_di_1 > minus_di_1)
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double exec_price = (ask > 0.0) ? ask : iClose(_Symbol, PERIOD_H1, 1); // perf-allowed: closed-bar close behind QM_IsNewBar()

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = exec_price - base_sl_dist;
      req.tp = exec_price + strategy_tp_rr_mult * base_sl_dist;
      req.reason = "hlhb_long";
      return true;
   }

   // 3. Short Entry Evaluation
   if(ema_cross_sell && rsi_1 < 50.0 && minus_di_1 > plus_di_1)
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double exec_price = (bid > 0.0) ? bid : iClose(_Symbol, PERIOD_H1, 1); // perf-allowed: closed-bar close behind QM_IsNewBar()

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = exec_price + base_sl_dist;
      req.tp = exec_price - strategy_tp_rr_mult * base_sl_dist;
      req.reason = "hlhb_short";
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0) return;
   const double pip_size = QM_StopRulesPipsToPriceDistance(_Symbol, 1.0);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(pip_size <= 0.0 || point <= 0.0) return;

   const double trigger_dist = strategy_trail_trigger_pips * pip_size;
   const double trail_dist   = strategy_trail_dist_pips * pip_size;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);

      if(pos_type == POSITION_TYPE_BUY)
      {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid <= 0.0 || open_price <= 0.0) continue;

         if((bid - open_price) >= trigger_dist)
         {
            const double target_sl = QM_TM_NormalizePrice(_Symbol, bid - trail_dist);
            if(target_sl > current_sl + point * 0.5)
               QM_TM_MoveSL(ticket, target_sl, "hlhb_trailing_stop");
         }
      }
      else if(pos_type == POSITION_TYPE_SELL)
      {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask <= 0.0 || open_price <= 0.0) continue;

         if((open_price - ask) >= trigger_dist)
         {
            const double target_sl = QM_TM_NormalizePrice(_Symbol, ask + trail_dist);
            if(current_sl <= 0.0 || target_sl < current_sl - point * 0.5)
               QM_TM_MoveSL(ticket, target_sl, "hlhb_trailing_stop");
         }
      }
   }
}

bool Strategy_ExitSignal()
{
   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time)
{
   return false;
}

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

void OnDeinit(const int reason)
{
   QM_FrameworkShutdown();
}

void OnTick()
{
   QM_FrameworkTrackOpenPositionMae();
   if(!QM_KillSwitchCheck()) return;
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

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;
   
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;

   if(!QM_IsNewBar()) return;
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

void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
