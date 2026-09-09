# QM5_41280 independent build review

- Recorded: 2026-09-09
- Branch: `agents/board-advisor`
- EA: `QM5_41280_usdchf-ww-shift-tr`
- Build task: `317b4d6a-3338-4603-8006-a4660ad6d5f1`
- Governed compile work item: `ab67b01f-07e9-4133-8fce-0ebf43d8336f`
- Review verdict: `APPROVE_FOR_BACKTEST`

## Scope and authority

This is a read-only review of the already-built USDCHF fallback sleeve. The
66-pair FX cointegration frontier is already fully mechanized, and the two
strict anchors `QM5_12532` and `QM5_12533` are past Q02. The current OWNER
decision in
`decisions/2026-09-02_qm5_41280_usdchf_weekly_mann_whitney_shift_trend_g0.md`
authorizes this existing structural, low-frequency forex build and one paced
Q02 handoff after compile and review PASS.

No source, binary, setfile, registry, portfolio, terminal, or live artifact was
changed by this review.

## Identity and build evidence

- Approved card:
  `strategy-seeds/cards/approved/QM5_41280_usdchf-ww-shift-tr_card.md`.
- Registry identity: `41280,usdchf-ww-shift-tr`, active.
- Active magic row: slot 0, `USDCHF.DWX`, magic `412800000`.
- MQ5 SHA-256:
  `75fd627e5961fe144429bfc61162bbd2f724bbbd3fb23d21d894abcdfca7523c`.
- EX5 SHA-256:
  `05963c77914ebe36c7c68a0bfa27420a91dea1f7f83fa18e7bc6d543fafd7fe6`.
- The current MQ5 and EX5 hashes match the governed compile evidence at
  `D:/QM/reports/work_items/ab67b01f-07e9-4133-8fce-0ebf43d8336f/QM5_41280/COMPILE_EA/compile_evidence.json`.
- That compile evidence records compile `PASS`, build check `PASS`, zero errors,
  zero warnings, and one canonical setfile.
- The MQ5, EX5, and canonical setfile are tracked and clean at HEAD.

An ad-hoc `build_check.ps1 -SkipCompile` attempt was correctly refused while
factory tester processes were alive. No retry or manual compile was attempted;
the review relies on the current hash-bound governed compile evidence.

## Card-to-code review

The implementation matches the approved execution contract:

- `Strategy_PrepareWeeklySignal` uses the sanctioned framework W1 key, consumes
  the current week before history/signal/news/execution gates, and rejects a
  late or non-genuine transition.
- `Strategy_LoadCompletedCloses` reads exactly shifts 12 through 1 from D1,
  orders them oldest to newest, excludes shift 0, and rejects invalid,
  duplicate-time, or tied-close samples.
- `Strategy_MannWhitneySignal` splits six old and six new closes, evaluates all
  36 strict cross-block comparisons, proves `U_new + U_old == 36`, proves the
  combined-rank identity, buys at inclusive `U_new >= 24`, sells at inclusive
  `U_new <= 12`, and remains flat centrally.
- `Strategy_EntrySignal` opens at most one USDCHF position with a normalized
  frozen `3.0 * ATR(20,D1)` hard stop and no target.
- `Strategy_ManageOpenPosition` closes malformed exposure and enforces the
  seven-calendar-day stale repair; framework Friday close remains first in the
  normal exit path.
- No trained signal, prohibited indicator, external runtime feed, grid,
  martingale, averaging, scale-in, pyramid, target, trail, partial close, or
  post-result rescue is present.

## Binding PACER guard

The exact required audit command was run against the canonical source before
any Q02 action:

```text
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source C:/QM/repo/framework/EAs/QM5_41280_usdchf-ww-shift-tr/QM5_41280_usdchf-ww-shift-tr.mq5
predicate=EA_FRAMEWORK_INPUT_PINNED
ok=true
hit_count=0
```

The locked guard compares only strategy inputs, `qm_ea_id`,
`qm_magic_slot_offset`, and fixed backtest risk. It does not compare the RNG,
news, or Friday-close inputs. Stress rejection is checked only for finiteness
and inclusive range 0..1.

## Verification

- Strategy-card schema lint: `ok`, no missing sections or ML hits.
- G0 card lint: `ok`, no missing sections.
- Deterministic reference suite: `7 passed`.
- Build-review prescreen: one REVIEW build, one clean, zero flagged.
- `validate_build_guardrails.py` on the EA directory: `PASS`, zero findings.
- Canonical setfile: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`; all eleven strategy values match the approved locked
  defaults.

## Disposition

`APPROVE_FOR_BACKTEST`. Close the recovered build review, re-run the canonical
`intake-first-q02` dry-run under the database lock, and append at most one
paced USDCHF Q02 canary only while the whole-host CPU sample remains below the
97 percent ceiling. Do not launch a tester manually.

No portfolio gate, portfolio admission, KPI, Q08 contribution, deploy/live
manifest, `T_Live`, AutoTrading, demo, shadow, or live state is authorized.
