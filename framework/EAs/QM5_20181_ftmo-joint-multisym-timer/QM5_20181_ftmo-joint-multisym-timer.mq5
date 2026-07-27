#property strict
#property version   "5.0"
#property description "QM5_20181 FTMO JOINT MULTI-SYMBOL (OnTimer) — BACKTEST-ONLY measurement instrument. STEP 1: runner 9936:USDJPY only."

#include <QM/QM_Common.mqh>
#include <QM/QM_PropFirm.mqh>   // phase selector — used at OFF only (RECORD, never ENFORCE)
#include <QM/modules/QM_Mod_FtmoJointRangeBreakout_20180.mqh>   // host runner (9936) — line-verified vs 9936
#include <QM/modules/QM_Mod_FtmoJointEquitySampler_20180.mqh>   // N-magic account-equity sampler

// =============================================================================
// QM5_20181 — MULTI-SYMBOL, OnTimer-DRIVEN JOINT FTMO BACKTEST-ONLY EA
// -----------------------------------------------------------------------------
// PURPOSE. One EA that runs the Q09-admitted runner+satellite book on ONE
// simulated $100k account in ONE tester run so the account equity curve is REAL.
// OWNER 2026-07-27: symbols are INPUT parameters; sleeves are dispatched by
// symbol; the EA is driven from OnTimer instead of per-tick OnTick.
//
// THIS FILE IS STEP 1 OF 3 (OWNER: "Stück für Stück"). It builds the SCAFFOLD
// and admits the RUNNER ONLY (9936:USDJPY). Satellites (10145:XAUUSD, then a
// measurement-gated GDAXI/12969) are added one at a time in steps 2 and 3, each
// admitted only at match_rate == 1.0 before the next.
//
// -----------------------------------------------------------------------------
// WHERE THE PLAN AND THE EXIT-CADENCE RECON CONFLICT, THE RECON WINS (task rule).
//
//   * The task frames a single "OnTimer-driven loop". RECON B
//     (2026-07-27_sleeve_exit_cadence.md:23-27) proves the runner 9936 manages
//     its exits with a +1R 2-bar-swing trailing stop evaluated PER TICK on live
//     BID/ASK, and RECON A (2026-07-27_ontimer_tester_semantics.md:19-26,89-97)
//     proves the tester's OnTimer fires on model-time intervals that never align
//     with tick timestamps, so a per-tick trailing stop CANNOT be reproduced at
//     match_rate == 1.0 from OnTimer at any interval. The runner therefore MUST
//     NOT be timer-driven.
//   * Resolution (the plan's own §2 division of labour, forced by the recon):
//       - The host runner (slot 0, USDJPY == chart symbol) runs on OnTick, the
//         SAME handler and SAME tick stream standalone 9936 sees. Its per-tick
//         trailing stop is byte-faithful BY CONSTRUCTION.
//       - The OnTimer loop drives the account-equity sampler and every NON-host
//         satellite (which must be TIMER-SAFE). In step 1 no satellite is
//         enabled, so the OnTimer non-host dispatch is dormant and only the
//         equity sampler runs on the timer.
//   The runner is thus admitted via the OnTick path; the OnTimer scaffold is
//   built and proven dormant, ready for the satellites.
//
// -----------------------------------------------------------------------------
// FIDELITY (the load-bearing requirement — match_rate == 1.0).
//   The previous joint EA (QM5_20180) scored 0.914741. The fidelity diagnosis
//   (2026-07-27_joint_ea_fidelity_diagnosis.md:68-97) found the miss was an
//   INVALID CONTROL — a July-14 standalone binary vs a July-27 joint binary
//   (execution-identity drift), NOT a signal-logic defect; sleeve 0 was valid by
//   construction. This EA fixes the control, not the strategy: the runner uses
//   the ALREADY LINE-VERIFIED QM_Mod_FtmoJointRangeBreakout_20180 module through
//   the DEFAULT single-symbol QM_Entry path (explicit_magic == 0), which is
//   byte-identical to standalone 9936 (QM_TradeManagement.mqh:276-280 — the
//   3-arg open with magic 0 IS the 2-arg default; QM_Entry.mqh:225-227 —
//   magic 0 resolves QM_MagicChecked(ea_id, symbol_slot=0, _Symbol) = host
//   magic). Admission is PROVEN by pinned same-vintage singleton replay: compile
//   BOTH standalone 9936 and this EA from ONE framework state and run BOTH
//   sequentially on ONE reserved terminal, then diff with compare_joint_replay.py.
//
// SINGLE-SYMBOL MODE IN STEP 1 (fidelity-preserving; recon > plan §Step-0).
//   The plan's Step-0 scaffold warms all three symbols. Per the recon's fidelity
//   priority, this EA activates basket mode (QM_SymbolGuardInit + warmup) ONLY
//   when more than one DISTINCT enabled sleeve symbol exists. With the runner
//   alone enabled the active set is {USDJPY} => single-symbol mode, byte-
//   identical to standalone 9936's framework path (QM_FrameworkInit ->
//   QM_SymbolGuardInitSingle). Warming unused symbols would flip the framework
//   to basket ownership (QM_Common.mqh:414-431) and perturb the very path the
//   1.0 gate measures. Step 2 enables a satellite, the set becomes {USDJPY,
//   XAUUSD}, and basket warmup activates then.
//
// BACKTEST-ONLY, structurally (measurement tool, not a tradeable EA):
//   * refuses to init outside the Strategy Tester (MQL_TESTER);
//   * refuses RISK_PERCENT > 0 (RISK_FIXED only — HR4);
//   * refuses any enforcing prop phase (records the FTMO limits, never acts);
//   * refuses a non-zero stress probability (measurement runs at stress 0 only);
//   * ships no live/demo/ftmo set, no deploy manifest; ea_id status is
//     "backtest-only" in the registry.
//
// EQUITY. QM_Mod_FtmoJointEquitySampler_20180 emits a real per-bar +
// every-intraday-low account-equity stream with a per-sleeve floating breakdown
// (Common\Files\QM\q08_equity\20181_USDJPY_DWX.jsonl). Driven from BOTH OnTick
// (host-tick resolution) AND OnTimer (1 s model-time resolution — plan §5) so a
// future non-host satellite's between-tick intraday low is not missed. RECORD,
// not ENFORCE.
// =============================================================================

