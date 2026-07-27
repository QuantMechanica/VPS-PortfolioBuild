#property strict
#property version   "5.0"
#property description "QM5_20180 FTMO JOINT SIM — BACKTEST-ONLY measurement instrument (USDJPY 9936+13213)"

#include <QM/QM_Common.mqh>
#include <QM/QM_PropFirm.mqh>   // phase selector — used at OFF only (RECORD, never ENFORCE)
#include <QM/modules/QM_Mod_FtmoJointRangeBreakout_20180.mqh>
#include <QM/modules/QM_Mod_FtmoJointEquitySampler_20180.mqh>

// =============================================================================
// QM5_20180 — JOINT FTMO BACKTEST-ONLY EA (measurement instrument)
// -----------------------------------------------------------------------------
// PURPOSE. A single EA that trades the two gate-clean, intraday-flat USDJPY
// sleeves — QM5_9936 (lead) and QM5_13213 (same-edge probe) — on ONE simulated
// $100k account in ONE strategy-tester run, so the account equity curve is REAL
// (not a proxy) and the two sleeves' realised correlation FALLS OUT of the run.
// OWNER's idea 2026-07-27: "sie handeln sofort gemeinsam ... hast du sofort ihre
// Korrelation."
//
// SCOPE = USDJPY-ONLY, PER THE ADVERSARIAL REVIEW (binding over the design).
//   docs/ops/evidence/2026-07-27_joint_backtest_ea_adversarial_review.md
//   The 3-sleeve design (adding 10848:XAUUSD) was REFUTED: a per-tick-managed
//   non-host foreign symbol driven off the host's tick stream measures a
//   DIFFERENT strategy (C1), cannot be validated by singleton replay (C2), and
//   biases the -5% daily read optimistically (C4). Both USDJPY sleeves are
//   host-symbol, so singleton replay is a VALID control and the equity path is
//   real at full tick resolution. The gold sleeve is OUT. Where the design and
//   the review conflict, the review wins (task instruction).
//
// BACKTEST-ONLY, structurally. This is a measurement tool, not a tradeable EA:
//   * refuses to init outside the Strategy Tester (MQL_TESTER);
//   * refuses RISK_PERCENT > 0 (RISK_FIXED only — HR4);
//   * refuses any enforcing prop phase (records the FTMO limits, never acts);
//   * refuses a non-zero stress probability (measurement runs at stress 0 only);
//   * ships no live/demo/ftmo set, no deploy manifest; ea_id status is
//     "backtest-only" in the registry.
//
// FIDELITY. Each sleeve's entry logic is the COPIED gated algorithm
// (QM_Mod_FtmoJointRangeBreakout_20180.mqh), bound to that sleeve's gated
// _backtest.set parameters. Sleeve 0 opens through the DEFAULT QM_Entry path
// (explicit_magic=0) — byte-identical to standalone 9936; sleeve 1 opens through
// the QM_Entry EXPLICIT-magic overload (its registered slot-1 magic). Fidelity
// is PROVEN by singleton replay (run one sleeve, diff its Q08 stream against the
// gated sleeve's stream), not asserted.
//
// EQUITY. QM_Mod_FtmoJointEquitySampler_20180.mqh emits a real per-bar +
// every-intraday-low account-equity stream with a per-sleeve floating breakdown
// (Common\Files\QM\q08_equity\20180_USDJPY_DWX.jsonl), from which the -5% daily
// / -10% total / +10% / +5% predicates are exact reads at any post-hoc leverage
// vector (RISK_FIXED linearity, design §6). RECORD, not ENFORCE (design §7).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 20180;
input int    qm_magic_slot_offset       = 0;      // host slot
input uint   qm_rng_seed                = 42;

input group "Risk — BACKTEST-ONLY: RISK_FIXED, never RISK_PERCENT (HR4)"
input double RISK_PERCENT               = 0.0;    // MUST be 0 (guarded in OnInit)
input double RISK_FIXED                 = 1000.0; // native 1x, exactly as gated
input double PORTFOLIO_WEIGHT           = 1.0;
input double qm_risk_cap_pct            = 1.0;    // framework default; prop OFF => no override

