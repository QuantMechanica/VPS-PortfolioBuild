#property strict
#property version   "5.0"
#property description "QM5_11518 Carter-T EMA(5/100) MTF: H1 Filter + M15 Entry"
// Strategy Card: QM5_11518 (carter-t-ema5-100-mtf-m15-h1), G0 APPROVED.

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_11518
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 11518;
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
input int    strategy_fast_ema_period     = 5;      // Fast EMA period
input int    strategy_slow_ema_period     = 100;    // Slow EMA period
input int    strategy_sl_pips             = 15;     // Fixed stop loss in pips
input int    strategy_tp_pips             = 30;     // Fixed take profit in pips
input int    strategy_max_spread_pips     = 12;     // Max allowable spread in pips

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask > 0.0 && bid > 0.0 && ask > bid && strategy_max_spread_pips > 0)
   {
      const double max_spread_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_max_spread_pips);
      if(max_spread_dist > 0.0 && (ask - bid) > max_spread_dist)
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

   // Higher Timeframe (H1) Trend Filter (Shift 1 closed bar)
   const double h1_fast = QM_EMA(_Symbol, PERIOD_H1, strategy_fast_ema_period, 1);
   const double h1_slow = QM_EMA(_Symbol, PERIOD_H1, strategy_slow_ema_period, 1);
   if(h1_fast <= 0.0 || h1_slow <= 0.0)
      return false;

   // Intraday (M15) EMA Crossover (Bar 1 vs Bar 2)
   const double m15_fast_1 = QM_EMA(_Symbol, PERIOD_M15, strategy_fast_ema_period, 1);
   const double m15_slow_1 = QM_EMA(_Symbol, PERIOD_M15, strategy_slow_ema_period, 1);
   const double m15_fast_2 = QM_EMA(_Symbol, PERIOD_M15, strategy_fast_ema_period, 2);
   const double m15_slow_2 = QM_EMA(_Symbol, PERIOD_M15, strategy_slow_ema_period, 2);
   if(m15_fast_1 <= 0.0 || m15_slow_1 <= 0.0 || m15_fast_2 <= 0.0 || m15_slow_2 <= 0.0)
      return false;

   const bool m15_cross_up = (m15_fast_1 > m15_slow_1 && m15_fast_2 <= m15_slow_2);
   const bool m15_cross_down = (m15_fast_1 < m15_slow_1 && m15_fast_2 >= m15_slow_2);

   // LONG: H1 bullish regime + M15 fresh golden cross
   if(h1_fast > h1_slow && m15_cross_up)
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask <= 0.0)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_StopFixedPips(_Symbol, QM_BUY, ask, strategy_sl_pips);
      const double rr = (strategy_sl_pips > 0) ? ((double)strategy_tp_pips / (double)strategy_sl_pips) : 2.0;
      req.tp = QM_TakeRR(_Symbol, QM_BUY, ask, req.sl, rr);
      req.reason = "Carter-T EMA5/100 MTF Bullish Cross";
      return true;
   }

   // SHORT: H1 bearish regime + M15 fresh death cross
   if(h1_fast < h1_slow && m15_cross_down)
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_StopFixedPips(_Symbol, QM_SELL, bid, strategy_sl_pips);
      const double rr = (strategy_sl_pips > 0) ? ((double)strategy_tp_pips / (double)strategy_sl_pips) : 2.0;
      req.tp = QM_TakeRR(_Symbol, QM_SELL, bid, req.sl, rr);
      req.reason = "Carter-T EMA5/100 MTF Bearish Cross";
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
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
   if(!QM_KillSwitchCheck())
      return;
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
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
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
   }

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

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

void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
