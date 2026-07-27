#ifndef QM_PROP_FIRM_MQH
#define QM_PROP_FIRM_MQH

#include <Trade/Trade.mqh>

#include "QM_Errors.mqh"
#include "QM_Logger.mqh"

// V5 Framework — prop-firm / challenge-account awareness.
//
// WHY THIS EXISTS, and why the defaults are what they are.
//
// A challenge account is not a trading account with extra rules bolted on; it is
// a different objective. A funded account must survive indefinitely. A challenge
// must reach +10% once and then stop mattering. Our EAs had no notion of the
// second, and the cost was measured on the FTMO campaign books
// (docs/research/FTMO_MULTI_ACCOUNT_CAMPAIGN_2026-07-26.md, 22-day windows,
// selection 2017-2022, scoring 2022-2025):
//
//     target reached at any trade close, then flat   86.3 %
//     target held to that day's close, then flat     86.0 %
//     NO target awareness — must simply END >= +10%  57.5 %
//
// Reaching the target and continuing to trade gives back 28.8 points of pass
// probability. That is the single largest lever found anywhere in that work —
// larger than account count, leverage, or any risk overlay. Hence the
// flatten-at-target behaviour is ON for the sprint phases (Phase 1 / Phase 2),
// and it is the reason this file exists.
//
// The opposite is true of the loss-side throttles, which is why they default OFF
// despite being the obvious things to add. Measured on the same books, the
// existing preservation governor (FTMO_2S_P1_100K_V2: halt entries at -0.9% on
// the day, liquidate at -1.25%, give up at -6%, taper size above +7.5%) took the
// campaign from 86.3% down to 65.2%. Throttling protects capital and costs the
// sprint the upward excursion it needs to reach target. An earlier measurement
// appeared to show these throttles helping; that was a modelling error — halting
// dropped the trade's P&L entirely instead of realising the loss at the stop.
// Once the loss is realised, an in-sample search over the on/off assignment
// chooses OFF for every sleeve.
//
// So: prop_daily_halt_pct and prop_derisk_* are provided because a venue or a
// future book may need them, and are zero by default because for the books we
// have they destroy probability. The phase selector NEVER turns them on. Turning
// them on is a decision that should carry its own evidence.
//
// LIVE TARGET SEMANTICS — a deliberate, documented divergence from the study.
//
// The 86.3% measurement above was produced from CLOSED-trade P&L: the offline
// stream data could express nothing else, so "target reached" there meant
// realised equity crossing +prop_target_pct. The live trip in QM_PropEntryAllowed
// deliberately uses ACCOUNT_EQUITY instead, which INCLUDES floating P&L on
// still-open positions. ACCOUNT_EQUITY is the correct LIVE trigger for FLATTENING
// — a challenge is scored on equity and we want to lock the +10% the instant it
// exists on the book, realised or floating — so QM_PropFlattenAll fires on the
// equity trip. But FTMO PASSES only when realised BALANCE exceeds target with all
// positions closed, so after the flatten empties the book the PERMANENT halt latch
// is gated on realised BALANCE, not equity (adversarial review H4). A fast
// excursion that spikes equity over target but gives part of it back on the close
// therefore flattens (locking what is real at that instant) yet does NOT latch the
// challenge as won — the EA stays armed and keeps trading toward the real target,
// instead of latching a passed flag below target and idling into a dormancy block.
// Do not "fix" the equity trip by switching it to closed P&L; do not remove the
// balance gate on the latch. The two are separate on purpose.
//
// -----------------------------------------------------------------------------
// PHASE SELECTOR (2026-07-27, OWNER-directed) — design + adversarial-review fixes.
//
// OWNER wants one operator control that says which FTMO phase an account is in,
// and the EA to behave correctly for that phase. That control is `prop_phase`, a
// single enum. It is the SOLE authority for every phase-dependent value
// (profit target %, flatten-at-target) and a FAIL-CLOSED guardrail on the one
// number that must stay operator-supplied — the per-trade risk cap, which
// continues to flow through the EA's existing `qm_risk_cap_pct` input and
// QM_FrameworkSetRiskCapPct. There is no second risk knob.
//
// `prop_phase` replaces the old `prop_enabled` bool: OFF (=0, default) IS the old
// prop_enabled=false and leaves the framework byte-identical; PHASE_1 / PHASE_2 /
// FUNDED replace prop_enabled=true. Collapsing a single-choice fact into one enum
// removes the illegal "enabled but no phase" / "two phases at once" states three
// booleans would admit.
//
// The design as first written claimed the cap section "closes the silent-1x hole";
// the adversarial review (docs/ops/evidence/2026-07-27_propfirm_design_adversarial_review.md)
// refuted several points. Where the review and the design conflict, the REVIEW wins.
// The confirmed findings are handled here:
//
//   H1 (cap is a ceiling, not a setter; a cap-log check certifies a 1x book):
//       QM_PropLogEffectiveCap emits the EFFECTIVE cap read back from the sizer so
//       the override is provable from a log — but that only proves the CEILING.
//       Proving realised SIZE is an out-of-EA observable-size check documented in
//       the implementation note; the log payload is labelled "ceiling_not_size".
//   H2 (omitting qm_risk_cap_pct silently ships the 1.0 default = 1x):
//       PHASE_1/PHASE_2 REJECT cap_pct==1.0 (the default sentinel) at init unless
//       the operator sets prop_allow_unit_risk=true. A sprint phase now fails
//       closed on the silent-1x default instead of arming at 1x.
//   H3 (no binding between prop_phase and the actual account):
//       prop_expected_login (0=off) binds a prop set file to one account number;
//       QM_PropInit refuses (INIT_FAILED, loud) if the attached login differs.
//       Full cross-deploy safety still needs the T_Live manifest/SHA verification
//       (OWNER+Claude) — this is the in-EA half.
//   H4 (equity-trip latch below target): the permanent latch is balance-gated
//       (see LIVE TARGET SEMANTICS above).
//   M1 (Funded weekend guard incomplete): friday-close does NOT cover >2h daily/
//       holiday breaks; QM_PropPhaseValidateWeekend logs PROP_PHASE_FUNDED_WEEKEND_
//       PARTIAL so an index/multi-day Funded sleeve is not silently blessed.
//   M2 ((0,5.0] upper end is self-defeating vs the -5% daily limit): a cap above
//       4.0 in a sprint phase emits PROP_PHASE_CAP_NEAR_DAILY_LIMIT (loud WARN).
//       The OWNER-ratified 5.0 ceiling in QM_Common is NOT changed.
//   M3 (prop_swing_account is an unverified operator claim): claiming it to pass
//       the Funded weekend check emits PROP_PHASE_SWING_CLAIMED (loud WARN); it
//       must be verified against the real account type at deploy time.
//   L2 (risk-anchor telemetry claimed an anchor that is not wired to the entry
//       path): prop_init logs "risk_anchor_wired":false and a prop_anchor_not_wired
//       WARN so the log no longer asserts a behaviour that does not run.
//
// Dormancy telemetry (dormancy design + findings M4/L1) is a SEPARATE change and
// is intentionally not implemented here; see the implementation note.

