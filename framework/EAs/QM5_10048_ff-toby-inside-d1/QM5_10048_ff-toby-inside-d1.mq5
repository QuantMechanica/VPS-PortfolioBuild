#property strict
#property version   "5.0"
#property description "QM5_10048 ForexFactory Toby Inside-Bar D1 Breakout"

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
input int    qm_ea_id                   = 10048;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
// All other phases use 42 by default. Stress / noise dimensions read from
// this single seed so reproducibility is guaranteed across re-runs.
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// FW1 2026-05-23 — Two-axis news filter per Vault Q09.
//   AXIS A (temporal): per-event behaviour. Default mode 3 = pause 30min pre+post.
//   AXIS B (compliance): prop-firm blackout overlay. Default DXZ = no extra rules.
// A trade is allowed only if BOTH axes allow. See Vault `Q09 News Impact Mode`.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
// Legacy single-mode input kept for back-compat with pre-FW1 setfiles.
// New EAs use qm_news_temporal + qm_news_compliance above and leave this OFF.
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 — only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_sma_period        = 21;
input int    strategy_entry_buffer_pips = 5;
input double strategy_tp_r_multiple     = 2.0;
input double strategy_max_spread_sl_frac = 0.12;
input int    strategy_fallback_stop_pips = 50;
input int    strategy_fallback_atr_period = 14;
input double strategy_fallback_atr_mult = 1.25;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

int Strategy_SourceStopPips()
  {
   if(StringFind(_Symbol, "GBPJPY") >= 0)
      return 100;
   if(StringFind(_Symbol, "EURJPY") >= 0)
      return 90;
   if(StringFind(_Symbol, "GBPUSD") >= 0 || StringFind(_Symbol, "USDCAD") >= 0)
      return 60;
   if(StringFind(_Symbol, "EURUSD") >= 0 || StringFind(_Symbol, "USDCHF") >= 0 ||
      StringFind(_Symbol, "NZDUSD") >= 0 || StringFind(_Symbol, "AUDUSD") >= 0 ||
      StringFind(_Symbol, "USDJPY") >= 0)
      return 50;
   return 0;
  }

double Strategy_StopDistancePrice()
  {
   const int source_stop_pips = Strategy_SourceStopPips();
   if(source_stop_pips > 0)
      return QM_StopRulesPipsToPriceDistance(_Symbol, source_stop_pips);

   const double fixed_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_fallback_stop_pips);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_fallback_atr_period, 1);
   if(atr <= 0.0)
      return fixed_distance;
   return MathMax(fixed_distance, strategy_fallback_atr_mult * atr);
  }

int Strategy_SmaSlopeDirection()
  {
   const double sma1 = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 1);
   const double sma2 = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 2);
   if(sma1 <= 0.0 || sma2 <= 0.0 || sma1 == sma2)
      return 0;
   return (sma1 > sma2) ? 1 : -1;
  }

int Strategy_CurrentInsideBarSetupDirection()
  {
   const double high1 = iHigh(_Symbol, PERIOD_D1, 1);
   const double low1 = iLow(_Symbol, PERIOD_D1, 1);
   const double high2 = iHigh(_Symbol, PERIOD_D1, 2);
   const double low2 = iLow(_Symbol, PERIOD_D1, 2);
   if(high1 <= 0.0 || low1 <= 0.0 || high2 <= 0.0 || low2 <= 0.0)
      return 0;
   if(!(high1 < high2 && low1 > low2))
      return 0;
   return Strategy_SmaSlopeDirection();
  }

bool Strategy_HasOurPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool Strategy_IsOurPendingStopType(const ENUM_ORDER_TYPE type)
  {
   return (type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP);
  }

bool Strategy_HasOurPendingStop()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(Strategy_IsOurPendingStopType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         return true;
     }
   return false;
  }

void Strategy_CancelPendingOrder(const ulong ticket)
  {
   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);
   request.action = TRADE_ACTION_REMOVE;
   request.order = ticket;
   OrderSend(request, result);
  }

