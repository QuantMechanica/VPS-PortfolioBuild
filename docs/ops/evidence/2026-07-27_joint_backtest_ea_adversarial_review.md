# Adversarial review — Joint FTMO backtest-only EA design (2026-07-27)

**Reviewer:** Claude (board-advisor worktree). **Adversary role:** refute the design.
**Target:** `docs/ops/evidence/2026-07-27_joint_backtest_ea_design.md`.
**Read for this review (in full or the cited ranges):** the design; both recon docs
(`…_multisymbol_machinery_recon.md`, `…_mt5_multisymbol_tester_recon.md`); the equity-gap
memo (`a5768d03_equity_export_gap_2026-07-27.md`); the single-account adversarial review;
the sleeve brief; and the real sources —
`framework/EAs/QM5_9936_…/…mq5` (full), `…QM5_13213_…mq5` (strategy hooks),
`…QM5_10848_tv-mtf-ambush.mq5` (full), `framework/include/QM/QM_BasketOrder.mqh` (full),
`QM_Common.mqh:390-432,860-979`, `QM_EquityStream.mqh`, `QM_SymbolGuard.mqh`,
`QM_RiskSizer.mqh:80-170`, `QM_Indicators.mqh:108`, and both registries.

**Default stance:** refuted-when-uncertain. Every finding carries a `file:line`, a concrete
failure scenario, and a severity. What survives is stated explicitly at the end.

---

## Verdict

**The instrument as designed CANNOT be trusted for its stated purpose — for the one sleeve
that justifies building it (10848 : XAUUSD.DWX).** The two USDJPY sleeves can be made
faithful; the cross-asset gold sleeve cannot, and the design's sole fidelity control is
structurally blind to the reason why. Because 10848 is simultaneously (a) "the point" of the
2-symbol run (design §1) and (b) the input to both headline deliverables — the joint equity
path and the USDJPY↔XAUUSD correlation — its infidelity contaminates both. The joint run
would produce a **precise-looking equity curve and correlation number for a gold sleeve that
is not the gated gold sleeve.** That is the exact failure the task says would "waste the
entire exercise."

A restricted instrument — **USDJPY-only (9936 + 13213), host USDJPY** — survives every
attack below and is worth building. It closes the intraday-interleaving gap and yields a real
account equity path for the two USDJPY sleeves. It does **not** yield a trustworthy
cross-asset correlation, because you cannot faithfully run a per-tick-managed foreign-symbol
sleeve from a host chart's tick stream.

---

## CRITICAL findings (each refutes a load-bearing claim)

### C1 — Non-host per-tick management is unfaithful: 10848 measures a *different* strategy in the joint run
**Claim refuted:** design §0/§3 "each sleeve's *exact* gated entry logic … fidelity is
verified by singleton replay"; §1 "10848 … delivers the one thing the USDJPY pair cannot."

**The break.** In an MT5 multi-currency test, `OnTick` fires **only on the chart (host)
symbol's ticks**. The framework's own history-load fix documents that secondary symbols are
second-class in the tester (`QM_SymbolGuard.mqh:100-108`, FW9). The design pins
`host_symbol = USDJPY.DWX` (§0, §2), so 10848 runs as a **non-host** sleeve and its code
executes only when a USDJPY tick arrives.

10848 is a **continuous, per-tick** manager:
- `Strategy_ManageOpenPosition` runs every tick (`QM5_10848…mq5:511`) and maintains a running
  high-water mark `g_highest_seen = MathMax(g_highest_seen, bid)` (`:417`) from
  `SymbolInfoDouble(_Symbol, SYMBOL_BID)` (`:406`); the safety trailing stop is
  `g_highest_seen * (1 - safety_trail_pct/100)` (`:421`) and is pushed via `QM_TM_MoveSL`
  (`:432`).
- The entry is a **market** order priced at `SymbolInfoDouble(_Symbol, SYMBOL_ASK)` (`:371`)
  at the instant the signal fires.

