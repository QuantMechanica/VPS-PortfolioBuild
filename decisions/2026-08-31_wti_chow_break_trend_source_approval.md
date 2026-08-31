# WTI Scanned Two-Regression Structural-Break Trend - Source Approval

Date: 2026-08-31

Decision: `APPROVED_SOURCE` for one bounded direct-WTI structural-trend
Strategy Card, deterministic EA-ID and one-slot magic allocation, one
branch-only non-live build, strict Q01 validation, and one paced Q02 enqueue
only while the governed whole-host CPU ceiling remains clear. This decision
does not authorize a manual tester run.

Authority: the current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`. The mission requests one new structural,
low-frequency commodity/energy sleeve outside the certified
XAU/SP500/NDX/XNG carrier set, lists direct WTI as an eligible route, requires
reputable-source criteria and a `RISK_FIXED` backtest preset, and forbids live,
AutoTrading, portfolio-gate, and `T_Live` manifest mutations.

## Candidate identity

- proposed slug: `wti-chow-break-tr`
- proposed strategy ID: `AI-CODEX-WTI-CHOWBREAK-20260831_S01`
- source ID: `AI-CODEX-WTI-CHOWBREAK-20260831`
- host / slot 0: exact `XTIUSD.DWX`, D1
- clock: first executable D1 tick after a genuine broker-month transition
- signal: maximum pooled-versus-two-segment OLS residual-improvement score
  over interior splits of 252 completed D1 log prices, followed by the sign of
  the selected post-break slope
- lifecycle: one consumed monthly attempt, one fixed-risk position, frozen
  ATR stop, next-month renewal, and forty-calendar-day stale repair

The deterministic registry process owns the EA ID. This source decision
neither reserves nor predicts an ID.

## Single governed source and evidence boundary

The single R1 lineage is the AI-originated governed packet
`strategy-seeds/sources/AI-CODEX-WTI-CHOWBREAK-20260831/source.md`.
`processes/qb_reputable_source_criteria.md` expressly permits AI-originated
strategies with a durable prompt/output trail and claim boundary.

The complete governed peer-reviewed WTI packet
`strategy-seeds/sources/MOP-TSMOM-2012/source.md` supports only the carrier,
monthly cadence, and own-return continuation direction. The Chow (1960)
bibliographic record is method context only. Its JSTOR route returned
`DEFERRED:SOURCE_POLICY`, so no inaccessible text, critical value,
significance, or empirical finding is imported.

## Locked mechanic

At the first executable D1 tick of each genuine broker month:

1. Persist the normalized month key before history, signal, news, spread,
   quote, stop, sizing, margin, or order checks. Never retry the same month.
2. Reconstruct 252 chronological completed WTI D1 closes, excluding the
   current bar, and take their finite positive logarithms.
3. Fit one OLS intercept/slope path to all 252 log prices and two separate OLS
   paths for every split `k=63..189`.
4. For each split compute
   `F_k=((RSS0-RSSk)/2)/(RSSk/(252-4))`, with fail-closed finite/degenerate
   guards and a `1e-12` negative-improvement round-off tolerance.
5. Select the largest score; an exact tie selects the most recent split.
   Consume flat below the inclusive activity boundary `3.0`.
6. Buy for a selected recent-segment slope above `1e-12`, sell below
   `-1e-12`, and consume flat otherwise. The scanned score is not a
   significance claim and never scales risk.
7. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen
   `3.5*ATR(20,D1)` broker hard stop, no target, and a 1,500-point spread cap.
8. Close at the next genuine month or after forty calendar days. Both news
   axes and Friday close remain off.

## Reputable-source criteria

- R1 `PASS_WITH_AI_SYNTHESIS_AND_POLICY_BOUNDARY`: one durable source ID,
  prompt/output trail, complete governed peer-reviewed WTI evidence, and an
  explicit deferred-method boundary.
- R2 `PASS`: clock, history, regression arithmetic, split scan, tie,
  threshold, side, attempt, risk, stop, spread, and exits are locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native WTI D1 and MT5
  state supply all runtime inputs; roll/basis/financing/gap risks remain.
- R4 `PASS`: deterministic native arithmetic only; no ML, trained output,
  banned signal indicator, external runtime feed, grid, martingale, scale-in,
  or pyramid.

## Non-duplicate decision

The corrected-root receipt
`artifacts/qm5_wti_chow_break_tr_preallocation_dedup_20260831.json`, SHA-256
`393FEF0D9514EAFB790722F6E9DCA3C249BF89F99E8AF8A6557970C2C03D19D8`,
scanned 4,753 registry identities, 1,391 cards, and 45 Strategy Wiki nodes and
found no exact or fuzzy match.

Manual review separates the candidate from single-path OLS/R-squared
`QM5_20261`, monthly-return mean-CUSUM `QM5_41245`, fixed-block Welch
`QM5_41249`, and daily-return CSS variance-shift `QM5_41252`. The load-bearing
difference is the unknown-location scan of pooled versus two-segment daily
log-price regressions followed by the selected recent slope.

Verdict:
`DISTINCT_WTI_MONTHLY_252_D1_LOG_PRICE_SCANNED_POOLED_VS_TWO_SEGMENT_OLS_RSS_BREAK_POST_SEGMENT_SLOPE_CONTINUATION`.

## Kill and safety boundary

Q02 retires the unchanged baseline on zero positions, fewer than five
completed positions in any full scored post-warm-up year, nonpositive governed
economics, current-bar leakage, wrong OLS or RSS arithmetic, wrong scan/tie
selection, boundary error, wrong post-break side, missing stop, invalid risk
mode, malformed lifecycle, or nondeterminism. No after-result parameter rescue
is authorized.

WTI adds physical crude-oil exposure absent from the certified carrier set,
but this approval makes no independence claim. Q09 alone evaluates overlap.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization presets; terminal control; AutoTrading; `T_Live`; deploy or live
manifests; portfolio-gate changes; portfolio admission; decorrelation claims;
and correlation waivers.
