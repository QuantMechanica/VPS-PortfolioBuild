# QM5_41178 XTI/XNG Monthly Mann-Whitney Location-Shift Reversion - G0 Decision

Date: 2026-08-27

Verdict: `APPROVED` at G0 for one non-live V5 build, strict Q01 validation,
and one paced logical-basket Q02 enqueue under the active factory resource
ceiling.

Authority: the current explicit OWNER commodity/energy portfolio mission on
`agents/board-advisor`, bounded by the durable source approval at
`decisions/2026-08-27_xtixng_monthly_mann_whitney_location_shift_reversion_source_approval.md`.
The mission asks for one genuinely new structural, low-frequency commodity
sleeve, requires reputable sources and `RISK_FIXED` backtests, and forbids
live and portfolio-gate mutations.

## Approved Identity

- EA: `QM5_41178`
- slug: `xtixng-mwilcoxon-rv`
- strategy ID: `VILLAR-MANNWHITNEY-XTIXNG-MSHIFT-RV-2026_S01`
- source ID: `VILLAR-MANNWHITNEY-XTIXNG-MSHIFT-RV-2026`
- slot 0: `XTIUSD.DWX`, D1, intended magic `411780000`
- slot 1: `XNGUSD.DWX`, D1, intended magic `411780001`
- canonical card:
  `strategy-seeds/cards/approved/QM5_41178_xtixng-mwilcoxon-rv_card.md`

The ID was not inferred or hand-written into the registry. The atomic command
`python tools/strategy_farm/farmctl.py reserve-ea-ids --slug
xtixng-mwilcoxon-rv --strategy-id
VILLAR-MANNWHITNEY-XTIXNG-MSHIFT-RV-2026_S01 --owner
"Research+Development (OWNER commodity/energy portfolio mission 2026-08-27)"
--created-at 2026-08-27 --start-after 41177` returned `reserved:true`,
`count:1`, and EA ID `41178`. Magic allocation remains a separate
deterministic build preflight after the EA directory exists.

## Source And Extraction Gate

Source approval commit: `74c7b7f41`.

The source of record is
`strategy-seeds/sources/VILLAR-MANNWHITNEY-XTIXNG-MSHIFT-RV-2026/source.md`,
SHA-256 `60522B7713DA763799783D2B5C8289A8A3E156C6CDA3C2BE5DC529D315097BCE`.
It joins one bounded lineage from:

- complete government and peer-reviewed oil/gas relationship evidence with
  explicit adverse findings; and
- Mann and Whitney's named peer-reviewed method record plus complete pinned R
  Core `stats::wilcox.test` source and manual defining the operative rank-sum
  and favorable-pair-count identity.

The original 1947 article body is not represented as completely read. The
exact twelve-endpoint sample, fixed six/six split, thresholds, contrarian
direction, continuous CFDs, fixed risk, atomic execution, attempt state, and
lifecycle are disclosed QM mechanizations. No source performance,
significance, profitability, CFD equivalence, independence, neutrality, or
decorrelation claim transfers.

Both `skill_card_schema_lint.py` and `skill_g0_card_lint.py` must return
`status: ok` before build.

## G0 R1-R4 Decision

- R1 `PASS_WITH_RELATION_METHOD_AND_CARRIER_TRANSLATION_RISK`: complete
  government and peer-reviewed oil/gas evidence with adverse findings, a
  named original Mann-Whitney record, and complete pinned R Core method files.
- R2 `PASS`: twelve synchronized completed month ends, fixed block
  membership, strict tie rejection, all 36 pair comparisons, complementary
  and rank-sum invariants, inclusive boundaries, contrarian sides, consumed
  month, aggregate fixed risk, hard stops, atomicity, renewal, and stale
  repair are deterministic.
