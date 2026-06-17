#property strict
#property version   "5.0"
#property description "QM5_10520 MQL5 Momo MACD + MA distance (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_10520 — MQL5 Momo: MACD sign-change scan + MA price-distance filter (H1)
// -----------------------------------------------------------------------------
// Card: QM5_10520_mql5-momo  (g0_status: APPROVED)
// Source: Rustamzhan Salidzhanov idea / Vladimir Karputov "Momo_trades",
//         MQL5 CodeBase 2018, https://www.mql5.com/en/code/19573
//
// Mechanic (baseline H1):
//   Scan a window of `strategy_macd_window` (11) MACD MAIN values starting at
//   `strategy_macd_start_bar` (2). Find the MOST RECENT MACD main-line sign
//   transition inside that window:
//     Long  : transition negative -> positive (older bar <= 0, newer bar > 0)
//             AND on `strategy_ma_bar` (6): Close[ma_bar] > MA[ma_bar] + shift.
//     Short : transition positive -> negative (older bar >= 0, newer bar < 0)
//             AND on `strategy_ma_bar` (6): Close[ma_bar] < MA[ma_bar] - shift.
//   The MACD transition is the TRIGGER EVENT; the MA-distance test is a STATE
//   confirmation on a fixed closed bar (DWX invariant #4 — one event only).
//   Entry at next bar open (req.price = 0 -> framework market fill).
//   Exit  : framework SL / TP only (card: fixed ATR SL + 1.5R TP, no manual
//           exit / trailing / break-even in the P2 baseline).
//   Stop  : strategy_atr_stop_mult (1.5) * ATR(strategy_atr_period=14) from entry.
//   Take  : strategy_tp_rr (1.5) R-multiple of the stop distance.
//   Filter: framework news / Friday-close / kill-switch only (no session gate).
//
// price_shift is a PIP distance converted to a scale-correct price distance via
// QM_StopRulesPipsToPriceDistance (DWX invariant #14 — points vs pips).
//
// Only the five Strategy_* hooks are filled; framework wiring below the hooks is
// kept verbatim from EA_Skeleton.mq5. Uses ONLY pooled QM_* readers (no raw
// iMACD/iMA/iATR, no per-EA IsNewBar). The single raw iClose read is a fixed
// closed-bar shift behind the framework new-bar gate (perf-allowed). qm_ea_id = 10520.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10520;
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
input int    strategy_macd_fast       = 12;   // MACD fast EMA period
input int    strategy_macd_slow       = 26;   // MACD slow EMA period
input int    strategy_macd_signal     = 9;    // MACD signal SMA period
input int    strategy_macd_start_bar  = 2;    // first (most recent) closed bar of the scan window
input int    strategy_macd_window     = 11;   // number of MACD main values scanned
input int    strategy_ma_bar          = 6;    // closed-bar shift for the MA-distance filter
input int    strategy_ma_period       = 14;   // moving-average period for the distance filter
input int    strategy_price_shift_pips = 50;  // required Close-vs-MA distance, in pips
input int    strategy_atr_period      = 14;   // ATR period for the hard stop
input double strategy_atr_stop_mult   = 1.5;  // ATR multiple for the hard stop
input double strategy_tp_rr           = 1.5;  // take-profit as R-multiple of the stop

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // Card specifies no session / regime filter beyond the framework news,
   // Friday-close, and kill-switch guards (handled in OnTick wiring).
   return false;
  }

// Scan the MACD main line for the most recent sign transition inside the
// window. Returns +1 for a negative->positive (long) transition, -1 for a
// positive->negative (short) transition, 0 for none. The first (smallest-shift)
// transition found is the most recent and wins.
int Momo_MacdTransition()
  {
   for(int s = strategy_macd_start_bar; s < strategy_macd_start_bar + strategy_macd_window - 1; ++s)
     {
      const double newer = QM_MACD_Main(_Symbol, (ENUM_TIMEFRAMES)_Period,
                                        strategy_macd_fast, strategy_macd_slow,
                                        strategy_macd_signal, s);
      const double older = QM_MACD_Main(_Symbol, (ENUM_TIMEFRAMES)_Period,
                                        strategy_macd_fast, strategy_macd_slow,
                                        strategy_macd_signal, s + 1);
      if(older <= 0.0 && newer > 0.0)
         return 1;
      if(older >= 0.0 && newer < 0.0)
         return -1;
     }
   return 0;
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

   if(strategy_macd_fast <= 0 || strategy_macd_slow <= strategy_macd_fast ||
      strategy_macd_signal <= 0 || strategy_macd_start_bar < 1 ||
      strategy_macd_window < 2 || strategy_ma_bar < 1 || strategy_ma_period <= 0 ||
      strategy_atr_period <= 0 || strategy_atr_stop_mult <= 0.0 || strategy_tp_rr <= 0.0)
      return false;

   const int direction = Momo_MacdTransition();
   if(direction == 0)
      return false;

   const double ma = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ma_period, strategy_ma_bar);
   const double close_bar = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ma_bar); // perf-allowed: fixed closed-bar shift behind the framework new-bar gate.
   const double shift_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_price_shift_pips);
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ma <= 0.0 || close_bar <= 0.0 || atr <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   if(direction > 0)
     {
      if(close_bar <= ma + shift_dist)
         return false;
      req.type = QM_BUY;
      req.sl = QM_StopATRFromValue(_Symbol, req.type, ask, atr, strategy_atr_stop_mult);
      if(req.sl <= 0.0)
         return false;
      req.tp = QM_TakeRR(_Symbol, req.type, ask, req.sl, strategy_tp_rr);
      req.reason = "QM5_10520_MOMO_LONG";
      return (req.tp > 0.0);
     }

   // direction < 0 — short
   if(close_bar >= ma - shift_dist)
      return false;
   req.type = QM_SELL;
   req.sl = QM_StopATRFromValue(_Symbol, req.type, bid, atr, strategy_atr_stop_mult);
   if(req.sl <= 0.0)
      return false;
   req.tp = QM_TakeRR(_Symbol, req.type, bid, req.sl, strategy_tp_rr);
   req.reason = "QM5_10520_MOMO_SHORT";
   return (req.tp > 0.0);
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card P2 baseline: no trailing, break-even, partial close, or add-on logic.
   // Breakeven / Trailing exist in the source but are disabled in the V5 baseline.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Card P2 baseline exits on fixed SL / TP only (Close-End-Day disabled).
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