// An account is in exactly one FTMO phase. One enum, not three booleans.
enum QM_PropPhase
  {
   QM_PROP_PHASE_OFF    = 0, // default; framework unchanged (was prop_enabled=false)
   QM_PROP_PHASE_1      = 1, // Challenge:    target +10%, flatten on, cap in (0,5.0]
   QM_PROP_PHASE_2      = 2, // Verification: target  +5%, flatten on, cap in (0,5.0]
   QM_PROP_PHASE_FUNDED = 3  // FTMO Account: no target, no flatten, cap in (0,1.0], weekend req.
  };

input group "Prop Firm (challenge accounts)"
input QM_PropPhase prop_phase          = QM_PROP_PHASE_OFF; // master phase selector; OFF = framework unchanged
input string prop_venue                = "FTMO";  // recorded in telemetry only
input double prop_start_balance        = 0.0;     // 0 = capture at first init and persist
input bool   prop_swing_account        = false;   // FTMO Swing (weekend-exempt); unverified operator claim (review M3)
input long   prop_expected_login       = 0;       // 0 = off; else INIT_FAILED unless ACCOUNT_LOGIN matches (review H3)
input bool   prop_allow_unit_risk      = false;   // sprint phases refuse cap==1.0 default unless true (review H2)
input double prop_daily_halt_pct       = 0.0;     // self-imposed daily stop; 0 = off (phase never turns on)
input double prop_derisk_at_loss_pct   = 0.0;     // shrink size below this drawdown; 0 = off (phase never turns on)
input double prop_derisk_scale         = 1.0;     // size multiplier once below it
input bool   prop_anchor_risk_to_start = true;    // size off start balance, not live equity (NOT wired to entry path yet — review L2)

