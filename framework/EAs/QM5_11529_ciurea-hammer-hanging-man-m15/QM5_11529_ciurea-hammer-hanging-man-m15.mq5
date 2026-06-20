#property strict
#property version   "5.0"
#property description "QM5_11529 Ciurea Hammer / Hanging Man M15"

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
input int    qm_ea_id                   = 11529;
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
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
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
input int    strategy_signal_side       = 1;      // 1 = Hammer long, -1 = Hanging Man short.
input int    strategy_body_min_pips     = 3;      // Minimum candle body in pips.
input double strategy_lower_shadow_mult = 2.0;    // Lower shadow must be >= this multiple of body.
input double strategy_upper_shadow_mult = 0.5;    // Upper shadow must be <= this multiple of body.
input int    strategy_stop_lookback     = 3;      // SL uses the 3-bar low/high extreme.
input int    strategy_stop_buffer_pips  = 3;      // SL buffer beyond the 3-bar extreme.
input int    strategy_stop_cap_pips     = 20;     // P2 cap from card.
input double strategy_reward_risk       = 2.0;    // TP = 2R.
input int    strategy_spread_cap_pips   = 12;     // Card spread cap.
input bool   strategy_no_friday_entry   = true;   // Card: no Friday entry.

bool Strategy_IsFriday()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (dt.day_of_week == 5);
  }

bool Strategy_ReadPatternBar(double &open1,
                             double &high1,
                             double &low1,
                             double &close1)
  {
   open1 = iOpen(_Symbol, PERIOD_M15, 1);   // perf-allowed: card requires OHLC body/shadow arithmetic.
   high1 = iHigh(_Symbol, PERIOD_M15, 1);   // perf-allowed: card requires OHLC body/shadow arithmetic.
   low1 = iLow(_Symbol, PERIOD_M15, 1);     // perf-allowed: card requires OHLC body/shadow arithmetic.
   close1 = iClose(_Symbol, PERIOD_M15, 1); // perf-allowed: card requires OHLC body/shadow arithmetic.
   return (open1 > 0.0 && high1 > 0.0 && low1 > 0.0 && close1 > 0.0 && high1 >= low1);
  }

bool Strategy_CandleShapeMatches(const double open1,
                                 const double high1,
                                 const double low1,
                                 const double close1)
  {
   const double pip = QM_StopRulesPipsToPriceDistance(_Symbol, 1);
   if(pip <= 0.0 || strategy_body_min_pips <= 0 ||
      strategy_lower_shadow_mult <= 0.0 || strategy_upper_shadow_mult < 0.0)
      return false;

   const double body = MathAbs(close1 - open1);
   const double lower = MathMin(open1, close1) - low1;
   const double upper = high1 - MathMax(open1, close1);

   return (body > (pip * strategy_body_min_pips) &&
           lower >= (strategy_lower_shadow_mult * body) &&
           upper <= (strategy_upper_shadow_mult * body));
  }

bool Strategy_Extremes(const int lookback, double &lowest_low, double &highest_high)
  {
   lowest_low = DBL_MAX;
   highest_high = -DBL_MAX;
   if(lookback <= 0)
      return false;

   for(int shift = 1; shift <= lookback; ++shift)
     {
      const double bar_low = iLow(_Symbol, PERIOD_M15, shift);    // perf-allowed: bounded 3-bar card SL extreme.
      const double bar_high = iHigh(_Symbol, PERIOD_M15, shift);  // perf-allowed: bounded 3-bar card SL extreme.
      if(bar_low <= 0.0 || bar_high <= 0.0 || bar_high < bar_low)
         return false;
      if(bar_low < lowest_low)
         lowest_low = bar_low;
      if(bar_high > highest_high)
         highest_high = bar_high;
     }

   return (lowest_low < DBL_MAX && highest_high > 0.0);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const double max_spread = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   if(max_spread > 0.0 && ask > bid && (ask - bid) > max_spread)
      return true;

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

   if((ENUM_TIMEFRAMES)_Period != PERIOD_M15)
      return false;
   if(strategy_no_friday_entry && Strategy_IsFriday())
      return false;
   if(strategy_signal_side != 1 && strategy_signal_side != -1)
      return false;

   double open1 = 0.0;
   double high1 = 0.0;
   double low1 = 0.0;
   double close1 = 0.0;
   if(!Strategy_ReadPatternBar(open1, high1, low1, close1))
      return false;
   if(!Strategy_CandleShapeMatches(open1, high1, low1, close1))
      return false;

   const QM_OrderType side = (strategy_signal_side > 0) ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   double lowest = 0.0;
   double highest = 0.0;
   if(!Strategy_Extremes(strategy_stop_lookback, lowest, highest))
      return false;

   const double buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_stop_buffer_pips);
   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_stop_cap_pips);
   if(buffer <= 0.0 || cap <= 0.0 || strategy_reward_risk <= 0.0)
      return false;

   double sl = 0.0;
   if(side == QM_BUY)
      sl = QM_StopRulesNormalizePrice(_Symbol, lowest - buffer);
   else
      sl = QM_StopRulesNormalizePrice(_Symbol, highest + buffer);

   if((side == QM_BUY && sl >= entry) || (side == QM_SELL && sl <= entry))
      return false;

   const double risk_distance = MathAbs(entry - sl);
   if(sl <= 0.0 || risk_distance <= 0.0 || risk_distance > cap)
      return false;

   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_reward_risk);
   if(tp <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = (side == QM_BUY) ? "CIUREA_HAMMER_LONG" : "CIUREA_HANGING_MAN_SHORT";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card has no trailing, break-even, partial close, or scale-in rule.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Card exits only through the initial SL/TP and framework Friday close.
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
