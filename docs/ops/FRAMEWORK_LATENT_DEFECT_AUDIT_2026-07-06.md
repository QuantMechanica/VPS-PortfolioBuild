# Framework Latent-Defect Audit — 2026-07-06

**What:** First deliberate, framework-wide hunt for latent defect classes, run as a
7-lane parallel agent audit with adversarial verification of every critical finding.
Motivation: four major dead-code/UB finds in the week to 07-06 (halt channel,
symbol_slot UB, news index defect, Q09 basket bug) were ALL accidental by-catch of
other investigations. This audit made the hunt systematic. OWNER directive 07-06:
"arbeite das der Reihe nach durch" (Fable program item #1).

**Lanes:** A sandbox/file-paths · B uninitialized structs · C indicator-handle misuse ·
D silent fallbacks/divergent duplicates · E time/bar/lookahead · F numeric/order
safety · G Python/PS evidence layer. Scope: all 34 `framework/include/QM/*.mqh`
(8,548 lines, read line-by-line by multiple lanes), `EA_Skeleton.mq5`, the phase
runners, `run_smoke.ps1`, `gen_setfile.ps1`, the Q08 Davey battery, the Q09
portfolio module, plus 40+ generated EA sources and corpus-wide greps over 2,694
EA dirs.

**Verification discipline:** every CRITICAL was re-verified by direct read of the
cited lines before any fix (F1, A1/D1, C1/E1/D3, E2, E4/D4, E7, B1/B2, G1, G4,
G6, G7 all confirmed; zero critical findings refuted). One tooling lesson en route:
a repo-wide ripgrep transiently dropped a real match (QM_TradeContext.mqh:91) —
re-confirmed the standing rule that grep output is never proof-of-absence; criticals
get full-file reads.

---

## 1. CRITICAL findings (all verified, all fixed 2026-07-06)

### F1/D2 — Permanent NO_MONEY latch blocked position CLOSES (live, both books)
`QM_TradeContext.mqh`: first `TRADE_RETCODE_NO_MONEY` set a latch that was never
reset and gated EVERY subsequent OrderSend — including closes, SL/TP modifies,
Friday close, basket rollback, time exits. One transient margin spike on the shared
account (15 DXZ sleeves / 12 FTMO legs) would leave the affected EA unable to flatten
until manual reload. Compounder F2: basket leg-2 NO_MONEY made the leg-1 rollback
fail through the just-set latch → naked FX leg (12778 class).
**Fix (d8b741d02):** latch now gates only exposure-OPENING requests
(`QM_TradeContextOpensExposure`: DEAL with position=0, or PENDING); closes/SLTP/
REMOVE/CLOSE_BY always pass; latch re-arms per broker day; latched rejections are
WARN-logged (were silent). *Reaches live books at next rebuild.*

### C1/D3/E1 — QM_StopATR raw-handle helper still poisoned the fleet
`QM_StopRules.mqh:52-75` (`QM_StopRulesReadATRValue`): raw iATR → CopyBuffer →
IndicatorRelease per call — the root of the ops-confirmed "1 trade then permanent
silence" class (4 confirmed cases: 12852, 12616, 12594, 12591). The 07-05 fixes were
call-site-only by design; the helper and its three framework routes (`QM_StopATR`,
`QM_TakeATR`, `QM_TM_TrailATR`) were unchanged, and `EA_Skeleton.mq5` still
RECOMMENDED the pattern. Exposure: 59 EA dirs on period-form Stop/TakeATR, 85 on
TM_TrailATR, 306 sources combining `QM_ATR(` + `QM_StopATR(`; fresh v2 builds
(12874, 13000, 13004, 13009, 13014, 13016) carried the collision profile into
Q02 THIS WEEK. Live sleeves 11132/12567(×2)/10513 use the raw path at entry but
have NO pooled same-spec twin (which is why their evidence was full-count);
12989 trails per-tick.
**Fix (d8b741d02):** helper now reads through the pooled `QM_ATR` (QM_Indicators),
no create/release. Kills the class at the source for all 3 routes and all future
builds. Compile-validated (10163, 11132, skeleton — all 0/0).
**Residue:** queued Q02 evidence for 12874/13000/13004/13009/13014/13016 was
produced (or will be produced) by pre-fix binaries → rebuild-in-place primed; treat
any 1-trade Q02 result from pre-fix binaries of this profile as the known bug, not
a strategy verdict.

### A1/D1 — KS distribution kill-switch was born dead (Q13 safety layer)
`QM_KillSwitchKS.mqh:203` built the baseline path as `D:\QM\data\baselines\…` —
drive-letter paths NEVER resolve in the MQL5 sandbox (the exact halt-channel class
fixed 07-05 in the SIBLING file; 47f4d/47f1d9709 did not touch this one). Worse, the
failure is deliberately non-fatal ("dormant", INFO) — it would never have told us.
The writer (`gen_q10_baseline.py`) wrote to the same unreachable location; the dir
has been empty since FW4 (2026-05-23). The entire 4th kill path (KS distribution
divergence — the Q13 burn-in protection) has been dead code its whole life; masked
only because no EA has reached Q13 yet.
**Fix (d8b741d02 + 8158dca1b):** sandbox-relative `QM\baselines\QM5_<id>_<sym>.json`
(local → FILE_COMMON), writer targets
`C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files\QM\baselines`.
Stale D:\-path comments corrected (A6). D-lane verdict: the two KillSwitch files are
two SUBSYSTEMS, not divergent duplicates — both wired via QM_Common.

### E2/E15 — Daily-loss kill switch is not restart-safe (live, both books) — TICKET
`QM_KillSwitchInit` resets halt state and re-anchors `day_start_equity` at
attach-time equity. Any mid-day reload (recompile, terminal restart, session-loss
watchdog auto-reboot — which exists on this VPS) erases an active −3% halt and
allows a fresh −3% the same day → stacked ~6% intra-day vs FTMO's 5% daily limit.
KS_MANUAL persists via halt files; KS_DAILY_LOSS does not.
**Not hot-patched** (persistence design: tester-exempt state file, lifecycle,
re-arm semantics) → **Wave-2 ticket, before the paid FTMO challenge.** Same design
must document/set the FTMO day-anchor question (E3: broker-midnight UTC+3 vs FTMO
midnight CE(S)T on max(balance,equity) — 1h gap + balance>equity gap).

### G9c — gen_setfile silently defaulted magic slot 0 (live-artifact adjacent)
No active `magic_numbers.csv` row for (ea_id, symbol) → `qm_magic_slot_offset=0`
emitted silently → collision-prone artifact that `QM_MagicRegistered` VALIDATES
(slot-0 magic is registered — for the wrong symbol). Env=live flowed through the
same code. **Fix (6113c8927):** hard throw (registry missing or row missing), per
the ratified order-of-operations rule.

---

## 2. Gate-integrity fixes (evidence layer, all shipped 6113c8927)

| ID | Defect | Direction of error | Fix |
|---|---|---|---|
| G1 | German terminals (T2/T6): no alias for "Equity Drawdown Maximal" → DD parsed 0.0 → **15% DD ceiling never bound there** | passed DD-blowout EAs | real-report-verified aliases ("Rückgang Equity maximal", "Qualität der Historie") |
| G13 | Missing graded-metric labels defaulted to 0s with no invalid marker → parse drift graded as strategy FAIL | both | `REPORT_METRIC_MISSING:<metric>` markers (0-trade reports verified to carry all labels — no requeue-churn risk) |
| G4 | Q08 report-fallback trades carry no volume → commission $0 → **DL-072 cushion auto-PASS + PF-net==PF-gross** exactly on degraded evidence | passed cost-fragile EAs | all-volume-less trade set → cushion INVALID → aggregate INVALID (re-run) |
| G7 | Q09 basket fix f8e79266b incomplete: durable store keys streams by LOGICAL symbol, resolver looked only for host-keyed files (12772/12864 verified broken on disk; 12778 worked only via manual copy) | blocked baskets (NEED_MORE_DATA) | existence-aware resolver with logical-name fallback + persister writes host AND logical copies. Functional test: 12772 0→226 trades, 12864 0→106, 12778 regression-free |
| G3 | Q08 baseline retry adopted newest summary from the shared per-EA dir — possibly ANOTHER SYMBOL's run | cross-symbol contamination | symbol-gated summary adoption |
| G6 | Q08.5 runner hardcoded `-Period H1` → non-H1 EAs got plateau evidence on the wrong timeframe | wrong evidence | `period_from_setfile` |
| G5 | One timed-out perturbation (pf=None→0.0) → plateau breach → **FAIL_HARD** | killed EAs on infra | pf=None rows → INVALID (re-run); parsed pf with 0 trades REMAINS a breach (real fragility). Suite 39/39 |
| G2 | Q10 graded infra-invalid summaries (NO_HISTORY cold cache etc.) as strategy FAIL at the final confirmation gate | killed EAs on infra | `summary_invalid_reason` mirror of q05/q06 + timeout handling |
| G16 | q08.5/q10 wrapper timeout == tester budget (no headroom) | INVALID churn | +120s headroom (q05/q06 pattern) |

MQL5-side evidence fixes in d8b741d02: A4 (silent Q04/Q08 Common write failures now
WARN-logged), B4/C4/E18/F16 (EquityStream ATR-regime median required copied==100 —
partial CopyBuffer sorted stack garbage into `atr_regime`), D5 (zero-row calendar
now fails init — previously "news-filtered" evidence with no filter), B1/B2
(QM_EntryRequest default-init constructor: retroactively neutralizes the 394-source
uninit class at next compile; skeleton ZeroMemory + corrected TODO).

---

## 3. Wave-2 ticket queue (design-sensitive; Codex review after Tuesday reset)

1. **IMPLEMENTED 2026-07-06 (eb5195a14) — review-only.** KS daily-loss restart
   persistence (E2/E15): state persisted terminal-locally (`QM\halt\
   ks_state_<ea>.state`, write on trip BEFORE the flatten + on day roll,
   restore only for the same halt-day, magic-checked, tester-exempt).
   FTMO day anchor (E3): `QM_KillSwitchSetDayAnchor(offset_hours,
   use_max_balance_equity)` — defaults preserve historical behavior; the FTMO
   preset opts in at challenge rebuild (recommended: offset −1h ≈ Prague
   midnight on the UTC+3/+2 server both seasons except brief US/EU DST
   divergence windows; baseline max(balance,equity)). Fail-safe: re-anchoring
   never clears an active halt.
2. **IMPLEMENTED 2026-07-06 (fadd5eaf8, pump-swept) — review-only.** Live news
   compliance axis (E4/D4): `QM_NewsLiveComplianceAllows` = native-calendar
   mirror of the tester firm-window check (per-impact tables + min-impact
   pre-filter for exact parity); live branch now ANDs both axes; fail-closed.
   STILL OPEN in this area: E5 (SKIP_DAY live=±24h vs tester=UTC-day) and E10
   (per-bar verdict cache — D1 charts sample firm windows once per bar; failed
   live reads cached until next bar) — both remain design items.
3. **IMPLEMENTED 2026-07-06 (fadd5eaf8 + ce7516286) — review-only.**
   Filling-mode resolution (F3): `QM_TradeContextResolveFilling` applied in
   QM_Entry, QM_BasketOrder, QM_TM_CloseByVolume; kill-switch CTrade close
   sets filling per position symbol (F14 residue closed).
4. **DONE_PARTIAL reconciliation (F4)** — partial fills treated as full; entry logs
   overstate exposure; partial close leaves residual position with flat EA state.
5. **Stops-level/freeze-level backstop (F5)** — trailing/modify paths never check
   SYMBOL_TRADE_STOPS_LEVEL (0 on .DWX in tester, real live) → trails that "worked"
   in evidence silently reject live.
6. **Kill-switch/Friday close: pending-order sweep (E11) + Friday-close retry
   (E12)** — halts/Friday flatten positions but leave resting pendings; Friday close
   is one-shot even when closes fail (weekend exposure).
7. **Basket init hardening (D6/D8)** — leg slots verified only lazily (silent
   zero-trade legs); QM_BasketOpenPosition supports only legacy news mode (per-leg
   2-axis gate impossible without hand-rolled hook).
8. **Indicator error channel (C3/D9/E6)** — QM_IndicatorReadBuffer returns in-band
   0.0 on failure; several QM_Sig_* primitives fabricate direction from it (RSI 0.0
   = "oversold", BB upper 0.0 = "short"). API change: sentinel + QM_IndValid.
9. **Runner robustness batch (G8/G10/G11/G12/G15/G17-G24)** — Q04 stream-loss folds
   → INVALID not FAIL; p2 infra taxonomy aligned with farmctl; stale-summary
   adoption identity-gated everywhere; shared number normalizer + German "Deals"
   anchor alias; Q08 baseline DL-069 dir resolution; PBO empty-slice handling (G14);
   gen_setfile param-empty postcondition (G9a/b).
10. **Misc register-only:** D11 ChartUI fabricates status (mitigated by "logs not
    visuals" rule), D13 QM_Exit second Friday-close engine + magic=0 lazy init
    (QM5_1505 family), D16/A5 dead logger primary path, D17 manual-halt re-arm gap,
    E8 wall-clock "bar" holds in 5 of 6 v2 EAs (13015 is the correct pattern), E9
    W1 calendar-key year-boundary double-fire (no current W1 users), E13 W1/MN1
    legacy EAs + MTFCoherence (tester-dead on .DWX), E14/C10/D15 pool-exhaustion
    silence (16/64 caps), E19 session-window DST semantics, C5 fractal EMPTY_VALUE
    (QM5_10550 evidence invalid), C7 12821 CSM W1/MN1 doctrine conflict (+.DWX
    suffix hardcode — blocks any live deploy), C8 legacy unchecked-CopyBuffer EAs
    (12110/12111/12112 evidence suspect), C9 Ichimoku shift doc-vs-default, A3
    drive-letter input defaults (12971/12972/12918), A7 fallback-order asymmetry,
    A8 no tester_file (constraint: local agents only), A9/G-class stale-stream
    overwrite semantics, B3 expiration_seconds unset in 34 market-order EAs
    (build-lint candidate), B5/F6/F7 grid module state (no live users), F8
    SYMBOL_VOLUME_LIMIT unchecked, F9 point-value fallback currency assumption,
    F10/F14/F15 shared-account equity semantics (document as design), F12 stale-
    price retry, F17/F20 margin pre-check absence (OrderCalcMargin), F11
    QM_TM_MoveSL(0) deletes stop, E16 DST ambiguity policy (documented, OK), E17
    tester calendar-coverage end guard, G18-G24 low-severity runner items.

## 4. Verdict-reading rules established by this audit

- **B2:** 394 sources never init `symbol_slot` (104 EAs / 360 pending Q02 items).
  Historical record: 4,695 INFRA_FAIL / 447 FAIL / 94 PASS in this population.
  Zero-trade Q02 FAILs there are SUSPECT (garbage-slot class) until the EA is
  recompiled with the new constructor; PASSes are stack-luck and flip on recompile.
- **C1-residue:** 1-trade Q02/smoke results from pre-fix binaries of the
  QM_ATR+QM_StopATR profile = the known bug (strong prior), not low frequency.
- **G1-residue:** historical DD values parsed on German terminals (T2/T6 runs) may
  be silently 0.0 — any borderline DD-gate PASS whose evidence ran on T2/T6 should
  be re-checked before promotion. (Forward runs are fixed.)
- **Week-28 session rule:** the two staged S4 binaries (10706/11708, compiled
  07-06 pre-audit) and ANY new admit must be RE-COMPILED after this wave so live
  books carry the latch/StopRules/KS fixes. Add to the session checklist.

## 5. Status & evidence

- MQL5 fixes: pump auto-commit **d8b741d02** (swept the include edits; noted for
  history), skeleton/writer **8158dca1b**, evidence layer **6113c8927**.
- Compile validation: QM5_10163, QM5_11132, EA_Skeleton — all 0 errors / 0 warnings.
- Tests: `test_q08_davey_subgates.py` 39/39 PASS. PS parser: 0 errors both scripts.
- Functional: Q09 resolver on-disk test (12772/12864/12778 above).
- Full lane reports: session d6e64bc6 agent outputs (A: a87dec3f4340fa078,
  B: a59b3b8b1efe4976e, C: a957f46dbb49d6fda, D: abd212189e6a92e4b,
  E: a23fa3b21e0f8380b, F: aee35cde47722e195, G: aea6647f65ea8b400).
- Rollout: live books unchanged until next rebuild (standard pattern); factory
  builds pick up new includes immediately via compile-time sync.
