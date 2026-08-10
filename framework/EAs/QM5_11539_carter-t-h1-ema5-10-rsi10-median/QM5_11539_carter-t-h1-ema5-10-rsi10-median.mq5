#property strict
#property version   "5.0"
#property description "QM5_11539 Carter-T H1 — EMA(5/10) cross + RSI(10,median) 50-cross (System #13)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_11539_carter-t-h1-ema5-10-rsi10-median
// -----------------------------------------------------------------------------
// Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)", System #13.
// Entry (H1): EMA(5) crosses EMA(10) AND RSI(10, PRICE_MEDIAN) crosses 50 in the
// same direction, the two cross events synchronized within a +/-2 bar window.
// Exit: fixed SL 30 pips / TP 50 pips (no discretionary exit). No Friday entry.
// Spread cap 15 pips. Framework boilerplate below the hooks is left intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11539;
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
input int    strategy_ema_fast          = 5;     // EMA(5) fast — PRICE_CLOSE.
input int    strategy_ema_slow          = 10;    // EMA(10) slow — PRICE_CLOSE.
input int    strategy_rsi_period        = 10;    // RSI period, applied to PRICE_MEDIAN (H+L)/2.
input double strategy_rsi_level         = 50.0;  // RSI cross level (midline).
input int    strategy_sync_window       = 2;     // +/- bars allowed between the EMA and RSI crosses.
input int    strategy_sl_pips           = 30;    // Fixed stop-loss (pips). P2 cap 35.
input int    strategy_tp_pips           = 50;    // Fixed take-profit (pips).
input int    strategy_spread_cap_pips   = 15;    // Block entry if live spread exceeds this (pips).
input int    strategy_block_friday_entry = 1;    // 1 = no new entries on Friday (broker time); 0 = allow.

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Direction of an EMA(fast/slow) cross that COMPLETES on closed bar `s`.
// +1 bullish (fast crosses above slow), -1 bearish, 0 none. Delegates to the
// framework MA-cross primitive (pooled closed-bar EMA reads).
int Carter_EmaCrossDir(const int s)
  {
   return QM_Sig_MA_Cross(_Symbol, PERIOD_H1, strategy_ema_fast, strategy_ema_slow, s);
  }

// Direction of an RSI(period, PRICE_MEDIAN) level cross that COMPLETES on closed
// bar `s`. +1 = crossed up through the level, -1 = crossed down, 0 = none.
// A 0.0 read is treated as an invalid buffer fetch (never a real cross).
int Carter_RsiMedianCrossDir(const int s)
  {
   const double r_now  = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, s,     PRICE_MEDIAN);
   const double r_prev = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, s + 1, PRICE_MEDIAN);
   if(r_now <= 0.0 || r_prev <= 0.0)
      return 0;
   if(r_prev <= strategy_rsi_level && r_now > strategy_rsi_level) return +1;
   if(r_prev >= strategy_rsi_level && r_now < strategy_rsi_level) return -1;
   return 0;
  }

// True when an EMA cross and an RSI-median 50-cross in direction `dir` are
// synchronized within +/- strategy_sync_window bars, with the LATER-completing
// event landing on the just-closed bar (shift 1). Anchoring the later event at
// shift 1 makes the signal fire exactly once, on the bar the pair completes.
bool Carter_SyncSignal(const int dir)
  {
   const int w = (strategy_sync_window > 0) ? strategy_sync_window : 0;

   // Case A: the EMA cross is the later event (completes on the just-closed bar);
   //         the RSI cross happened on this bar or up to `w` bars earlier.
   if(Carter_EmaCrossDir(1) == dir)
     {
      for(int s = 1; s <= 1 + w; ++s)
         if(Carter_RsiMedianCrossDir(s) == dir)
            return true;
     }

   // Case B: the RSI cross is the later event; the EMA cross happened on this
   //         bar or up to `w` bars earlier.
   if(Carter_RsiMedianCrossDir(1) == dir)
     {
      for(int s = 1; s <= 1 + w; ++s)
         if(Carter_EmaCrossDir(s) == dir)
            return true;
     }

   return false;
  }

// Return TRUE to BLOCK trading this tick. No per-tick session/regime filter for
// this strategy — entry-only gates (Friday, spread) live in Strategy_EntrySignal
// so open-position management is never suppressed.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Populate `req` and return TRUE if a NEW entry should fire on this closed bar.
// Caller guarantees QM_IsNewBar() == true. Lots are sized by the framework from
// req.sl — never computed here.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One position per EA magic on this symbol (card: one entry per signal, no pyramiding).
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong tk = PositionGetTicket(i);
      if(tk == 0 || !PositionSelectByTicket(tk))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   // Card: no Friday entry. Broker (server) time day-of-week; TimeCurrent() is
   // broker time in the tester (DXZ NY-Close). 0=Sun .. 5=Fri.
   if(strategy_block_friday_entry != 0)
     {
      MqlDateTime bt;
      TimeToStruct(TimeCurrent(), bt);
      if(bt.day_of_week == 5)
         return false;
     }

   // Card: spread cap 15 pips. .DWX tester spread is 0, so this only blocks a
   // genuinely wide LIVE spread — never gates on spread<=0 (.DWX invariant).
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   if(ask > 0.0 && bid > 0.0 && spread_cap > 0.0 && (ask - bid) > spread_cap)
      return false;

   int dir = 0;
   if(Carter_SyncSignal(+1))
      dir = +1;
   else if(Carter_SyncSignal(-1))
      dir = -1;
   if(dir == 0)
      return false;

   const QM_OrderType side = (dir == +1) ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? ask : bid;
   if(entry <= 0.0)
      return false;

   req.type               = side;
   req.price              = 0.0;   // market fill
   req.sl                 = QM_StopFixedPips(_Symbol, side, entry, strategy_sl_pips);
   req.tp                 = QM_TakeFixedPips(_Symbol, side, entry, strategy_tp_pips);
   req.reason             = (side == QM_BUY) ? "CARTER11539_LONG" : "CARTER11539_SHORT";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;

   return true;
  }

// SL/TP are static (30/50 pips) — no break-even, trail, or partial close.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit: positions close on SL/TP or the framework Friday sweep.
bool Strategy_ExitSignal()
  {
   return false;
  }

// Defer to the central two-axis news filter (no custom event handling).
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
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
   // Q08 evidence lifecycle: sample floating P&L before any per-tick guard can
   // return. QM_KillSwitchCheck retains the same call as a compatibility
   // fallback for pre-template EAs; keep this explicit hook in all new builds.
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

   // Per-tick: trade management can adjust SL/TP on open positions.
   // Management, rule-based exits and the Friday sweep above MUST keep
   // running through news windows — the news gate below blocks NEW entries
   // only (2026-07-02 audit rule; canonical order per QM5_12821 OnTick,
   // commit dc418a720).
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
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults. Gates NEW entries only —
   // never the management/exit paths above.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req); // symbol_slot=0 (host slot) + expiration=0 defaults; garbage
                    // in unset fields = the silent-zero-trades class (9e4cfedb1)
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
