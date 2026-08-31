# WTI Monthly Exact-Permutation Robust Scale Trend - Source Approval

Date: 2026-08-31

Decision: `APPROVED_SOURCE` for one bounded WTI structural-trend Strategy
Card, deterministic EA-ID and one-slot magic allocation, one branch-only
non-live build, strict Q01 validation, and one paced Q02 enqueue only while
the governed whole-host CPU ceiling remains clear. This decision does not
authorize a manual tester run.

Authority: the current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`. The mission requires one new structural,
low-frequency commodity/energy sleeve outside the certified
XAU/SP500/NDX/XNG carrier set, reputable-source criteria, a `RISK_FIXED`
backtest preset, committed non-duplicate work, and one paced Q02 handoff. It
forbids live, AutoTrading, portfolio-gate, and `T_Live` manifest mutations.

## Candidate identity

- proposed slug: `wti-mperm-scale-tr`
- proposed strategy ID: `AI-CODEX-WTI-MPERMSCALE-20260831_S01`
- source ID: `AI-CODEX-WTI-MPERMSCALE-20260831`
- host / slot 0: exact `XTIUSD.DWX`, D1
- clock: first executable D1 tick after a genuine broker-month transition
- signal: fixed older/recent blocks of six adjacent monthly WTI log returns,
  robust MAD scale expansion, all 924 fixed-size label assignments, and the
  actual recent-block mean direction
- lifecycle: one consumed monthly attempt, one fixed-risk position, frozen
  ATR stop, next-month renewal, and forty-calendar-day stale repair

The deterministic registry process owns the EA ID. This source decision
neither reserves nor predicts an ID.

## Single governed source and supporting evidence

The single R1 lineage is the AI-originated governed packet
`strategy-seeds/sources/AI-CODEX-WTI-MPERMSCALE-20260831/source.md`. The
canonical R1 rule in `processes/qb_reputable_source_criteria.md` expressly
permits an AI-originated strategy when its prompt/output trail, claim
boundary, and one source ID are durable.

The packet was synthesized only after reading the complete governed WTI
source `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.
That packet records a complete 23-page read of Moskowitz, Ooi, and Pedersen
(2012), *Time Series Momentum*, *Journal of Financial Economics* 104(2),
228-250, DOI `10.1016/j.jfineco.2011.11.003`, including explicit NYMEX WTI
membership and monthly own-return continuation findings.

The complete read supports the WTI carrier, monthly cadence, and continuation
direction only. The two fixed six-return blocks, median absolute deviations,
all 924 label assignments, inclusive upper-tail count, `416` cap, risk, stop,
and lifecycle are disclosed pre-result QM choices. The reproducible local
read record is
`strategy-seeds/sources/AI-CODEX-WTI-MPERMSCALE-20260831/retrieval_route_20260831.json`.

## Locked mechanic

At the first executable D1 tick of each genuine broker month:

1. Persist the normalized broker-month key before history, signal, news,
   spread, quote, stop, sizing, margin, or order checks. Never retry the same
   month.
2. Reconstruct thirteen consecutive completed WTI broker-month end closes,
   oldest to newest, and form twelve adjacent log returns `r[0..11]`.
3. Fix `old=r[0..5]` and `recent=r[6..11]`. For each block, use the average of
   sorted values three and four as the median, then use the same even-sample
   median on absolute deviations to obtain the block MAD.
4. Require `observed = MAD_recent - MAD_old > 1e-12`.
5. Enumerate all `C(12,6)=924` masks with six selected returns as
   pseudo-recent and the complement as pseudo-old. Recompute each block MAD
   and count, with `1e-14` comparison tolerance, every
   `perm_delta >= observed`.
6. Qualify only when the inclusive upper-tail count is at most `416`. Buy
   only when the actual recent-block arithmetic mean exceeds `1e-12`; sell
   only when it is below `-1e-12`; zero consumes the month flat. The score
   never scales risk.
