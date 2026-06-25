#property strict
#property version   "5.0"
#property description "QM5_9702 ForexFactory MTF RSI Stack M5"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  — closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        — risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() — use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly —
//     use the QM_* readers above. The framework pools handles and releases them
//     on shutdown.
//   - CopyRates over warmup windows on every tick. If you genuinely need raw
//     bar arrays, gate by QM_IsNewBar so the work runs once per closed bar.
//   - Hand-edit framework/include/QM/QM_MagicResolver.mqh. After adding rows
//     to magic_numbers.csv, run:
//         python framework/scripts/update_magic_resolver.py
//     This is idempotent and preserves all rows.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9702;
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
input int    strategy_rsi_period          = 55;
input double strategy_rsi_midline         = 50.0;
input int    strategy_cross_lookback_bars = 2;
input int    strategy_adr_days            = 5;
input int    strategy_min_adr_pips        = 60;
input int    strategy_max_spread_pips     = 3;
input int    strategy_stop_pips           = 20;
input int    strategy_take_pips           = 25;
input double strategy_take_rr_cap         = 1.25;
input int    strategy_atr_period          = 14;
input double strategy_min_stop_atr_mult   = 0.50;
input int    strategy_session_start_hour  = 7;
input int    strategy_session_end_hour    = 22;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   bool session_open = true;
   if(strategy_session_start_hour != strategy_session_end_hour)
     {
      if(strategy_session_start_hour < strategy_session_end_hour)
         session_open = (dt.hour >= strategy_session_start_hour && dt.hour < strategy_session_end_hour);
      else
         session_open = (dt.hour >= strategy_session_start_hour || dt.hour < strategy_session_end_hour);
     }
   if(!session_open)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;
   if(ask > bid)
     {
      const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_max_spread_pips);
      if(spread_cap <= 0.0 || (ask - bid) > spread_cap)
         return true;
     }

   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(strategy_cross_lookback_bars < 1 || strategy_cross_lookback_bars > 2)
      return false;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   bool session_open = true;
   if(strategy_session_start_hour != strategy_session_end_hour)
     {
      if(strategy_session_start_hour < strategy_session_end_hour)
         session_open = (dt.hour >= strategy_session_start_hour && dt.hour < strategy_session_end_hour);
      else
         session_open = (dt.hour >= strategy_session_start_hour || dt.hour < strategy_session_end_hour);
     }
   if(!session_open)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;
   if(ask > bid)
     {
      const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_max_spread_pips);
      if(spread_cap <= 0.0 || (ask - bid) > spread_cap)
         return false;
     }

   double adr = 0.0;
   if(!QM_StopRulesReadADRValue(_Symbol, strategy_adr_days, adr))
      return false;
   const double min_adr = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_min_adr_pips);
   if(min_adr <= 0.0 || adr <= min_adr)
      return false;

   const double rsi_m1  = QM_RSI(_Symbol, PERIOD_M1,  strategy_rsi_period, 1, PRICE_CLOSE);
   const double rsi_m5  = QM_RSI(_Symbol, PERIOD_M5,  strategy_rsi_period, 1, PRICE_CLOSE);
   const double rsi_m15 = QM_RSI(_Symbol, PERIOD_M15, strategy_rsi_period, 1, PRICE_CLOSE);
   const double rsi_m30 = QM_RSI(_Symbol, PERIOD_M30, strategy_rsi_period, 1, PRICE_CLOSE);
   const double rsi_h1  = QM_RSI(_Symbol, PERIOD_H1,  strategy_rsi_period, 1, PRICE_CLOSE);
   const double rsi_m5_prev1 = QM_RSI(_Symbol, PERIOD_M5, strategy_rsi_period, 2, PRICE_CLOSE);
   const double rsi_m5_prev2 = QM_RSI(_Symbol, PERIOD_M5, strategy_rsi_period, 3, PRICE_CLOSE);

   if(rsi_m1 <= 0.0 || rsi_m5 <= 0.0 || rsi_m15 <= 0.0 || rsi_m30 <= 0.0 || rsi_h1 <= 0.0 ||
      rsi_m5_prev1 <= 0.0 || rsi_m5_prev2 <= 0.0)
      return false;

   const bool long_stack = (rsi_m1 > strategy_rsi_midline &&
                            rsi_m5 > strategy_rsi_midline &&
                            rsi_m15 > strategy_rsi_midline &&
                            rsi_m30 > strategy_rsi_midline &&
                            rsi_h1 > strategy_rsi_midline);
   const bool short_stack = (rsi_m1 < strategy_rsi_midline &&
                             rsi_m5 < strategy_rsi_midline &&
                             rsi_m15 < strategy_rsi_midline &&
                             rsi_m30 < strategy_rsi_midline &&
                             rsi_h1 < strategy_rsi_midline);
   const bool cross_up = (rsi_m5_prev1 <= strategy_rsi_midline && rsi_m5 > strategy_rsi_midline) ||
                         (strategy_cross_lookback_bars >= 2 &&
                          rsi_m5_prev2 <= strategy_rsi_midline && rsi_m5_prev1 > strategy_rsi_midline);
   const bool cross_down = (rsi_m5_prev1 >= strategy_rsi_midline && rsi_m5 < strategy_rsi_midline) ||
                           (strategy_cross_lookback_bars >= 2 &&
                            rsi_m5_prev2 >= strategy_rsi_midline && rsi_m5_prev1 < strategy_rsi_midline);

   if(!long_stack && !short_stack)
      return false;
   if(long_stack && !cross_up)
      return false;
   if(short_stack && !cross_down)
      return false;

   req.type = long_stack ? QM_BUY : QM_SELL;
   const double entry = long_stack ? ask : bid;
   req.sl = QM_StopFixedPips(_Symbol, req.type, entry, strategy_stop_pips);

   if(StringFind(_Symbol, "EURUSD") != 0)
     {
      const double atr = QM_ATR(_Symbol, PERIOD_M5, strategy_atr_period, 1);
      const double atr_sl = QM_StopATRFromValue(_Symbol, req.type, entry, atr, strategy_min_stop_atr_mult);
      if(atr_sl <= 0.0)
         return false;
      if(req.type == QM_BUY && atr_sl < req.sl)
         req.sl = atr_sl;
      if(req.type == QM_SELL && atr_sl > req.sl)
         req.sl = atr_sl;
     }

   const double tp_fixed = QM_TakeFixedPips(_Symbol, req.type, entry, strategy_take_pips);
   const double tp_rr = QM_TakeRR(_Symbol, req.type, entry, req.sl, strategy_take_rr_cap);
   if(req.sl <= 0.0 || tp_fixed <= 0.0 || tp_rr <= 0.0)
      return false;

   if(req.type == QM_BUY)
      req.tp = MathMin(tp_fixed, tp_rr);
   else
      req.tp = MathMax(tp_fixed, tp_rr);

   req.reason = long_stack ? "MTF_RSI_STACK_M5_LONG" : "MTF_RSI_STACK_M5_SHORT";
   return (req.tp > 0.0);
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, scale-in, or partial-close management.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
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

      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      bool session_open = true;
      if(strategy_session_start_hour != strategy_session_end_hour)
        {
         if(strategy_session_start_hour < strategy_session_end_hour)
            session_open = (dt.hour >= strategy_session_start_hour && dt.hour < strategy_session_end_hour);
         else
            session_open = (dt.hour >= strategy_session_start_hour || dt.hour < strategy_session_end_hour);
        }
      if(!session_open)
         return true;

      const double rsi_m15 = QM_RSI(_Symbol, PERIOD_M15, strategy_rsi_period, 1, PRICE_CLOSE);
      const double rsi_m15_prev = QM_RSI(_Symbol, PERIOD_M15, strategy_rsi_period, 2, PRICE_CLOSE);
      if(rsi_m15 <= 0.0 || rsi_m15_prev <= 0.0)
         return false;

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(position_type == POSITION_TYPE_BUY &&
         rsi_m15_prev >= strategy_rsi_midline &&
         rsi_m15 < strategy_rsi_midline)
         return true;
      if(position_type == POSITION_TYPE_SELL &&
         rsi_m15_prev <= strategy_rsi_midline &&
         rsi_m15 > strategy_rsi_midline)
         return true;
     }

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
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