- R3 `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered
  `XTIUSD.DWX` and `XNGUSD.DWX` D1 histories plus MT5 state supply every
  runtime input.
- R4 `PASS`: logarithms, comparisons, integer arithmetic, calendar, ATR risk,
  and execution state only; no trained signal, prohibited runtime feed,
  adaptive PnL parameter, grid, martingale, scale-in, or pyramid.

## Locked Baseline

At the first synchronized executable D1 tick of a genuine new broker month,
consume the month before any fallible gate. Reconstruct the latest exactly
timestamp-matched XTI/XNG close pair in each of the immediately prior twelve
consecutive completed broker months, oldest to newest, excluding the current
month. Require an immediately prior-month endpoint, positive finite closes,
finite pairwise-distinct log ratios, strict chronology, and no newest endpoint
more than ten calendar days stale.

Fix `O=s[0..5]` and `N=s[6..11]` for
`s=ln(XTI close)-ln(XNG close)`. Count
`U_new=count(N[j]>O[i])` over all 36 cross-block pairs, independently prove
`U_new+U_old=36`, and prove `W_new-21=U_new` from strict combined ranks. SELL
XTI/BUY XNG at `U_new>=24`, BUY XTI/SELL XNG at `U_new<=12`, and otherwise
consume the month flat. No p-value, average-rank tie handling, variable split,
maximum search, endpoint fallback, fitted center, or fitted scale is allowed.

Open one equal-target-absolute-notional two-leg package with aggregate
`RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, frozen
`3.5*ATR(20,D1)` hard stops, no targets, 1,500/3,000-point entry-spread caps,
and at most 20% notional mismatch. Exit at the next broker-month boundary or
after forty calendar days. Both news axes, legacy news mode, and Friday close
are OFF. No retry occurs in the consumed month. Q02 must prove at least four
completed packages in every full post-warm-up year.

## Non-Duplicate Decision

The pre-allocation checker scanned 4,677 registry rows, 1,328 cards, and 45
Strategy Wiki nodes. It found no exact match and returned two fuzzy neighbors
for manual Research/QB review. Receipt:
`artifacts/qm5_xtixng_mwilcoxon_rv_preallocation_dedup_20260827.json`,
SHA-256
`F675A8FA910297733C86749A823355560FE9DBB9E858D7D7C5B5D1BC8B00911B`.

The fuzzy review separates the candidate from:

- `QM5_41177`, which fades the same fixed-block statistic on a gold/silver
  ratio under precious-metal relationship evidence; this candidate trades
  the weak, time-varying oil/gas relationship and energy execution risks;
- `QM5_41175`, which uses the same XTI/XNG carrier but searches all split
  points on thirteen ranks for one central Pettitt maximum; this candidate
  fixes one split on twelve ratios and never searches or maximizes;
- `QM5_20237`, which fits a 252-D1 trend-augmented OLS residual and z-score;
- fixed-ratio, return-spread, channel, carry, calendar, volatility, and
  directional energy families; and
- certified `QM5_12567`, a short-horizon long-only XNG oscillator pullback.

Fixed paths in the source packet prove Mann-Whitney/Pettitt flat and direction
disagreements. Verdict:
`CLEAN_AFTER_DECLARED_FUZZY_REVIEW_XTIXNG_FIXED_SIX_BY_SIX_MANN_WHITNEY_U24_RATIO_REVERSION`.

## Kill And Authorization Boundary

Q02 retires the candidate at zero trades, below four completed packages in
any full post-warm-up year, with nonpositive governed economics, or on any
timestamp, month, split, tie, pair-count, rank-sum, threshold, side, attempt,
risk, atomicity, lifecycle, or determinism defect. No failed result may be
rescued by changing the sample, split, boundary, direction, carrier, risk,
stop, hold, or by adding another gate.

The paired carrier is structurally different from the stated directional
XAU/SP500/NDX/XNG book but does not prove low or negative realized
correlation. Q09 alone owns the overlap verdict. Q02 may be enqueued exactly
once only after a current strict compile/Q01 PASS and independent review PASS.
If the backtest CPU ceiling is binding, stop without tester dispatch or
terminal control and preserve the committed build state.

This decision does not authorize a manual backtest; live, demo, shadow,
stress, or optimization setfile; AutoTrading; `T_Live`; deploy or live
manifest; portfolio-gate change; portfolio admission; correlation waiver;
terminal control; or a second Q02 row.
