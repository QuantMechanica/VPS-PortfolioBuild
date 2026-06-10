#property strict
#property version   "5.0"
#property description "QuantMechanica V5 — RSI Failure Swing Reversal"

#include <QM/QM_Common.mqh>
#include <QM/QM_Signals.mqh>
#include <QM/QM_StopRules.mqh>

// =============================================================================
// QM5_9212 — mql5-rsi-fail
// RSI(14) failure-swing reversal on H1. Buy when RSI crosses back above 30
// (from below), sell when RSI crosses back below 70 (from above). Exit at RSI
// 50, opposite signal, or hard 2R TP. ATR-vs-structure stop, volatility filter.
// Source: Stephen Njuki, MQL5 Articles 2024-09-18 (Part 39).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9212;
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
input int    strategy_rsi_period        = 14;
input double strategy_rsi_oversold      = 30.0;
input double strategy_rsi_overbought    = 70.0;
input int    strategy_atr_sl_period     = 14;
input double strategy_atr_sl_mult       = 1.5;
input int    strategy_atr_filter_fast   = 14;
input int    strategy_atr_filter_slow   = 100;
input double strategy_atr_filter_ratio  = 0.5;
input double strategy_tp_rr             = 2.0;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   double atr_fast = QM_ATR(_Symbol, _Period, strategy_atr_filter_fast, 1);
   double atr_slow = QM_ATR(_Symbol, _Period, strategy_atr_filter_slow, 1);
   if(atr_fast <= 0.0 || atr_slow <= 0.0)
      return true; // block if data unavailable
   return (atr_fast < strategy_atr_filter_ratio * atr_slow);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   int sig = QM_Sig_RSI_Reversal(_Symbol, _Period,
                                  strategy_rsi_period,
                                  strategy_rsi_oversold,
                                  strategy_rsi_overbought,
                                  1);
   if(sig == 0)
      return false;

   int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) == magic &&
         PositionGetString(POSITION_SYMBOL) == _Symbol)
         return false; // one position per magic/symbol
     }

   QM_OrderType side = (sig > 0) ? QM_BUY : QM_SELL;
   double entry = (side == QM_BUY)
                  ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                  : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   double sl_atr    = QM_StopATR(_Symbol, side, entry, strategy_atr_sl_period, strategy_atr_sl_mult);
   double sl_struct = QM_StopStructure(_Symbol, side, entry, 1);
   double sl_price  = 0.0;
   if(sl_atr <= 0.0 && sl_struct <= 0.0)
      return false;
   else if(sl_atr <= 0.0)
      sl_price = sl_struct;
   else if(sl_struct <= 0.0)
      sl_price = sl_atr;
   else
      sl_price = (side == QM_BUY) ? MathMin(sl_atr, sl_struct)
                                   : MathMax(sl_atr, sl_struct);

   double sl_dist_price = MathAbs(entry - sl_price);
   if(sl_dist_price <= 0.0)
      return false;

   double point     = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;
   double sl_points = sl_dist_price / point;
   double lots      = QM_LotsForRisk(_Symbol, sl_points);
   if(lots <= 0.0)
      return false;

   double tp_price = QM_TakeRR(_Symbol, side, entry, sl_price, strategy_tp_rr);

   req.type   = side;
   req.price  = entry;
   req.sl     = sl_price;
   req.tp     = tp_price;
   req.reason = (sig > 0) ? "RSI_FAIL_BUY" : "RSI_FAIL_SELL";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // SL/TP are hard-set at entry. No trailing or breakeven for this strategy.
  }

bool Strategy_ExitSignal()
  {
   if(!QM_IsNewBar())
      return false;

   int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double rsi_curr = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
      double rsi_prev = QM_RSI(_Symbol, _Period, strategy_rsi_period, 2);

      if(ptype == POSITION_TYPE_BUY)
        {
         if(rsi_curr >= 50.0)
            return true;
         if(rsi_prev > strategy_rsi_overbought && rsi_curr <= strategy_rsi_overbought)
            return true;
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         if(rsi_curr <= 50.0)
            return true;
         if(rsi_prev < strategy_rsi_oversold && rsi_curr >= strategy_rsi_oversold)
            return true;
        }
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line.
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