double   g_qm_prop_start_balance   = 0.0;
double   g_qm_prop_day_start_eq    = 0.0;
int      g_qm_prop_day_key         = -1;
bool     g_qm_prop_initialized     = false;
bool     g_qm_prop_target_reached  = false;
bool     g_qm_prop_day_halted      = false;
string   g_qm_prop_state_file      = "";
CTrade   g_qm_prop_trade;

// Human-readable phase name for logs.
string QM_PropPhaseName(const QM_PropPhase phase)
  {
   switch(phase)
     {
      case QM_PROP_PHASE_OFF:    return "OFF";
      case QM_PROP_PHASE_1:      return "PHASE_1";
      case QM_PROP_PHASE_2:      return "PHASE_2";
      case QM_PROP_PHASE_FUNDED: return "FUNDED";
     }
   return "UNKNOWN";
  }

// -----------------------------------------------------------------------------
// Phase-DERIVED values. `prop_phase` is the only source; no competing input
// exists (prop_target_pct / prop_flatten_at_target were removed as inputs so a
// set file cannot say one thing while the phase says another — the target IS the
// phase). FTMO-only numbers (10/5/none) are deliberate; a future multi-venue
// table keyed on prop_venue is out of scope.
// -----------------------------------------------------------------------------

// Profit target as % of start balance. 0 = no target (OFF, FUNDED).
double QM_PropTargetPct()
  {
   switch(prop_phase)
     {
      case QM_PROP_PHASE_1:      return 10.0; // FTMO Challenge
      case QM_PROP_PHASE_2:      return 5.0;  // FTMO Verification
      case QM_PROP_PHASE_OFF:
      case QM_PROP_PHASE_FUNDED: return 0.0;  // no target
     }
   return 0.0;
  }

// Flatten-and-halt at target? True only for the sprint phases; a Funded account
// has no target to flatten at, and OFF is inert.
bool QM_PropFlattenEnabled()
  {
   return (prop_phase == QM_PROP_PHASE_1 || prop_phase == QM_PROP_PHASE_2);
  }

// -----------------------------------------------------------------------------
// Phase VALIDATORS. Pure (no QM_Common dependency, no include cycle). Each logs a
// loud event and returns false on an illegal combination; the EA turns false into
// INIT_FAILED. OFF imposes no constraint (the framework's own (0,5.0] ceiling in
// QM_FrameworkSetRiskCapPct still applies downstream).
// -----------------------------------------------------------------------------