input group "QuantMechanica V5 Framework — BACKTEST-ONLY joint instrument"
input int    qm_ea_id                   = 20181;
input int    qm_magic_slot_offset       = 0;      // host slot
input uint   qm_rng_seed                = 42;

input group "Risk — BACKTEST-ONLY: RISK_FIXED, never RISK_PERCENT (HR4)"
input double RISK_PERCENT               = 0.0;    // MUST be 0 (guarded in OnInit)
input double RISK_FIXED                 = 1000.0; // native 1x baseline (per-sleeve below)
input double PORTFOLIO_WEIGHT           = 1.0;
input double qm_risk_cap_pct            = 1.0;    // framework default; prop OFF => no override

input group "News (host runner — preserved from 9936's gated input defaults)"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30; // mode 3
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;        // DXZ
input int    qm_news_stale_max_hours      = 336;     // 14 days
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close (9936: enabled, hour 21 broker)"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress — measurement instrument MUST stay 0 (guarded in OnInit)"
input double qm_stress_reject_probability = 0.0;

input group "Prop Firm — RECORD not ENFORCE: prop_phase MUST be OFF (guarded)"
// (prop_phase and the rest of the QM_PropFirm inputs come from QM_PropFirm.mqh.)

input group "Host binding (chart symbol) — guarded to _Symbol AND to the runner symbol"
input string host_symbol                = "USDJPY.DWX";

input group "Sleeve 0 — RUNNER 9936 ff-range-breakout (HOST, OnTick, byte-faithful)"
input bool   s0_enabled            = true;
input string s0_symbol             = "USDJPY.DWX";   // == host_symbol (guarded)
input double s0_risk_fixed         = 1000.0;
input int    s0_range_start_hr     = 1;              // GMT+3
input int    s0_range_end_hr       = 6;
input int    s0_cancel_hr          = 13;
input int    s0_close_hr           = 20;
input int    s0_atr_period         = 14;
input double s0_min_range_atr_mult = 0.4;
input double s0_max_range_atr_mult = 2.5;
input double s0_trail_trigger_r    = 1.0;
input int    s0_range_scan_bars    = 36;