void Strategy_CancelPendingIfSlopeInvalid()
  {
   const int slope = Strategy_SmaSlopeDirection();
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(!Strategy_IsOurPendingStopType(type))
         continue;
      if((type == ORDER_TYPE_BUY_STOP && slope <= 0) ||
         (type == ORDER_TYPE_SELL_STOP && slope >= 0))
         Strategy_CancelPendingOrder(ticket);
     }
  }

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double stop_distance = Strategy_StopDistancePrice();
   if(ask <= 0.0 || bid <= 0.0 || ask < bid || stop_distance <= 0.0)
      return true;

   Strategy_CancelPendingIfSlopeInvalid();
   return ((ask - bid) > stop_distance * strategy_max_spread_sl_frac);
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(_Period != PERIOD_D1)
      return false;
   if(Strategy_HasOurPosition() || Strategy_HasOurPendingStop())
      return false;
   if(strategy_sma_period < 2 || strategy_entry_buffer_pips <= 0 || strategy_tp_r_multiple <= 0.0)
      return false;

   const double high1 = iHigh(_Symbol, PERIOD_D1, 1);
   const double low1 = iLow(_Symbol, PERIOD_D1, 1);
   const double high2 = iHigh(_Symbol, PERIOD_D1, 2);
   const double low2 = iLow(_Symbol, PERIOD_D1, 2);
   if(high1 <= 0.0 || low1 <= 0.0 || high2 <= 0.0 || low2 <= 0.0)
      return false;
   if(!(high1 < high2 && low1 > low2))
      return false;

   const int slope = Strategy_SmaSlopeDirection();
   if(slope == 0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_entry_buffer_pips);
   const double stop_distance = Strategy_StopDistancePrice();
   if(ask <= 0.0 || bid <= 0.0 || ask < bid || buffer <= 0.0 || stop_distance <= 0.0)
      return false;
   if((ask - bid) > stop_distance * strategy_max_spread_sl_frac)
      return false;

   if(slope > 0)
     {
      req.type = QM_BUY_STOP;
      req.price = NormalizeDouble(high1 + buffer + (ask - bid), _Digits);
      req.sl = QM_StopRulesStopFromDistance(_Symbol, req.type, req.price, stop_distance);
      req.tp = QM_StopRulesTakeFromDistance(_Symbol, req.type, req.price, stop_distance * strategy_tp_r_multiple);
      req.reason = "TOBY_INSIDE_D1_BUY_STOP";
      return (req.sl > 0.0 && req.tp > 0.0 && req.sl < req.price && req.tp > req.price);
     }

   req.type = QM_SELL_STOP;
   req.price = NormalizeDouble(low1 - buffer - (ask - bid), _Digits);
   req.sl = QM_StopRulesStopFromDistance(_Symbol, req.type, req.price, stop_distance);
   req.tp = QM_StopRulesTakeFromDistance(_Symbol, req.type, req.price, stop_distance * strategy_tp_r_multiple);
   req.reason = "TOBY_INSIDE_D1_SELL_STOP";
   return (req.sl > 0.0 && req.tp > 0.0 && req.sl > req.price && req.tp < req.price);
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card baseline has no trailing, break-even, partial close, or scale logic.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int setup = Strategy_CurrentInsideBarSetupDirection();
   if(setup == 0)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY && setup < 0)
         return true;
      if(type == POSITION_TYPE_SELL && setup > 0)
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
                        qm_news_mode_legacy,           // legacy back-compat
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,                            // pause-before (legacy hint)
                        30,                            // pause-after (legacy hint)
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,              // FW1 Axis A
                        qm_news_compliance))           // FW1 Axis B
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
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults.
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

   // Per-tick: trade management can adjust SL/TP on open positions.
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
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

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
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
   // FW4: feeds closing-deal net-profits to the KS kill-switch.
   // No-op outside Q13 (when no baseline.json exists).
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
