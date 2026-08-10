#property strict
#property version   "5.0"
#property description "QM5_11388 Russ Horn Golden Strategy — SMMA(55) Channel + WPR(55) + Stoch(5,5,5)"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11388;
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
input int    strategy_smma_period            = 55;
input int    strategy_wpr_period             = 55;
input double strategy_wpr_overbought_level    = -25.0;
input double strategy_wpr_oversold_level      = -75.0;
input int    strategy_stoch_k_period         = 5;
input int    strategy_stoch_d_period         = 5;
input int    strategy_stoch_slowing          = 5;
input int    strategy_atr_period             = 14;
input double strategy_atr_sl_mult            = 1.0;
input int    strategy_sl_cap_pips            = 20;
input double strategy_tp_rr                  = 2.0;
input int    strategy_max_spread_pips        = 15;

// -----------------------------------------------------------------------------
// Card: "The Golden Strategy" by Russ Horn (RapidResultsMethod.com). Source:
// D:/QM/strategy_farm/artifacts/cards_approved/
// QM5_11388_russ-horn-golden-smma55-wpr55-stoch555.md
//
// Entry (LONG, SHORT mirrored): Close beyond the SMMA(55) High/Low channel,
// Williams %R(55) crosses the overbought/oversold level in the trade
// direction, Stochastic(5,5,5) %K vs %D confirms. Fixed SL = ATR(14)*mult
// capped to sl_cap_pips, TP = tp_rr * SL distance. No partial exit / trail
// (P2 baseline card; P3 adds an optional ATR trail).
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   if(strategy_smma_period <= 0 ||
      strategy_wpr_period <= 0 ||
      strategy_wpr_overbought_level <= -100.0 || strategy_wpr_overbought_level >= 0.0 ||
      strategy_wpr_oversold_level <= -100.0 || strategy_wpr_oversold_level >= 0.0 ||
      strategy_wpr_oversold_level >= strategy_wpr_overbought_level ||
      strategy_stoch_k_period <= 0 || strategy_stoch_d_period <= 0 || strategy_stoch_slowing <= 0 ||
      strategy_atr_period <= 0 ||
      strategy_atr_sl_mult <= 0.0 ||
      strategy_sl_cap_pips <= 0 ||
      strategy_tp_rr <= 0.0)
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

   const double close_1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   const double smma_high_1 = QM_SMMA(_Symbol, PERIOD_CURRENT, strategy_smma_period, 1, PRICE_HIGH);
   const double smma_low_1  = QM_SMMA(_Symbol, PERIOD_CURRENT, strategy_smma_period, 1, PRICE_LOW);
   if(close_1 <= 0.0 || smma_high_1 <= 0.0 || smma_low_1 <= 0.0)
      return false;

   const double wpr_1 = QM_WPR(_Symbol, PERIOD_CURRENT, strategy_wpr_period, 1);
   const double wpr_2 = QM_WPR(_Symbol, PERIOD_CURRENT, strategy_wpr_period, 2);
   if(wpr_1 > 0.0 || wpr_1 < -100.0 || wpr_2 > 0.0 || wpr_2 < -100.0)
      return false;

   const double stoch_k_1 = QM_Stoch_K(_Symbol, PERIOD_CURRENT, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double stoch_d_1 = QM_Stoch_D(_Symbol, PERIOD_CURRENT, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 1);

   const bool wpr_cross_up   = (wpr_2 <= strategy_wpr_overbought_level) && (wpr_1 > strategy_wpr_overbought_level);
   const bool wpr_cross_down = (wpr_2 >= strategy_wpr_oversold_level)   && (wpr_1 < strategy_wpr_oversold_level);

   const bool go_long  = (close_1 > smma_high_1) && wpr_cross_up   && (stoch_k_1 > stoch_d_1);
   const bool go_short = (close_1 < smma_low_1)  && wpr_cross_down && (stoch_k_1 < stoch_d_1);
   if(!go_long && !go_short)
      return false;

   const QM_OrderType side = go_long ? QM_BUY : QM_SELL;
   const double entry = go_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   double atr_value = 0.0;
   if(!QM_StopRulesReadATRValue(_Symbol, strategy_atr_period, 1, atr_value) || atr_value <= 0.0)
      return false;

   const double atr_dist = atr_value * strategy_atr_sl_mult;
   const double cap_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
   const double final_dist = (cap_dist > 0.0) ? MathMin(atr_dist, cap_dist) : atr_dist;
   if(final_dist <= 0.0)
      return false;

   const double sl_price = go_long ? (entry - final_dist) : (entry + final_dist);
   const double tp_price = QM_TakeRR(_Symbol, side, entry, sl_price, strategy_tp_rr);
   if(tp_price <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = NormalizeDouble(sl_price, _Digits);
   req.tp = NormalizeDouble(tp_price, _Digits);
   req.reason = go_long ? "RUSS_HORN_GOLDEN_LONG" : "RUSS_HORN_GOLDEN_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// P2 baseline card has no trailing, break-even, or partial-close logic —
// fixed SL/TP only (P3 variant adds an optional ATR trail).
void Strategy_ManageOpenPosition() { }

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
