#property strict
#property version   "5.0"
#property description "QM5_11271 Quant-Trading Shooting Star"

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
input int    qm_ea_id                   = 11271;
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
input double strategy_lower_wick_bound  = 0.20;
input double strategy_body_size_mult    = 0.50;
input int    strategy_body_mean_lookback = 20;
input int    strategy_uptrend_lookback  = 2;
input double strategy_exit_pct          = 0.05;
input int    strategy_holding_bars      = 7;
input int    strategy_atr_period        = 14;
input double strategy_gap_atr_mult      = 0.75;
input bool   strategy_use_atr_threshold = false;
input double strategy_atr_exit_mult     = 2.0;

double Strategy_BodySize(const MqlRates &bar)
  {
   return MathAbs(bar.close - bar.open);
  }

bool Strategy_LoadRates(MqlRates &rates[], const int bars_needed)
  {
   if(bars_needed <= 0)
      return false;
   ArraySetAsSeries(rates, true);
   // perf-allowed: Entry/exit candlestick structure needs raw OHLC. Calls are
   // bounded and EntrySignal is reached only after the framework new-bar gate.
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 0, bars_needed, rates);
   return (copied >= bars_needed);
  }

double Strategy_MeanBodyBeforePattern(const MqlRates &rates[], const int star_shift)
  {
   const int lookback = MathMax(1, strategy_body_mean_lookback);
   double sum = 0.0;
   int count = 0;
   for(int i = star_shift + 1; i <= star_shift + lookback; ++i)
     {
      sum += Strategy_BodySize(rates[i]);
      count++;
     }
   if(count <= 0)
      return 0.0;
   return sum / (double)count;
  }

bool Strategy_UptrendIntoPattern(const MqlRates &rates[], const int star_shift)
  {
   const int lookback = MathMax(1, strategy_uptrend_lookback);
   for(int i = star_shift + lookback; i > star_shift; --i)
     {
      if(rates[i].close > rates[i - 1].close)
         return false;
     }
   return true;
  }

double Strategy_NormalizePrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   return NormalizeDouble(price, _Digits);
  }

bool Strategy_OurPosition(ulong &ticket)
  {
   ticket = 0;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      ticket = candidate;
      return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // Card adds no time or spread filter. News and Friday close are enforced by
   // the framework before this hook; the gap filter belongs to EntrySignal.
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QT_SHOOTING_STAR_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_lower_wick_bound < 0.0 ||
      strategy_body_size_mult <= 0.0 ||
      strategy_exit_pct <= 0.0 ||
      strategy_holding_bars <= 0 ||
      strategy_atr_period <= 0 ||
      strategy_gap_atr_mult < 0.0 ||
      strategy_atr_exit_mult <= 0.0)
      return false;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const int star_shift = 2;
   const int confirm_shift = 1;
   const int max_lookback = (strategy_body_mean_lookback > strategy_uptrend_lookback)
                            ? strategy_body_mean_lookback
                            : strategy_uptrend_lookback;
   const int bars_needed = star_shift + max_lookback + 2;
   MqlRates rates[];
   if(!Strategy_LoadRates(rates, bars_needed))
      return false;

   const MqlRates star = rates[star_shift];
   const MqlRates confirm = rates[confirm_shift];
   if(star.open <= 0.0 || star.high <= 0.0 || star.low <= 0.0 || star.close <= 0.0 ||
      confirm.open <= 0.0 || confirm.high <= 0.0 || confirm.close <= 0.0)
      return false;

   const double body = Strategy_BodySize(star);
   if(body <= 0.0)
      return false;

   const double mean_body = Strategy_MeanBodyBeforePattern(rates, star_shift);
   if(mean_body <= 0.0)
      return false;

   const double lower_wick = MathMin(star.open, star.close) - star.low;
   const double upper_wick = star.high - MathMax(star.open, star.close);
   if(star.open < star.close)
      return false;
   if(lower_wick >= strategy_lower_wick_bound * body)
      return false;
   if(body >= mean_body * strategy_body_size_mult)
      return false;
   if(upper_wick < 2.0 * body)
      return false;
   if(!Strategy_UptrendIntoPattern(rates, star_shift))
      return false;
   if(confirm.high > star.high)
      return false;
   if(confirm.close > star.close)
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, star_shift);
   if(atr <= 0.0)
      return false;
   if(MathAbs(confirm.open - star.close) > strategy_gap_atr_mult * atr)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(bid <= 0.0)
      return false;

   const double stop_distance = strategy_use_atr_threshold ? (atr * strategy_atr_exit_mult)
                                                           : (bid * strategy_exit_pct);
   if(stop_distance <= 0.0)
      return false;

   req.price = Strategy_NormalizePrice(bid);
   req.sl = Strategy_NormalizePrice(req.price + stop_distance);
   req.tp = Strategy_NormalizePrice(req.price - stop_distance);
   if(req.price <= 0.0 || req.sl <= req.price || req.tp >= req.price || req.tp <= 0.0)
      return false;

   req.reason = StringFormat("QT_SHOOT_STAR lb=%.2f body=%.2f up=%d",
                             strategy_lower_wick_bound,
                             strategy_body_size_mult,
                             strategy_uptrend_lookback);
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, partial close, or break-even management.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   if(!Strategy_OurPosition(ticket) || !PositionSelectByTicket(ticket))
      return false;

   // The card's 5% / ATR threshold is mapped to broker SL/TP at entry; this
   // hook handles the independent 7-bar time stop.
   const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
   // perf-allowed: O(1) bar-age lookup for the card's holding-period exit.
   const int bars_since_entry = iBarShift(_Symbol, (ENUM_TIMEFRAMES)_Period, open_time, false);
   if(bars_since_entry >= strategy_holding_bars)
      return true;

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