// Legality of the operator's per-trade risk cap FOR THE SELECTED PHASE. Call in
// OnInit BEFORE QM_FrameworkSetRiskCapPct so the error names the phase and the
// account never arms on an illegal cap. This is where the phase-feature's loud
// refusal of caps above the ceiling lives (QM_FrameworkSetRiskCapPct refuses too,
// but silently); a cap above the band is REFUSED, never clamped into acceptance.
bool QM_PropPhaseValidateCap(const double cap_pct)
  {
   switch(prop_phase)
     {
      case QM_PROP_PHASE_OFF:
         return true; // no phase constraint; framework (0,5.0] applies downstream

      case QM_PROP_PHASE_1:
      case QM_PROP_PHASE_2:
        {
         if(cap_pct <= 0.0 || cap_pct > 5.0)
           {
            QM_LogEvent(QM_ERROR, "PROP_PHASE_CAP_REJECT",
                        StringFormat("{\"phase\":\"%s\",\"cap_pct\":%.4f,"
                                     "\"legal_band\":\"(0,5.0]\",\"reason\":\"cap_out_of_band\"}",
                                     QM_PropPhaseName(prop_phase), cap_pct));
            return false;
           }
         // review H2: the compiled default is 1.0. A sprint phase left at 1.0 is
         // the silent-1x book the whole exercise exists to kill. Refuse it loudly
         // unless the operator DELIBERATELY opts into unit risk.
         if(MathAbs(cap_pct - 1.0) < 1e-9 && !prop_allow_unit_risk)
           {
            QM_LogEvent(QM_ERROR, "PROP_PHASE_CAP_REJECT",
                        StringFormat("{\"phase\":\"%s\",\"cap_pct\":%.4f,"
                                     "\"reason\":\"unit_risk_default_in_sprint_phase\","
                                     "\"fix\":\"set qm_risk_cap_pct>1 OR prop_allow_unit_risk=true\"}",
                                     QM_PropPhaseName(prop_phase), cap_pct));
            return false;
           }
         // Verification FINDING 1 (2026-07-27): prop_expected_login defaults to 0
         // and neither shipped phase set carries it, so the account guard at
         // QM_PropInit was inert exactly where it mattered. An oversized sprint
         // cap could therefore arm on ANY attached account, including a Funded
         // one whose legal band is (0,1.0]. Live, a cap above the Funded band now
         // REQUIRES the set file to name its account. The tester is exempt: it
         // runs RISK_FIXED with a synthetic login, and demanding a real login
         // there would break every backtest without protecting any capital.
         if(!MQLInfoInteger(MQL_TESTER) && cap_pct > 1.0 && prop_expected_login == 0)
           {
            QM_LogEvent(QM_ERROR, "PROP_PHASE_CAP_REJECT",
                        StringFormat("{\"phase\":\"%s\",\"cap_pct\":%.4f,"
                                     "\"reason\":\"sprint_cap_above_funded_band_without_account_binding\","
                                     "\"fix\":\"set prop_expected_login to the challenge account login\"}",
                                     QM_PropPhaseName(prop_phase), cap_pct));
            return false;
           }
         // review M2: (4.0,5.0] is a one-stop-out daily-limit breach against the
         // -5% FTMO daily loss. Legal (5.0 is OWNER-ratified) but flagged loudly.
         if(cap_pct > 4.0)
            QM_LogEvent(QM_WARN, "PROP_PHASE_CAP_NEAR_DAILY_LIMIT",
                        StringFormat("{\"phase\":\"%s\",\"cap_pct\":%.4f,"
                                     "\"daily_loss_limit_pct\":5.0,"
                                     "\"note\":\"single_max_cap_stopout_can_breach_daily_limit\"}",
                                     QM_PropPhaseName(prop_phase), cap_pct));
         return true;
        }

      case QM_PROP_PHASE_FUNDED:
        {
         if(cap_pct <= 0.0 || cap_pct > 1.0)
           {
            QM_LogEvent(QM_ERROR, "PROP_PHASE_CAP_REJECT",
                        StringFormat("{\"phase\":\"FUNDED\",\"cap_pct\":%.4f,"
                                     "\"legal_band\":\"(0,1.0]\",\"reason\":\"cap_out_of_band\"}",
                                     cap_pct));
            return false;
           }
         return true;
        }
     }
   // Unknown enum → fail closed.
   QM_LogEvent(QM_ERROR, "PROP_PHASE_CAP_REJECT",
               StringFormat("{\"phase\":%d,\"cap_pct\":%.4f,\"reason\":\"unknown_phase\"}",
                            (int)prop_phase, cap_pct));
   return false;
  }

