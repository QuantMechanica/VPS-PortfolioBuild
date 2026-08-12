# Codex brief — independent recommendation: what is the next step for the FTMO campaign?

Date: 2026-07-27
Requested by: Claude, on OWNER's instruction ("Was würde Codex als nächsten Schritt empfehlen?")

## What is being asked

Give **your own independent recommendation** for the single next step of the FTMO
campaign. Claude's recommendation is deliberately withheld from this brief so the
two can be compared without anchoring. If the two disagree, a third model
arbitrates. Do not try to guess or reconstruct Claude's position — argue from the
evidence.

Answer these, in order:

1. **Do we have a defensible FTMO book today?** Yes/No, with the decisive reason.
2. **What is the single next step?** One concrete action, not a programme.
3. **What is the expected payoff of that step**, and what would make it wasted work?
4. **What should explicitly NOT be done next**, and why — including anything in the
   list of open work below that you consider a distraction or negative-value.
5. **Is the FTMO campaign worth continuing at all**, or is the correct call to stop
   and redirect the factory's capacity to sleeve supply / DXZ? Argue the economics,
   not the sunk cost. A recommendation to stop is a fully acceptable answer and
   will not be held against the campaign's authors.

## Established state (all of this is verified; do not re-derive unless you doubt it)

### Measurement history — read this carefully, it is the crux

The campaign pass-rate estimate moved as follows over 2026-07-26/27:

| Estimate | What it actually was |
|---|---|
| "low tens of percent" | wrong metric: `speed = (%/yr)/maxDD` divides by a 15-year max drawdown to answer a 22-trading-day question |
| 80.7% -> 81.1% -> 90.2% | progressively better AND progressively leakier |
| 79.5% | `challenge_defensible.py` (71b6cf87f): restricted to sleeves with <=1% multi-day positions, leverage <=5 |
| **4.7%** | `challenge_as_deployed.py` (796e855ac): `LEVERAGES = (1.0,)`, i.e. the book as the framework would actually run it today |

### The 1% risk cap

- `framework/include/QM/QM_Common.mqh:179` computes `risk_cap_money = ACCOUNT_EQUITY * 0.01`
- `framework/include/QM/QM_Common.mqh:182` calls `QM_RiskSizerSetCapPct(1.0)`
- `framework/include/QM/QM_RiskSizer.mqh:95-115` clamps `weighted_risk` to `cap_global`
- `framework/include/QM/QM_Common.mqh:315` `QM_FrameworkSetRiskCapPct(cap_pct)` rejects
  `cap_pct <= 0 || cap_pct > 5.0` — an OWNER-ratified ceiling of 5.0 (2026-07-05)
- **No campaign EA calls the override.** No set file carries `qm_risk_cap_pct`.
  Three of the four campaign EAs cannot read such an input at all.
- Consequence: the deploy manifest's per-leg 4/4/8/8 risk is fiction. The 8x legs
  are structurally impossible even if wired, because of the 5.0 ceiling.

### Instrument defects found by adversarial review (Codex, 2026-07-26)

- **Multi-day blindness**: `challenge_final.py:110` stores only `(close, net, mae)`.
  `entry_time` is discarded. All six cited stream files lack usable `entry_time` on
  every record (10553: 2615/2615 missing; 10848: 1344/1344; 13036: 1352/1352;
  13108: 553/553; 13213: 1596/1596; 13301: 551/551). A position that breaches the
  daily cap on day 2 and closes profitably on day 23 is invisible to every window
  ending before day 23. The available data therefore permit an actual rate of
  **0/830** while the script reports 748/830.
- **"Touch = pass" is wrong**: FTMO requires the *balance* above target with all
  positions closed, not an intraday equity touch. `challenge_final.py:168` passes on
  the closing event that makes `eq + realized >= target`.
- **4-trading-day minimum** is not enforced.
- **Day boundaries**: FTMO resets at midnight CE(S)T; the script groups by
  `datetime.date()` with no explicit conversion.
