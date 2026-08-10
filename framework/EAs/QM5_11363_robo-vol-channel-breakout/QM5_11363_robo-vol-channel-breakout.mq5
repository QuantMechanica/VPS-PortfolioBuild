#property strict
#property version   "5.0"
#property description "QM5_11363 RoboForex -- Dual ATR Volatility Channel Breakout (M15)"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11363;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_ema_wide                = 5;
input int    strategy_atr_wide_period         = 30;
input int    strategy_ema_tight               = 4;
input int    strategy_atr_tight_period        = 14;
input double strategy_atr_tp_mult             = 2.0;
input int    strategy_sl_cap_pips             = 20;
input double strategy_min_atr_pips            = 5.0;
input int    strategy_max_spread_pips         = 15;

// -----------------------------------------------------------------------------
// Card: RoboForex, Forex Trading Strategies Collection -- Volatility Channel
// Breakout. Source: D:/QM/strategy_farm/artifacts/cards_approved/
// QM5_11363_robo-vol-channel-breakout.md
//
// Dual ATR/EMA channel: a wide channel (EMA(5) +/- ATR(30)) and a tight
// channel (EMA(4) +/- ATR(14)). Both must be violated in the same direction
// on the same closed bar for a valid breakout; entry at next bar open. SL
// at the wide-channel EMA (or ATR(30) distance if too close), capped. TP at
// ATR(14) x 2.0. Minimum-volatility gate: ATR(14) must exceed a pip floor.
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   if(strategy_atr_tp_mult <= 0.0 || strategy_sl_cap_pips <= 0)
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

   const double ema5_1  = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_wide, 1);
   const double atr30_1 = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_wide_period, 1);
   const double ema4_1  = QM_EMA(_Symbol, PERIOD_CURRENT, strategy_ema_tight, 1);
   const double atr14_1 = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_tight_period, 1);
   const double close_1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   if(ema5_1 <= 0.0 || atr30_1 <= 0.0 || ema4_1 <= 0.0 || atr14_1 <= 0.0 || close_1 <= 0.0)
      return false;

   if(strategy_min_atr_pips > 0.0)
     {
      const double min_atr_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(strategy_min_atr_pips));
      if(min_atr_dist > 0.0 && atr14_1 < min_atr_dist)
         return false;
     }

   const double wide_upper  = ema5_1 + atr30_1;
   const double wide_lower  = ema5_1 - atr30_1;
   const double tight_upper = ema4_1 + atr14_1;
   const double tight_lower = ema4_1 - atr14_1;

   const bool go_long  = (close_1 > wide_upper) && (close_1 > tight_upper);
   const bool go_short = (close_1 < wide_lower) && (close_1 < tight_lower);
   if(!go_long && !go_short)
      return false;

   const QM_OrderType side = go_long ? QM_BUY : QM_SELL;
   const double entry = go_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double cap_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
   double sl_dist = go_long ? (entry - ema5_1) : (ema5_1 - entry);
   if(sl_dist <= 0.0)
      sl_dist = atr30_1;
   if(cap_dist > 0.0)
      sl_dist = MathMin(sl_dist, cap_dist);
   const double tp_dist = atr14_1 * strategy_atr_tp_mult;
   if(sl_dist <= 0.0 || tp_dist <= 0.0)
      return false;

   const double sl_price = go_long ? (entry - sl_dist) : (entry + sl_dist);
   const double tp_price = go_long ? (entry + tp_dist) : (entry - tp_dist);

   req.type = side;
   req.price = 0.0;
   req.sl = NormalizeDouble(sl_price, _Digits);
   req.tp = NormalizeDouble(tp_price, _Digits);
   req.reason = go_long ? "ROBO_VOLCHANNEL_LONG" : "ROBO_VOLCHANNEL_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return (req.sl > 0.0 && req.tp > 0.0);
  }

bool Strategy_ExitSignal() { return false; }

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