// Weekend / 2h-break legality for the selected phase. FTMO's weekend-close rule
// applies to a Standard FUNDED account only; Challenge/Verification have no
// weekend rule, and Swing accounts are exempt. Call in OnInit; false → INIT_FAILED.
bool QM_PropPhaseValidateWeekend(const bool friday_close_enabled)
  {
   switch(prop_phase)
     {
      case QM_PROP_PHASE_OFF:
      case QM_PROP_PHASE_1:
      case QM_PROP_PHASE_2:
         return true; // no weekend requirement before Funded

      case QM_PROP_PHASE_FUNDED:
        {
         if(prop_swing_account)
           {
            // review M3: unverified operator claim. Loud + auditable; the real
            // account type must be confirmed at deploy time.
            QM_LogEvent(QM_WARN, "PROP_PHASE_SWING_CLAIMED",
                        "{\"phase\":\"FUNDED\",\"prop_swing_account\":true,"
                        "\"note\":\"weekend_guard_bypassed_on_unverified_swing_claim;"
                        "verify_account_type_at_deploy\"}");
            return true;
           }
         if(friday_close_enabled)
           {
            // review M1: friday-close covers the weekend but NOT >2h daily/holiday
            // index-session breaks or gap-trading windows. Loud so an index /
            // multi-day Funded sleeve is not silently treated as compliant.
            QM_LogEvent(QM_WARN, "PROP_PHASE_FUNDED_WEEKEND_PARTIAL",
                        "{\"phase\":\"FUNDED\",\"friday_close_enabled\":true,"
                        "\"note\":\"friday_close_only;does_not_cover_>2h_daily_or_holiday_breaks;"
                        "multi_day_or_index_holds_require_intraday_flat_or_swing\"}");
            return true;
           }
         QM_LogEvent(QM_ERROR, "PROP_PHASE_WEEKEND_REJECT",
                     "{\"phase\":\"FUNDED\",\"friday_close_enabled\":false,"
                     "\"prop_swing_account\":false,"
                     "\"reason\":\"funded_requires_friday_close_or_swing\"}");
         return false;
        }
     }
   QM_LogEvent(QM_ERROR, "PROP_PHASE_WEEKEND_REJECT",
               StringFormat("{\"phase\":%d,\"reason\":\"unknown_phase\"}", (int)prop_phase));
   return false;
  }

// Proof-of-effect log (requirement #2 / review H1). Call in OnInit immediately
// AFTER QM_FrameworkSetRiskCapPct, passing the effective cap read back from the
// sizer (g_qm_risk_per_trade_cap_pct, visible in an EA that includes QM_Common).
// This proves the override took effect FROM A LOG, not from reading source. It
// proves the CEILING only — realised position size is set by RISK_PERCENT /
// RISK_FIXED, so an observable-size check (lots x stop-money == N% of anchored
// balance) is required separately before any live deploy (see implementation note).
void QM_PropLogEffectiveCap(const double requested_cap_pct, const double effective_cap_pct)
  {
   const bool matched = (MathAbs(requested_cap_pct - effective_cap_pct) < 1e-9);
   QM_LogEvent(matched ? QM_INFO : QM_ERROR, "PROP_EFFECTIVE_CAP",
               StringFormat("{\"phase\":\"%s\",\"requested_cap_pct\":%.4f,"
                            "\"effective_cap_pct\":%.4f,\"matched\":%s,"
                            "\"note\":\"ceiling_not_position_size\"}",
                            QM_PropPhaseName(prop_phase), requested_cap_pct,
                            effective_cap_pct, matched ? "true" : "false"));
  }