input group "Sleeve 1 — SATELLITE-1 10145:XAUUSD (OnTimer, TIMER-SAFE) — WIRED IN STEP 2"
input bool   s1_enabled            = false;          // step 1: OFF. Enabling it in step 1 fails OnInit.
input string s1_symbol             = "XAUUSD.DWX";
input double s1_risk_fixed         = 1000.0;

// -----------------------------------------------------------------------------
// Runner sleeve state (host, OnTick). The satellite registry below is the
// OnTimer scaffold; it is EMPTY in step 1 (runner-only).
// -----------------------------------------------------------------------------
QM_FJ_RB_Params g_s0;
QM_FJ_RB_State  g_s0_state;

// Non-host satellite registry — populated in OnInit from ENABLED non-host
// sleeves. STEP 1: g_sat_count == 0 (runner-only), so the OnTimer non-host
// dispatch is dormant. STEP 2+ fills this and wires per-kind manage/entry.
struct QM_JT_Sat
  {
   int             slot;
   string          symbol;
   ENUM_TIMEFRAMES tf;
   int             magic;
   int             kind;        // strategy-family id (unimplemented in step 1)
   double          risk_fixed;
  };
QM_JT_Sat g_sats[];
int       g_sat_count = 0;

// -----------------------------------------------------------------------------
int OnInit()
  {
   // ---- Backtest-only structural guards ------------------------------------
   if(!MQLInfoInteger(MQL_TESTER))
     {
      Print("QM5_20181 is BACKTEST-ONLY: refusing to init outside the Strategy Tester.");
      return INIT_FAILED;
     }
   if(RISK_PERCENT > 0.0)
     {
      Print("QM5_20181 is BACKTEST-ONLY: RISK_PERCENT must be 0 (RISK_FIXED only, HR4).");
      return INIT_FAILED;
     }
   if(RISK_FIXED <= 0.0)
     {
      Print("QM5_20181: RISK_FIXED must be > 0.");
      return INIT_FAILED;
     }
   if(prop_phase != QM_PROP_PHASE_OFF)
     {
      Print("QM5_20181 RECORDS the FTMO limits, never ENFORCES them: prop_phase must be OFF.");
      return INIT_FAILED;
     }
   if(qm_stress_reject_probability != 0.0)
     {
      Print("QM5_20181 is a measurement instrument: qm_stress_reject_probability must be 0.");
      return INIT_FAILED;
     }

   // ---- Host binding: the chart symbol IS the runner symbol ----------------
   if(!s0_enabled)
     {
      Print("QM5_20181 step 1: the runner (sleeve 0) must be enabled.");
      return INIT_FAILED;
     }
   if(s0_symbol != host_symbol)
     {
      Print("QM5_20181: s0_symbol (", s0_symbol, ") must equal host_symbol (", host_symbol, ").");
      return INIT_FAILED;
     }
   if(_Symbol != host_symbol)
     {
      Print("QM5_20181: host_symbol is ", host_symbol, " but the attached chart is ", _Symbol, ".");
      return INIT_FAILED;
     }

   // ---- STEP 1 GUARD: no satellite is wired yet. A non-host sleeve enabled in
   //      step 1 would have no strategy module, so refuse loudly rather than
   //      silently trade nothing. Satellite dispatch lands in step 2.
   if(s1_enabled)
     {
      Print("QM5_20181 step 1 admits the RUNNER ONLY. Satellite sleeve 1 (", s1_symbol,
            ") is not wired until step 2 — set s1_enabled=false.");
      return INIT_FAILED;
     }

   // ---- Active enabled-symbol set decides single vs basket mode ------------
   //      Step 1: {host} only => single-symbol mode (no QM_SymbolGuardInit /
   //      warmup) => byte-identical framework path to standalone 9936.
   //      (Basket mode + per-symbol warmup activate in step 2 when a non-host
   //      sleeve is enabled — see the header note.)
   const bool basket_mode = false;   // step 1: runner-only => single-symbol

   // ---- Framework init (single-symbol: default guard {_Symbol=USDJPY}) ------
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

   // ---- Prop phase = OFF: validators/init are no-ops (framework byte-identical
   //      to standalone 9936, which runs the same sequence). Called for parity.
   if(!QM_PropPhaseValidateCap(qm_risk_cap_pct))
      return INIT_FAILED;
   if(!QM_FrameworkSetRiskCapPct(qm_risk_cap_pct))
      return INIT_FAILED;
   QM_PropLogEffectiveCap(qm_risk_cap_pct, g_qm_risk_per_trade_cap_pct);
   if(!QM_PropPhaseValidateWeekend(qm_friday_close_enabled))
      return INIT_FAILED;
   if(!QM_PropInit(qm_ea_id))
      return INIT_FAILED;

   // ---- Resolve + REGISTER the runner magic (slot 0 = host). QM_MagicFor binds
   //      slot->_Symbol context and registers with the kill switch. The runner
   //      then opens via the DEFAULT path (explicit_magic=0), so its magic is
   //      resolved exactly as standalone 9936 resolves g_qm_fw_magic.
   const int m0 = QM_MagicFor(qm_ea_id, 0);
   if(m0 <= 0 || !QM_MagicRegistered(qm_ea_id, 0))
     {
      Print("QM5_20181: runner magic resolution/registration failed (m0=", m0, ").");
      return INIT_FAILED;
     }

   // ---- Bind sleeve 0 = QM5_9936 gated backtest params (host, default path).
   g_s0.enabled            = s0_enabled;
   g_s0.slot               = 0;
   g_s0.magic              = m0;
   g_s0.explicit_magic     = 0;   // host slot -> DEFAULT QM_Entry path (byte-identical to 9936)
   g_s0.range_start_hr     = s0_range_start_hr;
   g_s0.range_end_hr       = s0_range_end_hr;
   g_s0.cancel_hr          = s0_cancel_hr;
   g_s0.close_hr           = s0_close_hr;
   g_s0.atr_period         = s0_atr_period;
   g_s0.min_range_atr_mult = s0_min_range_atr_mult;
   g_s0.max_range_atr_mult = s0_max_range_atr_mult;
   g_s0.trail_trigger_r    = s0_trail_trigger_r;
   g_s0.range_scan_bars    = s0_range_scan_bars;
   g_s0.reason_prefix      = "FF_RANGE";
   QM_FJ_RB_StateInit(g_s0_state);

   // ---- Non-host satellite registry: EMPTY in step 1 (runner-only) ---------
   g_sat_count = 0;
   ArrayResize(g_sats, 0);

   // ---- Equity sampler: per-sleeve floating breakdown keyed on the enabled
   //      sleeves' magics (step 1: the runner only).
   long eqmagics[];
   ArrayResize(eqmagics, 1);
   eqmagics[0] = m0;
   QM_FJ_Eq_Configure(eqmagics);

   // ---- Model-second timer. RECON A: OnTimer fires on simulated time; the
   //      useful floor is 1 s (TimeCurrent() is second-resolution). Drives the
   //      equity sampler now; drives non-host satellites in step 2.
   EventSetTimer(1);

   QM_LogEvent(QM_INFO, "INIT_OK",
               StringFormat("{\"instrument\":\"ftmo_joint_multisym_timer\",\"step\":1,"
                            "\"host\":\"%s\",\"basket_mode\":%s,\"runner_magic\":%d,"
                            "\"runner_enabled\":%s,\"sat_count\":%d}",
                            QM_LoggerEscapeJson(_Symbol),
                            basket_mode ? "true" : "false",
                            m0, s0_enabled ? "true" : "false", g_sat_count));
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   QM_FJ_Eq_Shutdown();
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

// -----------------------------------------------------------------------------
// OnTick — handles ONLY the host runner (slot 0). This is the byte-faithful
// path: same handler, same tick stream, same default entry path as standalone
// 9936. The account-equity sampler is also driven here at host-tick resolution.
// -----------------------------------------------------------------------------
void OnTick()
  {
   if(!QM_KillSwitchCheck())
      return;

   // Per-tick account-equity low sampler — read-only (equity/position reads +
   // file write to a SEPARATE JSONL). Cannot affect the trade stream, so runner
   // singleton-replay fidelity is unchanged. Runs BEFORE the news early-return
   // so a broker-day anchor / intraday low is never missed.
   QM_FJ_Eq_OnTick();

   const datetime broker_now = TimeCurrent();

   // News gate — identical to standalone 9936 (host _Symbol = USDJPY,
   // PRE30_POST30 + DXZ from the input defaults).
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   // Friday close — closes all owned positions (runner), exactly as 9936 does.
   if(QM_FrameworkHandleFridayClose())
      return;

   // Prop-firm entry gate — mirrors standalone 9936 line-for-line. In OFF phase
   // QM_PropEntryAllowed returns true with no side effect (QM_PropFirm.mqh:542),
   // so this is a no-op here; it is present to keep the runner path structurally
   // identical to 9936 (removes an execution-identity variable).
   const long qm_prop_magic = (long)QM_FrameworkMagic();
   const bool qm_prop_entry_allowed = QM_PropEntryAllowed(qm_prop_magic);
   if(!qm_prop_entry_allowed)
      QM_FJ_RB_RemoveOurPendingOrders(g_s0, "PROP_ENTRY_BLOCKED");

   // Per-tick runner management + discretionary exit (the +1R trailing stop, the
   // opposite-touch, and the 20:00 time exit — all byte-faithful on host ticks).
   QM_FJ_RB_NoTradeFilter(g_s0, g_s0_state);
   QM_FJ_RB_ManageOpenPosition(g_s0, g_s0_state);
   if(QM_FJ_RB_ExitSignal(g_s0, g_s0_state))
      QM_FJ_RB_CloseAll(g_s0);

   // Per closed H1 bar only, from here (host new-bar latch — key USDJPY|H1).
   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();   // parity with 9936 (per-day EQUITY_SNAPSHOT to log)
   QM_FJ_Eq_OnNewBar();         // EQUITY_BAR per host H1 closed bar (primary deliverable)

   if(qm_prop_entry_allowed)
      QM_FJ_RB_TryEntry(g_s0, g_s0_state);
  }

// -----------------------------------------------------------------------------
// OnTimer — model-second (EventSetTimer(1)). Drives the account-equity sampler
// at 1 s resolution and the NON-host satellite dispatch. The host runner is NOT
// handled here: QM_IsNewBar(host, H1) must NOT be called from the timer (it
// would race the OnTick host latch — plan §2). In STEP 1 g_sat_count == 0, so
// the per-symbol new-bar dispatch is dormant and only the equity sampler runs.
// -----------------------------------------------------------------------------
void OnTimer()
  {
   // (1) Account-equity sampler at 1 s model-time resolution (plan §5). Idempotent
   //     to timer bursts (RECON A: up to ~797 fires share one TimeCurrent()) — it
   //     only emits on a new intraday low / day rollover, never per fire.
   QM_FJ_Eq_OnTick();

   // (2) Non-host satellite dispatch — DORMANT in step 1 (no enabled non-host
   //     sleeve). The per-symbol new-bar detection below acts once and only once
   //     per (symbol, tf) bar via the framework's global bar tracker
   //     (QM_Indicators.mqh:108-137). Satellite manage/entry wiring lands in
   //     step 2; the loop keeps zero iterations until then.
   if(g_sat_count == 0)
      return;

   if(!QM_KillSwitchCheck())
      return;

   for(int i = 0; i < g_sat_count; ++i)
     {
      // STEP 2 inserts here (in order): per-sleeve news on g_sats[i].symbol;
      // TIMER-SAFE manage/exit; then the once-per-bar entry below.
      if(!QM_IsNewBar(g_sats[i].symbol, g_sats[i].tf))
         continue;
      // STEP 2: satellite entry once per that symbol's closed bar.
     }
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
