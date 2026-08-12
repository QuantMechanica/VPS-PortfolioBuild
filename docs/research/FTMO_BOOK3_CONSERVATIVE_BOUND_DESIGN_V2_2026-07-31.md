# FTMO Book3 — Conservative-Bound Diagnostic, Design v2 (Claude, 2026-07-31)

Supersedes `FTMO_BOOK3_SEALED_VALIDATION_DESIGN_2026-07-31.md` (v1) after Codex
R1 (62 %, `docs/ops/evidence/2026-07-31_book3_sealed_validation_review.md`).
All seven R1 acceptance conditions are adopted. The central concession is in the
title: **this tool cannot produce a selection-sealed proof on existing history**
— Book3 was rank 17 of 165 published OOS compositions; the holdout has been
seen. What the tool CAN produce is an honest, conservative, fully hash-bound
**diagnostic bound** — and the machinery is reusable for any genuinely
prospective seal later.

## 1. Claim taxonomy (condition 1, 2)

- Every result over existing bytes is stamped
  `HISTORICAL_DIAGNOSTIC_NOT_SELECTION_SEALED`. It can never lift the
  selection-sealed blocker of `strict_qualification`.
- `n_trials: UNKNOWN_LOWER_BOUND_165` (165 composition candidates, 35
  Q09-passing sets, within-set permutations unreconstructed), recorded in every
  verdict artifact.
- A genuinely sealed claim requires **prospective bytes** that did not exist at
  seal time: the exact-profile FTMO Free Trial / shadow route. That is an OWNER
  decision (account currently PARKED to 2026-08-25) and is out of scope here.
- Final status after any diagnostic run remains
  `strict_qualification: UNVERIFIED`, `paid_challenge: NO_GO`.

## 2. Pinned evaluation contract (conditions 3, 4)

- **Streams (provenance contract = per-run evidence set):** the three
  hash-bound per-run streams with 100 % `entry_time`/`time`/`mae_acct`
  coverage — R0 9936/USDJPY 1,143 rows (`1593ee93…`), R1 10145/XAUUSD 291
  (`cba8eac2…`), R2 13108/XTIUSD 548 (`136cc04d…`) — plus their summaries,
  reports, receipts and `evaluation_manifest.json` (`fdd26cc9…`). The Q08
  aggregates (1,252/314/553, different bytes) are explicitly NOT inputs.
- **Window:** start 2022-09-16 (first day after the original composition IS
  end 2022-09-15), end pinned 2025-12-30 (last close in the bound streams).
  Labelled unsealed-historical.
- **Multipliers:** 1.0 per sleeve (the only no-search baseline; the standalone
  manifest pins `base_risk_fixed=1000` each). Phase-2 0.75x is a separately
  labelled policy scenario, evaluated alongside — official raw +10 %/+5 %
  scenario and internal-policy scenario are reported as distinct rows, never
  mixed.
- **Start set & censoring:** starts = simultaneous-account-flat CE(S)T days
  with ≥1 new Book3 position; right-censored = non-pass (gate-conservative,
  matching the existing diagnostic); one start = one book outcome.
- **Thresholds:** report the moving-block-bootstrap CI against 0.80 as a
  *supplemental, unratified* reference line — explicitly NOT a redefinition of
  the earlier Book3 preregistration (phase-1 LB 70 % / joint point 65 %) and
  NOT of Q08/`challenge_ready`. Known power limit is stated up front: even
  under false independence the Wilson LB is 72.73 % — refutation is the
  expected outcome and is a valid result.

## 3. Statistics (condition 3)

- **Primary CI:** moving-block bootstrap of the single merged Book3
  Prague-day/event vector with full two-phase re-evaluation per path. Blocks
  start/end only at all-sleeves-flat boundaries (multi-day positions never cut).
- **Block rule frozen from IS only:** deterministic autocorrelation-length
  candidate over joint realized-PnL and pessimistic-low series (predeclared
  lag rule, max lag, tie handling in the tool's config, committed before any
  holdout read); target length `max(20 CE(S)T days, IS candidate)`; sensitivity
  at half/double length.
- **Dependence reporting (all four):** raw overlapping starts+outcomes; greedy
  non-overlapping start count; Bartlett-weighted HAC ESS
  (`ESS = N / (1 + 2*sum((1-k/(K+1))*rho_k))`, clipped [1,N], K and rho_k
  published, bandwidth frozen from IS); bootstrap CI. `n=102` is never treated
  as independent.

## 4. Trace semantics (condition 6)

Label: **`CONSERVATIVE_LIFETIME_MAE_BOUND`** — a lower bound, not an
event-complete equity reproduction. The exact-event blocker stays open.

- `pessimistic_equity(event) = realized_balance + sum(lifetime-min floating
  PnL of every open position)`; breach requires passing this bound; target
  recognition uses realized close-only balance while flat.
- Close field is `time` (UTC epoch); conversion via `ZoneInfo("Europe/Prague")`
  incl. both DST transitions; half-open lifetime intervals, deterministic
  ordering for equal timestamps; every crossed Prague calendar day represented.
- Daily floor = `midnight_balance − 0.05·initial_capital`; total floor =
  `0.90·initial_capital`; trading-day = position opened; minimum-trading-day
  and phase-transition semantics explicit in config.
- Money basis: rows must carry `money_basis=FULL_POSITION_LIFECYCLE_ACTUAL_V1`
  with finite component reconciliation; entry commission included in the
  pessimistic treatment.

## 5. Costs and margin (condition 5)

- **Cost input:** the hash-bound provider snapshot
  `docs/ops/evidence/2026-07-30_ftmo_book3_symbol_cost_snapshot.json`
  (`7eab3bf8…`) as an explicitly named separate input — labelled
  **fixed-current-terms counterfactual** (one dated swap/commission set applied
  over history, not historical realized swap). `venue_cost_model.json` is
  cited only for what it has (USDJPY flat $5, XTIUSD $0, XAUUSD indicative) and
  its swap gap; nothing is invented; missing fields ⇒ refusal.
- **Replacement arithmetic:** the tool states which stream components are
  removed (.DWX commission/swap already in `net`) and which snapshot components
  are inserted; swap accrual allocated to actual CE(S)T rollover days incl. the
  snapshot's triple day.
- **Margin/leverage:** Swing-profile provider rows (USDJPY 30, XAUUSD 15,
  USOIL.cash 15), full margin inputs (side, volume, entry/mark price, contract
  size, calc mode, conversion) — reported diagnostic, not a pass criterion.

## 6. Purity (condition 7)

`book3_sealed_eval.py` (working name `book3_bound_eval.py`) is a pure function
of (config JSON, bound artifact files). No live `farm_state.sqlite` read enters
the statistical verdict; any DB cross-check is a separately labelled advisory
snapshot artifact bound by hash. Fail-closed refusals: config/stream SHA
mismatch, coverage < 100 %, missing cost fields, window outside stream bounds.

## 7. Workflow

`prepare-config` (IS-only reads; emits pinned config + hashes; committed)
→ Codex R2 review of this design (≥90 %) → implement tool+tests → Claude
implementation review → single diagnostic run → verdict artifact. Any future
prospective seal reuses the same tool with a `prepare-seal` config whose
evaluation window starts after the seal commit — that mode requires OWNER
authorization of the trial/shadow route first.

## Honest expectation

The diagnostic will most likely land below 0.80 at the lower bound. Its value:
(a) converts the 81.37 % headline into an honest bound with dependence-aware
uncertainty, (b) builds the reusable trace/cost machinery any future book needs,
(c) sharpens the sleeve-breeding target (FUND_SCORE) with per-sleeve bound
attribution.