int QM_PropDayKey(const datetime t)
  {
   MqlDateTime s;
   TimeToStruct(t, s);
   return s.year * 10000 + s.mon * 100 + s.day;
  }

// State must survive terminal restarts: a challenge runs for weeks, and a
// restart that forgets the start balance would silently re-anchor the target to
// whatever the balance happens to be that morning.
//
// The file lives under FILE_COMMON, which is shared by EVERY terminal on this
// machine. Two accounts running the same EA therefore collide unless the state
// is namespaced per account. It is keyed by ea_id + login + server in the file
// NAME, and the account login is also recorded INSIDE the file so a stale or
// mis-copied file cannot feed one account another account's start balance or
// target flag (see QM_PropLoadState).
bool QM_PropSaveState()
  {
   if(g_qm_prop_state_file == "")
      return false;
   int h = FileOpen(g_qm_prop_state_file, FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);
   if(h == INVALID_HANDLE)
      return false;
   FileWriteString(h, StringFormat("%I64d;%.2f;%d\n",
                                   AccountInfoInteger(ACCOUNT_LOGIN),
                                   g_qm_prop_start_balance,
                                   g_qm_prop_target_reached ? 1 : 0));
   FileClose(h);
   return true;
  }

bool QM_PropLoadState()
  {
   if(g_qm_prop_state_file == "" ||
      !FileIsExist(g_qm_prop_state_file, FILE_COMMON))
      return false;
   int h = FileOpen(g_qm_prop_state_file, FILE_READ|FILE_TXT|FILE_ANSI|FILE_COMMON);
   if(h == INVALID_HANDLE)
      return false;
   string line = FileReadString(h);
   FileClose(h);
   string parts[];
   if(StringSplit(line, ';', parts) < 3)
      return false;
   // Defence in depth against the shared FILE_COMMON namespace: refuse any file
   // whose recorded login does not match the account we are actually attached
   // to, rather than trusting the balance/target it carries.
   const long recorded_login = (long)StringToInteger(parts[0]);
   const long current_login  = AccountInfoInteger(ACCOUNT_LOGIN);
   if(recorded_login != current_login)
     {
      QM_LogEvent(QM_WARN, "prop_state_account_mismatch",
                  StringFormat("{\"recorded_login\":%I64d,\"current_login\":%I64d,"
                               "\"action\":\"ignore_state\"}",
                               recorded_login, current_login));
      return false;
     }
   double bal = StringToDouble(parts[1]);
   if(bal <= 0.0)
      return false;
   g_qm_prop_start_balance  = bal;
   g_qm_prop_target_reached = (StringToInteger(parts[2]) == 1);
   return true;
  }