Standalone (XAUUSD host), `g_highest_seen` advances on **every XAUUSD tick** and the entry
fills at the first XAUUSD tick after the signal bar. In the joint EA (USDJPY host),
`g_highest_seen` advances only on **USDJPY ticks**, so the trailing-stop path — the primary
risk control of this strategy — is computed from gold prices *sampled at USDJPY tick times*.
The trailing SL level, the exit price, and therefore the trade's net P&L **differ from the
gated sleeve**. The market entry fills at a different gold price/time for the same reason.

**Failure scenario.** Gold spikes up then reverts inside a 90-second window in which USDJPY
happens not to tick (thin Asian-afternoon liquidity). Standalone 10848 ratchets
`g_highest_seen` to the spike top and trails the stop up, getting stopped on the revert. Joint
10848 never sees the spike (no host tick), leaves the stop low, and rides the position further
— a different exit, a different P&L, a different trade. Multiply over 8 years: 10848 in the
joint run is not 10848.

**Severity: CRITICAL.** This is task failure modes #1 (strategy fidelity) and #2 (secondary-
symbol OnTick) realised in code. The initial fixed SL/TP *are* honoured at true XAUUSD ticks
(they are order-level, processed by the tester engine), so the position does not run
unbounded — but the **trailing** exit, which dominates 10848's outcomes, does not.

### C2 — The design's only fidelity control cannot see C1
**Claim refuted:** §3.3 "singleton replay … catches any of §3.2's four divergences by
construction … the single most important control in this design"; §0 "fidelity is verified …
not asserted."

Singleton replay (§3.3 step 1) runs each sleeve **"on S's symbol as host."** For 10848 that
means **XAUUSD as host** → `OnTick` fires on XAUUSD ticks → `g_highest_seen` tracks XAUUSD
ticks → it reproduces the standalone stream and **replay passes**. But the authoritative joint
run uses **USDJPY as host** (§0). The replay and the joint run place 10848 in *different tick
environments*; a pass in the former is not evidence for the latter. The control validates the
symbol-parameterisation refactor and is **structurally incapable** of detecting the non-host
cadence divergence in C1 — the same class of blind spot the single-account review §3 flagged
("the self-check validates the refactor, not the coupling"), reproduced here one level up.

**Severity: CRITICAL.** The design's central promise ("verified, not asserted") is false for
the non-host sleeve.

### C3 — No host assignment makes all three sleeves faithful; the chosen host is the worst one
**Claim refuted (implicitly):** that host = USDJPY is a neutral packaging choice (§2).

All three sleeves do per-tick discretionary management on **their own** symbol, so whichever
symbol is not the host is sampled at the host's tick cadence:
- 9936: per-tick opposite-side touch exit reading `SYMBOL_BID/ASK` (`QM5_9936…mq5:410-416`)
  and per-tick "+1R reached" trail-arm (`:360-382`).
- 13213: identical per-tick exit/trail (`QM5_13213…mq5:360-366,414-417`).
- 10848: **continuous** high-water-mark trail (C1).

There is therefore **no host choice under which all three are faithful.** Worse, the USDJPY
sleeves' trail *level* is bar-structural (`iLow/iHigh` of bars 1-2, `9936:365-368`), so it only
changes on new bars — they are comparatively **robust** to being non-host. 10848's trail is a
tick-by-tick maximum and is the **most** cadence-sensitive. The design puts the most
cadence-sensitive sleeve (10848) in the non-host seat and the more robust ones (USDJPY) on the
host chart — the fidelity-maximising assignment would be the reverse, and even that only
reduces, not removes, the USDJPY divergence.

**Severity: CRITICAL (fundamental limitation); host choice HIGH.** Running heterogeneous
per-tick-managed strategies jointly on one chart is not a faithful measurement of any sleeve
that is not the host.

### C4 — The equity export under-samples the intraday low it exists to measure
**Claim refuted:** §7/§9 "the true single-account equity path (per-bar + **every intraday
low**) … −5% daily … become direct reads … with **no invented intratrade equity**"; §7
"determinism / bound … cheap."