7. Open at most one exact-WTI slot-0 position with `RISK_FIXED=1000`,
   `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen
   `3.5 * ATR(20,D1)` broker hard stop, no target, and a 1,500-point spread
   ceiling.
8. Close at the next genuine broker month or after forty calendar days.
   Both news axes and Friday close remain off so the month hold is not
   rewritten into weekly packages.

This is a deterministic exact-enumeration trading score, not a randomized
procedure or a statistical-significance claim.

## Reputable-source criteria

- R1 `PASS_WITH_AI_SYNTHESIS_BOUNDARY`: exactly one durable AI-originated
  source ID and a complete-read peer-reviewed WTI trading packet are
  preserved; the exact robust-scale trading conjunction is clearly bounded.
- R2 `PASS`: month clock, endpoints, return orientation, fixed samples,
  median/MAD arithmetic, complete assignment set, tolerance, tail cap, side,
  attempt, risk, hard stop, spread, and exits are deterministic and locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 history and MT5 execution state supply every runtime input.
  Futures-to-CFD, roll, financing, gap, and broker-month-label risks remain.
- R4 `PASS`: timestamps, completed prices, logarithms, finite sorts,
  medians, deviations, enumeration, comparisons, ATR risk control, and native
  position/deal state only; no ML, trained output, banned signal indicator,
  external runtime feed, grid, martingale, scale-in, or pyramid.

## Non-duplicate decision

The corrected-root canonical receipt
`artifacts/qm5_wti_mperm_scale_tr_preallocation_dedup_20260831.json`,
SHA-256 `133C36BA2F3B6CA20F658794A67CAD7A5277B8A454903A3C52F1D545D7928D4D`,
scanned 4,749 registry identities, 1,387 card files, and 45 Strategy Wiki
nodes. It found no exact identity and one expected fuzzy neighbor,
`QM5_41249`, at score `0.53`.

Manual mechanic review fixes the semantic boundary:

- `QM5_41249_wti-mwelch-shift-tr` qualifies on a parametric-style
  standardized difference between the old and recent arithmetic means. This
  candidate qualifies on a robust dispersion expansion and its exact
  924-assignment label distribution; old/recent mean difference is not a
  qualification input.
- `QM5_20298_wti-vov-regime` estimates nested rolling-daily realized VoV in
  two 252-sample blocks and trades a low-minus-high uncertainty premium. This
  candidate uses twelve monthly returns and follows an upper-tail scale
  expansion.
- `QM5_41108_wti-mrange-expansion-mom` compares two monthly OHLC high-low
  widths and follows a candle body. This candidate has no monthly OHLC range
  or body state.
- `QM5_20288_wti-volnorm-mom` normalizes each historical monthly return by
  its own daily L2 path. This candidate neither normalizes returns nor
  aggregates twelve normalized signs.
- certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback, not a symmetric monthly direct-WTI volatility-regime
  continuation rule.

Verdict:
`DISTINCT_WTI_MONTHLY_FIXED_SIX_BY_SIX_EXACT_924_LABEL_PERMUTATION_ROBUST_SCALE_EXPANSION_RECENT_MEAN_CONTINUATION`.

## Kill and safety boundary

The fixed tail boundary admits at most twelve entries/year and has a
pre-result assignment-density prior of `416/924`, approximately 45.02%; five
to six completed positions/year is a design prior, not test evidence. Q02
retires the unchanged baseline on zero positions, fewer than five positions
in any full scored post-warm-up year, nonpositive governed economics, future
leakage, wrong return orientation, wrong median or MAD, missing assignments,
wrong tail comparison, boundary or direction error, missing stop, invalid
risk mode, malformed lifecycle, or nondeterminism. Failure may not be rescued
by changing the block, scale statistic, tail cap, side rule, stop, or hold.

WTI supplies physical crude-oil exposure absent from the certified book, but
this approval does not assert realized independence. Q09 alone may evaluate
portfolio overlap.

This approval excludes a manual backtest; live, demo, shadow, stress, and
optimization presets; terminal control; AutoTrading; `T_Live`; deploy or
T_Live manifests; portfolio-gate changes; portfolio admission;
decorrelation claims; and correlation waivers.
