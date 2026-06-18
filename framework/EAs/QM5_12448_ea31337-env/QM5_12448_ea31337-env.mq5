#property strict
#property version   "5.0"
#property description "QM5_12448 EA31337 Envelopes Reentry"

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
input int    qm_ea_id                   = 12448;
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
input int                strategy_env_period          = 20;          // Source default Envelopes MA period.
input double             strategy_env_deviation       = 0.1;         // Source default Envelopes deviation (%).
input ENUM_MA_METHOD     strategy_env_method          = MODE_SMA;    // Card override: SMA.
input ENUM_APPLIED_PRICE strategy_env_price           = PRICE_CLOSE; // Card override: close price.
input double             strategy_signal_open_level   = 0.001;       // Source percent-change threshold.
input int                strategy_signal_mask_bars    = 4;           // Source GetSignals(4) confirmation window.
input int                strategy_atr_period          = 14;          // V5 protective ATR period.
input double             strategy_atr_sl_mult         = 2.0;         // Source price stop level 2, ATR-scaled.
input double             strategy_rr_take_profit      = 1.0;         // V5 fixed target; source close profit baseline.
input int                strategy_max_hold_bars       = 30;          // Source close time -30 bars.
input int                strategy_max_spread_pips     = 4;           // Source max spread cap.

datetime g_entry_bar_time = 0;
int      g_open_dir       = 0;

double EnvUpper(const int shift)
  {
   return QM_Envelope_Upper(_Symbol, _Period, strategy_env_period,
                            strategy_env_deviation, strategy_env_method,
                            shift, strategy_env_price);
  }

double EnvLower(const int shift)
  {
   return QM_Envelope_Lower(_Symbol, _Period, strategy_env_period,
                            strategy_env_deviation, strategy_env_method,
                            shift, strategy_env_price);
  }

double EnvMiddle(const int shift)
  {
   const double upper = EnvUpper(shift);
   const double lower = EnvLower(shift);
   if(upper <= 0.0 || lower <= 0.0)
      return 0.0;
   return (upper + lower) * 0.5;
  }

bool EnvelopeDirectionPass(const int dir)
  {
   if(strategy_signal_open_level < 0.0)
      return false;

   if(dir > 0)
     {
      const double now = EnvLower(1);
      const double old = EnvLower(3);
      if(now <= 0.0 || old <= 0.0)
         return false;
      return ((now - old) / MathAbs(old)) >= strategy_signal_open_level;
     }

   const double now = EnvUpper(1);
   const double old = EnvUpper(3);
   if(now <= 0.0 || old <= 0.0)
      return false;
   return ((old - now) / MathAbs(old)) >= strategy_signal_open_level;
  }

bool SourceSignalMaskPass(const int dir)
  {
   const int bars = (strategy_signal_mask_bars < 1) ? 1 : strategy_signal_mask_bars;
   for(int shift = 1; shift <= bars; ++shift)
     {
      const double close_price = iClose(_Symbol, _Period, shift); // perf-allowed: O(1) closed-bar reentry mask; no QM_Close reader exists.
      const double mid = EnvMiddle(shift);
      const double lower = EnvLower(shift);
      const double upper = EnvUpper(shift);
      if(close_price <= 0.0 || mid <= 0.0 || lower <= 0.0 || upper <= 0.0)
         return false;

      if(dir > 0)
        {
         if(close_price >= lower && close_price <= mid)
            return true;
        }
      else
        {
         if(close_price <= upper && close_price >= mid)
            return true;
        }
     }
   return false;
  }