input group "News (preserved from the gated sleeves' input defaults)"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30; // mode 3
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;        // DXZ
input int    qm_news_stale_max_hours      = 336;     // 14 days
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close (both gated sleeves: enabled, hour 21 broker)"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress — measurement instrument MUST stay 0 (guarded in OnInit)"
input double qm_stress_reject_probability = 0.0;

input group "Prop Firm — RECORD not ENFORCE: prop_phase MUST be OFF (guarded)"
// (prop_phase and the rest of the QM_PropFirm inputs come from QM_PropFirm.mqh.)

input group "Sleeve 0 — QM5_9936 range breakout (USDJPY GMT+3 01-06, cancel 13, close 20)"
input bool   s0_enabled            = true;
input int    s0_range_start_hr     = 1;
input int    s0_range_end_hr       = 6;
input int    s0_cancel_hr          = 13;
input int    s0_close_hr           = 20;
input int    s0_atr_period         = 14;
input double s0_min_range_atr_mult = 0.4;
input double s0_max_range_atr_mult = 2.5;
input double s0_trail_trigger_r    = 1.0;
input int    s0_range_scan_bars    = 36;

input group "Sleeve 1 — QM5_13213 Balke range breakout (USDJPY GMT+3 03-06, single evening flat 18)"
input bool   s1_enabled            = true;
input int    s1_range_start_hr     = 3;
input int    s1_range_end_hr       = 6;
input int    s1_cancel_hr          = 18;   // Balke single evening flat drives BOTH cancel & close (review M2)
input int    s1_close_hr           = 18;
input int    s1_atr_period         = 14;
input double s1_min_range_atr_mult = 0.4;
input double s1_max_range_atr_mult = 2.5;
input double s1_trail_trigger_r    = 1.0;
input int    s1_range_scan_bars    = 36;

QM_FJ_RB_Params g_s0;
QM_FJ_RB_Params g_s1;
QM_FJ_RB_State  g_s0_state;
QM_FJ_RB_State  g_s1_state;

