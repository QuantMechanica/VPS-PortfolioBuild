#property strict
#property version   "5.0"
#property description "QM5_9228 MQL5 Alligator Teeth Close Trigger"
// Strategy Card: ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb (mql5-alligator-teeth), G0 APPROVED 2026-05-19.
// Source: Mohamed Abdelmaaboud, "Learn how to design a trading system by Alligator",
//         MQL5 Articles, 2022-10-12 (see SPEC.md for full citation URL).

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9228;
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
// Alligator Jaws: SMMA(13) shifted 8 bars forward on PRICE_MEDIAN
input int    strategy_jaw_period        = 13;
input int    strategy_jaw_shift         = 8;
// Alligator Teeth: SMMA(8) shifted 5 bars forward on PRICE_MEDIAN
input int    strategy_teeth_period      = 8;
input int    strategy_teeth_shift       = 5;
// Alligator Lips: SMMA(5) shifted 3 bars forward on PRICE_MEDIAN
input int    strategy_lips_period       = 5;
input int    strategy_lips_shift        = 3;
// ATR stop/filter parameters
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 1.8;
input double strategy_atr_tp_mult       = 2.2;   // R-multiple (2.2R take profit)
input int    strategy_atr_slow_period   = 100;
input double strategy_atr_slow_ratio    = 0.5;   // Block if ATR14 < 0.5 * ATR100
// Time exit after N H1 bars
input int    strategy_max_hold_bars     = 60;

// =============================================================================
// Strategy hooks
// =============================================================================

// Return TRUE to BLOCK trading this tick.
bool Strategy_NoTradeFilter()
  {
   // Volatility regime filter: block when ATR(14) < 0.5 * ATR(100).
   // Both reads use pooled handles — O(1) per tick.
   const double atr_fast = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period);
   const double atr_slow = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_slow_period);
   if(atr_slow > 0.0 && atr_fast < strategy_atr_slow_ratio * atr_slow)
      return true;
   return false;
  }

// Build Alligator line values at the last closed bar.
// The Alligator shifts its SMMA forward by jaw_shift/teeth_shift/lips_shift bars,
// so reading bar[1+shift] of the unshifted SMMA yields the display value at bar[1].
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Alligator lines at last closed bar (bar index = 1 + visual_shift)
   const int j_idx = strategy_jaw_shift   + 1;   // = 9
   const int t_idx = strategy_teeth_shift + 1;   // = 6
   const int l_idx = strategy_lips_shift  + 1;   // = 4

   const double jaw   = QM_SMMA(_Symbol, PERIOD_H1, strategy_jaw_period,   j_idx, PRICE_MEDIAN);
   const double teeth = QM_SMMA(_Symbol, PERIOD_H1, strategy_teeth_period, t_idx, PRICE_MEDIAN);
   const double lips  = QM_SMMA(_Symbol, PERIOD_H1, strategy_lips_period,  l_idx, PRICE_MEDIAN);

   // Previous bar Teeth for crossover detection
   const double teeth_p = QM_SMMA(_Symbol, PERIOD_H1, strategy_teeth_period, t_idx + 1, PRICE_MEDIAN);

   // Close prices for cross detection — single fixed-shift bar reads
   const double close1 = iClose(_Symbol, PERIOD_H1, 1); // perf-allowed: bespoke Alligator cross logic
   const double close2 = iClose(_Symbol, PERIOD_H1, 2); // perf-allowed: bespoke Alligator cross logic

   if(jaw <= 0.0 || teeth <= 0.0 || lips <= 0.0 || close1 <= 0.0)
      return false;

   // One position per magic — skip if already in a trade
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic) return false;
     }

   // Entry at next bar open (market order); use current Ask/Bid as proxy for open price
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0) return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period);
   if(atr <= 0.0) return false;

   req.symbol_slot       = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // Long: Lips < Teeth, Lips < Jaws, close crosses above Teeth
   if(lips < teeth && lips < jaw && close1 > teeth && close2 <= teeth_p)
     {
      const double sl = QM_StopATR(_Symbol, QM_BUY, ask, strategy_atr_period, strategy_atr_sl_mult);
      const double sl_dist = ask - sl;
      if(sl_dist <= 0.0) return false;
      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = ask + sl_dist * strategy_atr_tp_mult;
      req.reason = "ALLIGATOR_LONG";
      return true;
     }

   // Short: Lips > Teeth, Lips > Jaws, close crosses below Teeth
   if(lips > teeth && lips > jaw && close1 < teeth && close2 >= teeth_p)
     {
      const double sl = QM_StopATR(_Symbol, QM_SELL, bid, strategy_atr_period, strategy_atr_sl_mult);
      const double sl_dist = sl - bid;
      if(sl_dist <= 0.0) return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = bid - sl_dist * strategy_atr_tp_mult;
      req.reason = "ALLIGATOR_SHORT";
      return true;
     }

   return false;
  }

