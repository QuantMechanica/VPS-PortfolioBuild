#property strict
#property version   "5.0"
#property description "QM5_9907 Bandy Bollinger-Lower-Band -> Midband Reversion (Long-only MR)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_9907 bandy-bbands-midband-reversion-mr-index
// -----------------------------------------------------------------------------
// Source: Howard B. Bandy, "Quantitative Technical Analysis", Blue Owl Press,
// 2015, ISBN 9780979183850. Card:
// artifacts/cards_approved/QM5_9907_bandy-bbands-midband-reversion-mr-index.md
//
// Entry (D1 close): close[1] < BB_lower(20, 2.0)[1] AND close[1] > SMA(200)[1].
// Exit: close[1] >= BB_mid(20, 2.0)[1] (midband reversion) OR 7 trading days
// elapsed without a midband touch (time stop).
// Stop: 2.0 * ATR(14) catastrophic backstop below entry. Long-only, one
// position per magic.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9907;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
// All other phases use 42 by default. Stress / noise dimensions read from
// this single seed so reproducibility is guaranteed across re-runs.
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.5;
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
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_bb_period          = 20;   // Bandy BB period
input double strategy_bb_std_mult        = 2.0;  // Bandy BB std-dev multiplier
input int    strategy_regime_sma_period  = 200;  // long-term regime filter
input int    strategy_atr_period         = 14;   // catastrophic-stop ATR period
input double strategy_atr_stop_mult      = 2.0;  // catastrophic-stop ATR multiplier
input int    strategy_time_stop_days     = 7;    // trading days before time-stop exit

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // Card has no session/spread filter beyond the closed-bar gate (handled by
   // the framework's QM_IsNewBar entry gate) and the one-position-per-magic
   // rule (handled in Strategy_EntrySignal so position management below is
   // never suppressed while a position is open).
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

   if(strategy_bb_period <= 1 || strategy_bb_std_mult <= 0.0 ||
      strategy_regime_sma_period <= 0 || strategy_atr_period <= 0 ||
      strategy_atr_stop_mult <= 0.0)
      return false;

   // Long-only, one position per magic (Bandy: symmetric short MR fights
   // long-run drift on equity indices).
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   MqlRates bar1;
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 1, bar1))
      return false;

   const double bb_lower   = QM_BB_Lower(_Symbol, PERIOD_D1, strategy_bb_period, strategy_bb_std_mult, 1);
   const double regime_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_regime_sma_period, 1);
   if(bb_lower <= 0.0 || regime_sma <= 0.0)
      return false;

   // Entry trigger: just-closed D1 bar's close below the lower BB band AND
   // above the long-term regime SMA (Bandy long-only MR condition).
   if(!(bar1.close < bb_lower && bar1.close > regime_sma))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, QM_BUY, ask, strategy_atr_period, strategy_atr_stop_mult);
   if(sl <= 0.0 || sl >= ask)
      return false;

   req.type   = QM_BUY;
   req.price  = 0.0; // market fill == "next open" execution the card asks for
   req.sl     = sl;
   req.tp     = 0.0; // no static TP — exit is the midband-touch / time-stop rule below
   req.reason = "BANDY_BB_LOWER_MIDBAND_REVERSION_LONG";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card defines no trailing / break-even / partial-close management — only
   // the midband-touch target and time stop, both handled as full closes in
   // Strategy_ExitSignal below.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      MqlRates bar1;
      if(!QM_ReadBar(_Symbol, PERIOD_D1, 1, bar1))
         continue;

      // Primary target: closed-bar close has reverted to the BB centerline.
      const double bb_mid = QM_BB_Middle(_Symbol, PERIOD_D1, strategy_bb_period, strategy_bb_std_mult, 1);
      if(bb_mid > 0.0 && bar1.close >= bb_mid)
         return true;

      // Time stop: N trading (D1) days elapsed since entry without a midband touch.
      if(strategy_time_stop_days > 0)
        {
         const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
         const int bars_held = iBarShift(_Symbol, PERIOD_D1, opened, false);
         if(bars_held >= strategy_time_stop_days)
            return true;
        }
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