- **CI method**: `len(f)//WINDOW` as effective sample size is a heuristic. Measured
  lag-1 autocorrelation 0.648; autocorrelation-based ESS ~104, not 37. A
  dependence-robust *conditional* interval is ~84-96%, but selection/adaptive reuse
  of the same holdout is not accounted for at all.
- **Adaptive holdout reuse**: `MIN_DAYS` was lowered 600 -> 500 specifically to admit
  13301 after it looked decorrelated. `SPLIT = 0.60` and the 22-day horizon are
  hard-coded with no preregistration.

### Pipeline admission status of the campaign sleeves

All six campaign sleeves (10553, 10848, 13036, 13108, 13213, 13301) carry a latest
Q09 verdict of `FAIL_PORTFOLIO`. 13036 and 13301 have since improved to Q08 PASS and
merit a fresh Q09 run (13301 was enqueued 2026-07-27, `fcd46e6fc`). 13036 has no Q03
record at all yet entered the claimed book.

Only two sleeves are `challenge_ready`: 10128 and 10145, both XAUUSD.

### Sleeve supply funnel (authoritative, 6344682e7)

189 Q08 trade streams: 120 gate-rejected, 69 gate-clean, 60 gate-clean but under 500
trading days, **8-9 qualifying**, 16 blocked only by `INFRA_FAIL`. Note the
qualifying count is unstable: 10582 flipped to `INFRA_FAIL` one minute after the
funnel was committed.

Top blockers: Q08 `FAIL_HARD` 84, Q04 `FAIL` 17, Q08 `INFRA_FAIL` 12.

### The equity export gap (your own finding, task a5768d03)

`docs/ops/evidence/a5768d03_equity_export_gap_2026-07-27.md` concludes that the
campaign re-measurement "cannot be produced from the current durable evidence
without inventing intratrade equity", and proposes a bounded tester-only equity
sampler writing `FILE_COMMON/QM/q08_equity/<bare>_<SYMBOL>_DWX.jsonl`, then a clean
full-history re-run of the four EAs.

**Cost note for your recommendation:** that programme means a framework change, a
recompile of the affected EAs, and full-history Q08 re-runs. Estimate the factory
cost in your answer, and say whether the information gained justifies it *given*
that the sleeves it would measure are currently Q09 `FAIL_PORTFOLIO`.

### Your other open finding (task 4458d308)

Of 204 Q08 `INFRA_FAIL` rows, 158 have valid current set files and split into 7
disjoint causes; **only 2 are transient** (`ACTIVE_TIMEOUT`). At least 129/158 are
deterministic. You identified a boundary defect in `tools/strategy_farm/farmctl.py`
that flattens upstream `INVALID` to `INFRA_FAIL`, making deterministic evidence
insufficiency look generically retryable. Sub-gate details: `8.5_neighborhood` 94x
`artifact_missing`, 10x `degenerate_baseline`; `8.7_pbo` 81x
`insufficient_distinct_configs:got=0`.

### Standing OWNER constraints

- FTMO is **parked** by OWNER decision (2026-07-26): no new trial or challenge
  account until results are significantly better. Trial #2 died at -10.0%.
- Target: P(pass Phase 1) >= 0.80 within 30 days.
- The live Darwinex account (T_Live, 4000090541) keeps running and must not be
  disturbed. No reboot, no logoff, no `tscon`.

## Hard constraints on your work

- Do **NOT** run `Factory_OFF` or `Factory_ON`.
- Do **NOT** interrupt active T1-T10 backtests.
- Read-only analysis plus this one evidence document. No repo edits beyond writing
  your artifact, no requeues, no work-item changes.
- Evidence over claims: cite file:line or a query for every factual assertion.
- Do not invent commission, swap, or DST values.

## Deliverable

Write `docs/ops/evidence/2026-07-27_codex_ftmo_next_step_recommendation.md` with the
five answers above. Be decisive: name one next step, not a ranked list of six. If
your honest answer is "stop the campaign", say that plainly and defend it.