`ACCOUNT_EQUITY` can only be read inside `OnTick` (or `OnTimer`), i.e. at **host (USDJPY)
tick** timestamps — confirmed by the shipped emitter, which reads `AccountInfoDouble(
ACCOUNT_EQUITY)` only in the new-bar path (`QM_EquityStream.mqh:249`, gated by `QM_IsNewBar`
in the EA at `9936…mq5:539-544`). The proposed `EQUITY_LOW` sampler ("on any tick whose
`ACCOUNT_EQUITY` is below the running min", §7) therefore samples the account low **only at
USDJPY tick times.**

Account equity includes the floating P&L of the open **XAUUSD** position. A gold-driven
intraday trough that occurs *between* two USDJPY ticks — and recovers before the next USDJPY
tick — is **never recorded**. The −5% daily predicate is computed from `EQUITY_LOW` (§7), so a
gold-driven daily breach can be **missed**. The bias is **optimistic** (fewer breaches than
reality) on the exact go/no-go metric the instrument is built to produce, and it is largest
precisely where it matters: volatile gold, quiet USDJPY.

The design asserts this away — "`EQUITY_LOW` rows are a handful per day … cheap" (§7) — without
bounding the sampling error against the inter-USDJPY-tick gap. The magnitude is not zero and is
**NOT ESTABLISHED** by the design.

**Severity: HIGH→CRITICAL.** This defeats gap #1 (the equity gap) for the cross-asset sleeve:
the "real, not proxy" equity path is real only at USDJPY-tick resolution, with an unquantified
optimistic bias on gold-driven intraday extremes.

---

## HIGH findings

### H1 — The correlation deliverable is contaminated and overclaimed
**Claim refuted:** §0/§9 "the **realised** correlation matrix (9936↔13213 … USDJPY↔XAUUSD)
… settling the '9936/13213 are one edge' hypothesis with measurement."

Two independent problems:
1. **USDJPY↔XAUUSD is measured against a distorted gold stream (C1).** The XAUUSD trade series
   in the joint run is not the gated sleeve's series, so the cross-asset correlation is between
   the real USDJPY sleeve and a cadence-distorted gold sleeve — not the number claimed.
2. **9936↔13213 correlation "settles" nothing.** Both are USDJPY range breakouts firing at the
   **same** 06:00 GMT+3 hour (`9936` range_end 6, `13213` range_end 6) off **overlapping**
   ranges (9936 01–06, 13213 03–06). They are near-collinear **by construction** — the design
   itself says so when arguing *for* XAUUSD ("two USDJPY range-breakouts firing at the same
   GMT+3 hour are near-collinear by construction", §1). A high measured correlation is
   guaranteed by the construction and is not evidence about independent alpha. §1 and §9
   contradict each other.

Task item #6 stands: correlation is a property of the **sample and period**, not a constant.
§9's CANNOT list carves out first-passage ESS but says nothing about the correlation estimate's
own (wide, one-path) CI — repeating the "oversold precision" error the single-account review §5
already charged.

**Severity: HIGH.** One of the three cited justifications (correlation) is not delivered
faithfully; the intra-USDJPY correlation is a tautology.

### H2 — Recommended next step recompiles two GATED production EAs
**Claim refuted:** §11 "extract `QM_Sig_RangeBreakout.mqh` and **re-point 9936/13213 at it** to
prove the shared module reproduces both standalone."

9936 is the **FTMO lead sleeve** (sleeve brief §2, §5). Re-pointing 9936 and 13213 at a new
shared include forces a recompile of two gated EAs; any transcription drift silently
invalidates their gated Q08 streams (the very streams under
`D:/QM/reports/portfolio/sleeve_streams/QM/q08_trades/9936_USDJPY_DWX.jsonl` that the whole
campaign rests on) and forces a full re-gate. This is task hazard #5 ("an include change that
alters other EAs") written into the build plan. The blast radius is unnecessary: the joint EA
can **copy** the logic into its own module and leave 9936/13213 untouched, with the USDJPY
singleton replay (which *is* valid for host-symbol sleeves) as the check.

**Severity: HIGH.** Avoidable perturbation of gated, campaign-critical EAs.

---

## MEDIUM findings

### M1 — "Do not re-implement" is contradicted by the design's own mechanism
§3.1 says "Do **not** re-implement any sleeve," then specifies turning each sleeve's
`Strategy_*` hooks into modules parameterised by `(symbol, timeframe, magic, params)` "taking
**no** dependency on `_Symbol` or `QM_FrameworkMagic()`." 10848 is `_Symbol`-bound in every
data accessor (`:108,113,118,371,406,426`) and filters by `QM_FrameworkMagic()` throughout;
converting those to parameters is a **re-implementation** with real edit surface. For the USDJPY
sleeves the replay guard covers the transcription; for XAUUSD it does not (C2). **Severity:
MEDIUM.**

### M2 — The 13213 parameter-binding recipe is defective, and "identical Strategy_* functions" is false
§3.1 claims 9936 and 13213 are "identical save for the window-hour inputs … differing only in
three hour parameters," and binds 13213 as "range_start=3, end=6, exit_hour=18 (rest are the
EA input defaults … identical to 9936's shared defaults)." In fact 13213 has **no separate
cancel hour**: it uses one `strategy_exit_hour=18` for **both** the pending-cancel
(`13213…mq5:330`) and the session close (`:396`), whereas 9936 uses **two** distinct hours,
cancel=13 (`9936…mq5:327`) and close=20 (`:392`). Binding "the rest to 9936's defaults" would
set the joint 13213 sleeve's cancel hour to **13**, not 18 — a fidelity error. The USDJPY
replay would catch it, but the recipe as written is wrong and the "line-for-line identical"
premise is inaccurate (the exit/cancel *structure* differs, not just parameter values).
**Severity: MEDIUM (recipe defect; replay covers).**

### M3 — Per-tick equity sampler cost is not in the recon's budget
The recon's ~1.5–3 h estimate (`…_mt5_multisymbol_tester_recon.md §4`) is measured on EAs that
do **not** scan all positions every tick. The proposed sampler adds, on **every host tick**
(~10^9 USDJPY ticks over 9 yr), an unconditional `PositionsTotal()` scan to sum floating P&L by
magic plus an `ACCOUNT_EQUITY` read and comparison (§7). That the joint run completes within the
claimed wall-clock **with** the sampler is **NOT ESTABLISHED**; it is plausibly slower.
**Severity: MEDIUM** (task #3 — history/cost).

### M4 — Registering 20180 as an active basket EA makes it pipeline-routable
The design's own RAM-guard mitigation (§8.4) requires shipping `basket_manifest.json` and
registering in `multisymbol_eas.txt` — but those are exactly the markers `farmctl` uses to
recognise and route a **basket work item** (`farmctl.py:4953-4999, 5135-5160`, per the machinery
recon §2). With ea_id 20180 `active` in `ea_id_registry.csv`, nothing structural stops the
router from enqueuing it through Q02+ (consuming factory slots and producing a bogus
3-strategy "sleeve"). The backtest-only guarantee rests on **discipline** ("must not be
enqueued", §8.1), not a guard. **Severity: MEDIUM** (task #5 — factory reach). Mitigation: a
hard non-pipeline marker, or do not register it as a normal active EA.

---

## LOW / accuracy

### L1 — §8.1 tick-timing claim is internally contradictory
§8.1 states the sleeves "do NOT share a tick" while its own parenthetical says "both breakouts
at 06:00 GMT+3." Both USDJPY sleeves fire at range_end hour 6 on the **same** host bar/tick, so
they **do** share the 06:00 host tick. Moot at stress=0 (the block is skipped,
`QM_BasketOrder.mqh:211`), but it shows the design's tick-timing model is unreliable — the same
model error that underlies C1/C4. **Severity: LOW.**

### L2 — `prop_phase=OFF` / `RISK_PERCENT=0` are set-file values, not compile-time constants
The backtest-only guarantee (§10) is enforced by set-file content, not by the binary. A
set-file edit or a stray `gen_setfile -Env demo` (which memory `ftmo_multi_account_campaign`
warns against for these EAs) could flip `prop_phase` or add `RISK_PERCENT`. RISK_FIXED default
and no shipped live set make this low-probability, but it is not structurally impossible.
**Severity: LOW.**

---

## What SURVIVES

1. **Magic/registry model.** `ea_id 20180` is free (registry max 20179; `grep -c "^20180,"` = 0
   in both registries). Rows `201800000/1/2` collide with nothing (distinct ea_id); the
   collision guard only rejects the *same* magic on a *different* symbol
   (`QM_MagicResolver.mqh:99-143`). **No ea_id or magic collision.** SURVIVES.
2. **Trade-stream capture in basket mode.** `QM_FrameworkQ08EmitFromHistory` decides ownership
   on the **opening** deal (`QM_Common.mqh:898-910`) and writes one host-keyed FILE_COMMON file
   with each line tagged by its per-sleeve magic (`:940-942,965-968`). With
   `QM_SymbolGuardInit({USDJPY,XAUUSD})` (basket mode, `QM_SymbolGuard.mqh:65`), the XAUUSD
   sleeve's trades **are** owned and captured (`QM_FrameworkOwnsMagicSymbol` basket branch,
   `QM_Common.mqh:414-431`). §5 is correct; basket-mode is correctly identified as the
   prerequisite. SURVIVES (as a mechanism — the *content* is still C1-distorted for XAUUSD).
3. **RISK_FIXED linearity / post-hoc re-leverage arithmetic.** FIXED mode uses the frozen money
   cap, not the percent rail; the 1% `qm_risk_cap_pct` does not bite FIXED
   (`QM_RiskSizer.mqh:108-110,163-168`). Per-trade $ risk is equity-independent, so joint
   balance is linear in each sleeve's `RISK_FIXED` up to lot quantization (disclosed, §6). §6
   arithmetic SURVIVES.
4. **File I/O in the tester.** FILE_COMMON writes survive the sandbox and are deterministic under
   Model 4 — proven by the existing `q08_trades` streams and the persistent-handle truncate-once
   pattern (`QM_Common.mqh:952-978`). The equity file *would be written*; it is the **sampling
   completeness** that fails (C4), not the write. SURVIVES.
5. **History & cost baseline.** USDJPY.DWX and XAUUSD.DWX have full tick coverage over the window
   and need no re-import, so the `CustomTicksReplace` OFF/ON trap is not triggered (recon §2,
   §6.3). SURVIVES (subject to M3 on the added per-tick cost).
6. **Record-not-enforce.** Emitting limits rather than acting on them (`prop_phase=OFF`) is the
   right call for a measurement instrument; enforcement would truncate the path being measured
   (§7). SURVIVES.
7. **The USDJPY-only instrument.** For 9936 + 13213 with host = USDJPY, both sleeves are
   host-symbol, singleton replay is a *valid* control (same tick environment in replay and joint
   run), and C1/C2/C4's cross-symbol cadence problem does not arise. A USDJPY-only joint run
   faithfully closes the intraday-interleaving gap and yields a real 2-sleeve account equity
   path. SURVIVES and is worth building.

---

## Bottom line for OWNER

- **Build the USDJPY-only joint EA** (9936 + 13213, host USDJPY, RISK_FIXED, `prop_phase=OFF`,
  backtest-only). It survives every attack, closes the intraday-interleaving gap for the two
  sleeves that carry the campaign, and produces a genuine single-account equity path with real
  tick ordering.
- **Do not add 10848 (or any XAUUSD sleeve) to a USDJPY-hosted joint run** expecting a faithful
  gold sleeve, a trustworthy cross-asset correlation, or a complete intraday-low series. A
  per-tick-managed foreign-symbol sleeve driven off the host's tick stream measures a different
  strategy (C1), cannot be validated by the design's replay control (C2), and biases the −5%
  daily read optimistically (C4). If the cross-asset number is genuinely needed, it must come
  from a **separate XAUUSD-hosted run**, and the two runs' correlation is then an inference
  across runs — the very thing the joint EA was meant to avoid — with a wide, one-path CI.
- **Do not re-point 9936/13213 at a shared include** (H2); copy the logic instead.
- The three cited gaps resolve as: **intraday interleaving — closed** (USDJPY-only);
  **equity gap — closed for USDJPY, NOT for the gold contribution** (C4); **correlation —
  NOT delivered faithfully by the joint run** (C1/H1).

**Evidence:** all `file:line` anchors above, verified in branch `agents/board-advisor`
(`C:\QM\repo`). No terminal was launched, no factory slot touched, nothing under `T_Live`
read or modified.