bool QM_PropInit(const int ea_id)
  {
   g_qm_prop_initialized    = false;
   g_qm_prop_target_reached = false;
   g_qm_prop_day_halted     = false;
   if(prop_phase == QM_PROP_PHASE_OFF)
      return true;

   // review H3: bind a prop set file to a specific account. If the operator set
   // an expected login and it does not match the attached account, refuse to arm
   // — a Phase-1 set file deployed to a different (e.g. Funded) account fails
   // init instead of trading a wrong-phase cap on a live account.
   const long login = AccountInfoInteger(ACCOUNT_LOGIN);
   if(prop_expected_login != 0 && login != prop_expected_login)
     {
      QM_LogEvent(QM_ERROR, "PROP_PHASE_ACCOUNT_MISMATCH",
                  StringFormat("{\"phase\":\"%s\",\"expected_login\":%I64d,"
                               "\"actual_login\":%I64d,\"action\":\"init_failed\"}",
                               QM_PropPhaseName(prop_phase), prop_expected_login, login));
      return false;
     }

   // Namespace the shared-FILE_COMMON state per account so two accounts running
   // the same EA cannot read or overwrite each other's start balance / target.
   const string server = QM_LoggerSanitizeSlug(AccountInfoString(ACCOUNT_SERVER));
   g_qm_prop_state_file = StringFormat("QM\\prop\\%d_%I64d_%s.state",
                                       ea_id, login, server);

   if(!QM_PropLoadState())
     {
      g_qm_prop_start_balance = (prop_start_balance > 0.0)
                                ? prop_start_balance
                                : AccountInfoDouble(ACCOUNT_BALANCE);
      if(g_qm_prop_start_balance <= 0.0)
        {
         QM_LogEvent(QM_ERROR, "prop_init_no_balance",
                     "{\"reason\":\"cannot anchor challenge start balance\"}");
         return false;
        }
      QM_PropSaveState();
     }

   g_qm_prop_day_key      = QM_PropDayKey(TimeCurrent());
   g_qm_prop_day_start_eq = AccountInfoDouble(ACCOUNT_EQUITY);
   g_qm_prop_initialized  = true;

   // review L2: prop_anchor_risk_to_start is honoured only if the sizing call is
   // fed QM_PropRiskBasis, which QM_Entry does NOT do today. Do not let the init
   // log assert an anchor that is not applied.
   if(prop_anchor_risk_to_start)
      QM_LogEvent(QM_WARN, "prop_anchor_not_wired",
                  "{\"note\":\"prop_anchor_risk_to_start=true but QM_PropRiskBasis is not "
                  "wired into the QM_Entry sizing path; live sizes off live equity\"}");

   QM_LogEvent(QM_INFO, "prop_init",
               StringFormat("{\"phase\":\"%s\",\"phase_id\":%d,\"venue\":\"%s\","
                            "\"start_balance\":%.2f,\"target_pct\":%.2f,"
                            "\"flatten_at_target\":%s,\"daily_halt_pct\":%.2f,"
                            "\"derisk_at_pct\":%.2f,\"derisk_scale\":%.2f,"
                            "\"risk_anchor_input\":\"%s\",\"risk_anchor_wired\":false}",
                            QM_PropPhaseName(prop_phase), (int)prop_phase,
                            QM_LoggerEscapeJson(prop_venue),
                            g_qm_prop_start_balance, QM_PropTargetPct(),
                            QM_PropFlattenEnabled() ? "true" : "false",
                            prop_daily_halt_pct, prop_derisk_at_loss_pct,
                            prop_derisk_scale,
                            prop_anchor_risk_to_start ? "start_balance" : "equity"));
   return true;
  }

// The balance risk sizing is computed against. RISK_PERCENT normally sizes off
// live equity, which drifts upward as the challenge gains and so does not
// reproduce the RISK_FIXED behaviour every backtest used. Anchoring to the start
// balance keeps deployed size equal to what was measured. NOTE (review L2): this
// is defined but not yet called by QM_Entry — wiring it is a separate change.
double QM_PropRiskBasis(const double fallback)
  {
   if(prop_phase == QM_PROP_PHASE_OFF || !g_qm_prop_initialized || !prop_anchor_risk_to_start)
      return fallback;
   return g_qm_prop_start_balance;
  }

double QM_PropRiskScale()
  {
   if(prop_phase == QM_PROP_PHASE_OFF || !g_qm_prop_initialized)
      return 1.0;
   if(prop_derisk_at_loss_pct <= 0.0)
      return 1.0;
   const double eq   = AccountInfoDouble(ACCOUNT_EQUITY);
   const double down = (g_qm_prop_start_balance - eq) / g_qm_prop_start_balance * 100.0;
   return (down >= prop_derisk_at_loss_pct) ? prop_derisk_scale : 1.0;
  }

void QM_PropFlattenAll(const long magic, const string reason)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(magic != 0 && PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(!g_qm_prop_trade.PositionClose(ticket))
         QM_LogEvent(QM_ERROR, "prop_flatten_failed",
                     StringFormat("{\"ticket\":%I64u,\"reason\":\"%s\",\"retcode\":%d}",
                                  ticket, QM_LoggerEscapeJson(reason),
                                  g_qm_prop_trade.ResultRetcode()));
     }
  }