bool EnvelopeLongSignal()
  {
   const double lower1 = EnvLower(1);
   const double lower2 = EnvLower(2);
   const double lower3 = EnvLower(3);
   if(lower1 <= 0.0 || lower2 <= 0.0 || lower3 <= 0.0)
      return false;

   const double low1 = iLow(_Symbol, _Period, 1); // perf-allowed: O(1) three-bar envelope excursion check.
   const double low2 = iLow(_Symbol, _Period, 2); // perf-allowed: O(1) three-bar envelope excursion check.
   const double low3 = iLow(_Symbol, _Period, 3); // perf-allowed: O(1) three-bar envelope excursion check.
   if(low1 <= 0.0 || low2 <= 0.0 || low3 <= 0.0)
      return false;

   const double lowest_price = MathMin(low1, MathMin(low2, low3));
   const double highest_lower = MathMax(lower1, MathMax(lower2, lower3));
   if(lowest_price >= highest_lower)
      return false;
   if(!EnvelopeDirectionPass(1))
      return false;
   return SourceSignalMaskPass(1);
  }

bool EnvelopeShortSignal()
  {
   const double upper1 = EnvUpper(1);
   const double upper2 = EnvUpper(2);
   const double upper3 = EnvUpper(3);
   if(upper1 <= 0.0 || upper2 <= 0.0 || upper3 <= 0.0)
      return false;

   const double high1 = iHigh(_Symbol, _Period, 1); // perf-allowed: O(1) three-bar envelope excursion check.
   const double high2 = iHigh(_Symbol, _Period, 2); // perf-allowed: O(1) three-bar envelope excursion check.
   const double high3 = iHigh(_Symbol, _Period, 3); // perf-allowed: O(1) three-bar envelope excursion check.
   if(high1 <= 0.0 || high2 <= 0.0 || high3 <= 0.0)
      return false;

   const double highest_price = MathMax(high1, MathMax(high2, high3));
   const double lowest_upper = MathMin(upper1, MathMin(upper2, upper3));
   if(highest_price <= lowest_upper)
      return false;
   if(!EnvelopeDirectionPass(-1))
      return false;
   return SourceSignalMaskPass(-1);
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
   const double max_spread = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_max_spread_pips);
   if(ask > 0.0 && bid > 0.0 && ask > bid && max_spread > 0.0 && (ask - bid) > max_spread)
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

   if(QM_EntryHasOpenPosition((long)QM_FrameworkMagic(), _Symbol))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(EnvelopeLongSignal())
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_StopATR(_Symbol, req.type, ask, strategy_atr_period, strategy_atr_sl_mult);
      req.tp = QM_TakeRR(_Symbol, req.type, ask, req.sl, strategy_rr_take_profit);
      if(req.sl <= 0.0 || req.tp <= 0.0)
         return false;
      req.reason = "EA31337_ENV_LONG";
      g_entry_bar_time = iTime(_Symbol, _Period, 1); // perf-allowed: O(1) record for 30-bar time exit.
      g_open_dir = 1;
      return true;
     }

   if(EnvelopeShortSignal())
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_StopATR(_Symbol, req.type, bid, strategy_atr_period, strategy_atr_sl_mult);
      req.tp = QM_TakeRR(_Symbol, req.type, bid, req.sl, strategy_rr_take_profit);
      if(req.sl <= 0.0 || req.tp <= 0.0)
         return false;
      req.reason = "EA31337_ENV_SHORT";
      g_entry_bar_time = iTime(_Symbol, _Period, 1); // perf-allowed: O(1) record for 30-bar time exit.
      g_open_dir = -1;
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   if(g_entry_bar_time == 0)
      return;
   if(!QM_EntryHasOpenPosition((long)QM_FrameworkMagic(), _Symbol))
     {
      g_entry_bar_time = 0;
      g_open_dir = 0;
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(g_entry_bar_time == 0 || g_open_dir == 0)
      return false;

   const int elapsed = iBarShift(_Symbol, _Period, g_entry_bar_time); // perf-allowed: O(1) bar-count time stop.
   if(elapsed < 0 || elapsed >= strategy_max_hold_bars)
      return true;

   if(g_open_dir > 0 && EnvelopeShortSignal())
      return true;
   if(g_open_dir < 0 && EnvelopeLongSignal())
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