// No active trade management — SL/TP set at entry.
void Strategy_ManageOpenPosition()
  {
  }

// Exit on signal reversal (new bar) or failsafe time stop.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();

   // Locate our position
   ulong ticket = 0;
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   datetime open_time = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      ticket    = t;
      ptype     = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      break;
     }

   if(ticket == 0) return false;

   // Failsafe time exit: 60 H1 bars from open
   const long hold_secs = (long)(TimeCurrent() - open_time);
   if(hold_secs >= (long)strategy_max_hold_bars * PeriodSeconds(PERIOD_H1))
      return true;

   // Signal-based exits run on closed-bar cadence only
   if(!QM_IsNewBar()) return false;

   const int t_idx  = strategy_teeth_shift + 1;
   const int l_idx  = strategy_lips_shift  + 1;
   const int j_idx  = strategy_jaw_shift   + 1;

   const double teeth   = QM_SMMA(_Symbol, PERIOD_H1, strategy_teeth_period, t_idx,     PRICE_MEDIAN);
   const double teeth_p = QM_SMMA(_Symbol, PERIOD_H1, strategy_teeth_period, t_idx + 1, PRICE_MEDIAN);
   const double lips    = QM_SMMA(_Symbol, PERIOD_H1, strategy_lips_period,  l_idx,     PRICE_MEDIAN);
   const double lips_p  = QM_SMMA(_Symbol, PERIOD_H1, strategy_lips_period,  l_idx + 1, PRICE_MEDIAN);
   const double jaw     = QM_SMMA(_Symbol, PERIOD_H1, strategy_jaw_period,   j_idx,     PRICE_MEDIAN);

   const double close1 = iClose(_Symbol, PERIOD_H1, 1); // perf-allowed: bespoke Alligator cross logic
   const double close2 = iClose(_Symbol, PERIOD_H1, 2); // perf-allowed: bespoke Alligator cross logic

   if(ptype == POSITION_TYPE_BUY)
     {
      // Exit long: close crosses back below Teeth
      if(close1 < teeth && close2 >= teeth_p)
         return true;
      // Exit long: Lips reversal — Lips crosses above both Teeth and Jaws
      if(lips > teeth && lips > jaw && (lips_p <= teeth_p || lips_p <= jaw))
         return true;
     }
   else
     {
      // Exit short: close crosses back above Teeth
      if(close1 > teeth && close2 <= teeth_p)
         return true;
      // Exit short: Lips reversal — Lips crosses below both Teeth and Jaws
      if(lips < teeth && lips < jaw && (lips_p >= teeth_p || lips_p >= jaw))
         return true;
     }

   return false;
  }

// Defer news filtering to framework.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// =============================================================================
// Framework wiring — do NOT edit below this line.
// =============================================================================

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"mql5-alligator-teeth\",\"ea\":\"QM5_9228\"}");
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
         const ulong t = PositionGetTicket(i);
         if(!PositionSelectByTicket(t)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(t, QM_EXIT_STRATEGY);
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