// How many positions for this magic are still open. Used to CONFIRM a flatten
// actually emptied the book before the challenge state is recorded as halted.
int QM_PropOpenPositions(const long magic)
  {
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(magic != 0 && PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      n++;
     }
   return n;
  }

// Call once per tick, before entry logic. Returns false when the EA must not
// open new positions.
bool QM_PropEntryAllowed(const long magic)
  {
   if(prop_phase == QM_PROP_PHASE_OFF || !g_qm_prop_initialized)
      return true;

   const int today = QM_PropDayKey(TimeCurrent());
   if(today != g_qm_prop_day_key)
     {
      g_qm_prop_day_key      = today;
      g_qm_prop_day_start_eq = AccountInfoDouble(ACCOUNT_EQUITY);
      g_qm_prop_day_halted   = false;
     }

   if(g_qm_prop_target_reached)
      return false;

   const double eq     = AccountInfoDouble(ACCOUNT_EQUITY);
   const double target = g_qm_prop_start_balance * (1.0 + QM_PropTargetPct() / 100.0);

   if(QM_PropFlattenEnabled() && eq >= target)
     {
      // Order matters: flatten FIRST (on the EQUITY trip, so we lock the +target
      // the instant it exists, floating or realised), then decide whether the
      // challenge is actually WON. If a close fails, leave the state unwritten so
      // the next tick retries rather than stranding live exposure behind a "flat"
      // flag.
      QM_PropFlattenAll(magic, "target_reached");
      const int remaining = QM_PropOpenPositions(magic);
      if(remaining > 0)
        {
         QM_LogEvent(QM_WARN, "prop_target_flatten_pending",
                     StringFormat("{\"equity\":%.2f,\"target\":%.2f,\"remaining\":%d,"
                                  "\"action\":\"retry_next_tick\"}",
                                  eq, target, remaining));
         return false;
        }

      // Book empty. review H4: FTMO passes on realised BALANCE >= target with all
      // positions closed — NOT on the equity excursion that tripped the flatten.
      // Latch the permanent "won" state only if realised balance actually reached
      // target; otherwise stay armed (target_reached stays false) so the EA keeps
      // trading toward target instead of latching a pass below target and idling
      // into a dormancy block.
      const double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      if(balance >= target)
        {
         g_qm_prop_target_reached = true;
         QM_PropSaveState();
         QM_LogEvent(QM_INFO, "prop_target_reached",
                     StringFormat("{\"equity\":%.2f,\"balance\":%.2f,\"target\":%.2f,"
                                  "\"action\":\"flat_and_halt\"}",
                                  eq, balance, target));
        }
      else
        {
         QM_LogEvent(QM_WARN, "prop_target_flatten_shortfall",
                     StringFormat("{\"equity\":%.2f,\"balance\":%.2f,\"target\":%.2f,"
                                  "\"action\":\"stay_armed\","
                                  "\"reason\":\"equity_trip_but_realised_balance_below_target\"}",
                                  eq, balance, target));
        }
      return false;
     }

   if(prop_daily_halt_pct > 0.0)
     {
      const double day_pnl_pct =
         (eq - g_qm_prop_day_start_eq) / g_qm_prop_start_balance * 100.0;
      if(day_pnl_pct <= -prop_daily_halt_pct)
        {
         if(!g_qm_prop_day_halted)
           {
            g_qm_prop_day_halted = true;
            QM_PropFlattenAll(magic, "daily_halt");
            QM_LogEvent(QM_INFO, "prop_daily_halt",
                        StringFormat("{\"day_pnl_pct\":%.2f,\"limit_pct\":%.2f}",
                                     day_pnl_pct, prop_daily_halt_pct));
           }
         return false;
        }
     }

   return true;
  }

#endif // QM_PROP_FIRM_MQH