// -----------------------------------------------------------------------------
int OnInit()
  {
   // ---- Backtest-only structural guard (review L2 + task backtest-only mandate)
   if(!MQLInfoInteger(MQL_TESTER))
     {
      Print("QM5_20180 is BACKTEST-ONLY: refusing to init outside the Strategy Tester.");
      return INIT_FAILED;
     }
   if(RISK_PERCENT > 0.0)
     {
      Print("QM5_20180 is BACKTEST-ONLY: RISK_PERCENT must be 0 (RISK_FIXED only, HR4).");
      return INIT_FAILED;
     }
   if(RISK_FIXED <= 0.0)
     {
      Print("QM5_20180: RISK_FIXED must be > 0.");
      return INIT_FAILED;
     }
   if(prop_phase != QM_PROP_PHASE_OFF)
     {
      Print("QM5_20180 RECORDS the FTMO limits, never ENFORCES them: prop_phase must be OFF.");
      return INIT_FAILED;
     }
   if(qm_stress_reject_probability != 0.0)
     {
      Print("QM5_20180 is a measurement instrument: qm_stress_reject_probability must be 0.");
      return INIT_FAILED;
     }

   // ---- Framework init (single-symbol: default guard {_Symbol=USDJPY}). Both
   //      sleeves are host-symbol, so NO QM_SymbolGuardInit / basket warmup is
   //      needed (design hazards §8.2/§8.3 do not arise for USDJPY-only).
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

   // ---- Prop phase = OFF: validators/init are no-ops (framework byte-identical).
   //      Called for parity/telemetry with the gated sleeves (9936 includes it).
   if(!QM_PropPhaseValidateCap(qm_risk_cap_pct))
      return INIT_FAILED;
   if(!QM_FrameworkSetRiskCapPct(qm_risk_cap_pct))
      return INIT_FAILED;
   QM_PropLogEffectiveCap(qm_risk_cap_pct, g_qm_risk_per_trade_cap_pct);
   if(!QM_PropPhaseValidateWeekend(qm_friday_close_enabled))
      return INIT_FAILED;
   if(!QM_PropInit(qm_ea_id))
      return INIT_FAILED;

   // ---- Resolve + REGISTER each sleeve's magic. QM_MagicFor binds slot->_Symbol
   //      in the ownership contexts (so both sleeves' trades are captured in the
   //      one host-keyed Q08 stream) AND registers the magic with the kill-switch,
   //      which the QM_Entry explicit-magic path requires (QM_Entry.mqh:233).
   const int m0 = QM_MagicFor(qm_ea_id, 0);   // == g_qm_fw_magic (host slot)
   const int m1 = QM_MagicFor(qm_ea_id, 1);
   if(m0 <= 0 || m1 <= 0)
     {
      Print("QM5_20180: sleeve magic resolution/registration failed (m0=", m0, " m1=", m1, ")");
      return INIT_FAILED;
     }

   // ---- Bind sleeve 0 = QM5_9936 gated backtest params.
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

   // ---- Bind sleeve 1 = QM5_13213 gated backtest params (cancel==close==18).
   g_s1.enabled            = s1_enabled;
   g_s1.slot               = 1;
   g_s1.magic              = m1;
   g_s1.explicit_magic     = m1;  // non-host slot -> EXPLICIT-magic QM_Entry path
   g_s1.range_start_hr     = s1_range_start_hr;
   g_s1.range_end_hr       = s1_range_end_hr;
   g_s1.cancel_hr          = s1_cancel_hr;
   g_s1.close_hr           = s1_close_hr;
   g_s1.atr_period         = s1_atr_period;
   g_s1.min_range_atr_mult = s1_min_range_atr_mult;
   g_s1.max_range_atr_mult = s1_max_range_atr_mult;
   g_s1.trail_trigger_r    = s1_trail_trigger_r;
   g_s1.range_scan_bars    = s1_range_scan_bars;
   g_s1.reason_prefix      = "BALKE_RANGE";

   QM_FJ_RB_StateInit(g_s0_state);
   QM_FJ_RB_StateInit(g_s1_state);

   // ---- Equity sampler: per-sleeve floating breakdown keyed on the two magics.
   long eqmagics[];
   ArrayResize(eqmagics, 2);
   eqmagics[0] = m0;
   eqmagics[1] = m1;
   QM_FJ_Eq_Configure(eqmagics);

   QM_LogEvent(QM_INFO, "INIT_OK",
               StringFormat("{\"instrument\":\"ftmo_joint_backtest_only\",\"host\":\"%s\","
                            "\"s0_magic\":%d,\"s0_enabled\":%s,\"s1_magic\":%d,\"s1_enabled\":%s}",
                            QM_LoggerEscapeJson(_Symbol),
                            m0, s0_enabled ? "true" : "false",
                            m1, s1_enabled ? "true" : "false"));
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_FJ_Eq_Shutdown();
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();

   // News gate — identical to both gated sleeves (host _Symbol = USDJPY,
   // PRE30_POST30 + DXZ). One gate serves both sleeves because both are USDJPY.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   // Friday close — closes ALL owned positions (both sleeves), per-magic, exactly
   // as each gated sleeve closes its own.
   if(QM_FrameworkHandleFridayClose())
      return;

   // Per-tick account-equity low sampler. USDJPY-only => every tick is a host
   // tick => full-resolution intraday equity low (review C4 does not apply).
   QM_FJ_Eq_OnTick();

   // Per-sleeve management + discretionary exit. The two sleeves are independent
   // state machines, each filtered to its own (symbol, magic).
   if(g_s0.enabled)
     {
      QM_FJ_RB_NoTradeFilter(g_s0, g_s0_state);
      QM_FJ_RB_ManageOpenPosition(g_s0, g_s0_state);
      if(QM_FJ_RB_ExitSignal(g_s0, g_s0_state))
         QM_FJ_RB_CloseAll(g_s0);
     }
   if(g_s1.enabled)
     {
      QM_FJ_RB_NoTradeFilter(g_s1, g_s1_state);
      QM_FJ_RB_ManageOpenPosition(g_s1, g_s1_state);
      if(QM_FJ_RB_ExitSignal(g_s1, g_s1_state))
         QM_FJ_RB_CloseAll(g_s1);
     }

   // Per closed bar only, from here.
   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();   // parity with gated sleeves (per-day EQUITY_SNAPSHOT to log)
   QM_FJ_Eq_OnNewBar();         // EQUITY_BAR per host H1 closed bar (primary deliverable)

   if(g_s0.enabled)
      QM_FJ_RB_TryEntry(g_s0, g_s0_state);
   if(g_s1.enabled)
      QM_FJ_RB_TryEntry(g_s1, g_s1_state);
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
