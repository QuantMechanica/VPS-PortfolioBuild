# WTI Same-Calendar Regime-Shift Seasonality - Source Approval

Date: 2026-08-30

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced Q02 enqueue if the active factory remains below its hard CPU
ceiling. This decision does not authorize a manual tester run.

Authority: the current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`. It asks for one new structural, low-frequency
commodity or energy sleeve outside the certified XAU/SP500/NDX/XNG book,
requires reputable-source criteria and fixed-risk backtests, and forbids live
and portfolio-gate work.

## Candidate identity

- proposed slug: `wti-samecal-regimeshift`
- proposed strategy ID:
  `KELOHARJU-MOP-WTI-SAMECAL-REGIMESHIFT-2026_S01`
- proposed source ID: `KELOHARJU-MOP-WTI-SAMECAL-REGIMESHIFT-2026`
- host / intended slot 0: exact `XTIUSD.DWX`, D1
- clock: first executable D1 tick after each genuine normalized broker-month
  transition
- state: the arithmetic means of the exact same calendar month in recent
  years `Y-1..Y-5` and older years `Y-6..Y-10`
- trigger: require both five-year blocks complete and their means to have
  strict opposite signs; follow the recent block for one broker month

The deterministic allocator owns the EA ID. This source decision does not
guess or reserve one.

## Approved source basis and claim boundary

Extraction may use only these governed records, read completely after this
approval becomes durable:

1. `strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md`, SHA-256
   `54E6036035D146BB080A0DDF4A16B378C187655A3834DF86329F7B2D319875F0`,
   covering Keloharju, Linnainmaa, and Nyberg (2016), "Return
   Seasonalities," *The Journal of Finance* 71(4), 1557-1590, DOI
   `10.1111/jofi.12398`. It binds recurring prior-year same-calendar return
   information, explicit crude-oil membership, monthly renewal, and the
   five-year history floor.
2. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
   `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`,
   covering Moskowitz, Ooi, and Pedersen (2012), "Time Series Momentum,"
   *Journal of Financial Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`. It binds WTI membership, own-return
   directional interpretation, and a monthly lifecycle, not the
   same-calendar split or disagreement rule.

Neither paper tests a single-WTI recent-versus-older same-calendar sign
reversal, the five/five split, a Darwinex continuous CFD, fixed-risk sizing,
ATR stops, spread ceilings, or the current portfolio. No source or sibling
return, alpha, significance, profit factor, drawdown, density, transaction
cost, futures/CFD equivalence, decorrelation, or portfolio result transfers.
The two-block regime-shift trigger is a transparent, pre-result QM
falsification choice.

## Locked mechanic

At the first executable `XTIUSD.DWX` D1 tick after a genuine normalized
broker-calendar month transition in `(Y,M)`:

1. Repair owned exposure and persist broker `yyyymm` before every fallible
   entry gate. Never retry that month after any downstream outcome.
2. Under one uniform native or `+1` energy D1-label convention, reconstruct
   the completed WTI log return for calendar month `M` in every exact year
   `Y-1..Y-10`. Require strict adjacent-month endpoints and a confirming
   following bar. All ten years are mandatory; there is no substitution,
   compression, or current-month price.
3. Compute `recent_mean = mean(r_1..r_5)` and
   `older_mean = mean(r_6..r_10)`. Require both finite and outside the
   inclusive `1e-12` tie band.
4. If `recent_mean > +1e-12` and `older_mean < -1e-12`, buy WTI. If
   `recent_mean < -1e-12` and `older_mean > +1e-12`, sell WTI. Equal signs,
   either tie, or invalid state consumes the month flat. Signal magnitude
   never changes risk.
5. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
   Attach one frozen `3.5*ATR(20,D1)` hard stop and no target.
6. Reject crossed quotes, negative modeled spread, or genuinely positive
   spread above 1,500 WTI points.
7. Close at the next genuine normalized broker-month boundary; 40 elapsed
   calendar days is survivor repair only.

Both news axes, legacy news mode, and framework Friday close are OFF. There
is no moving average, oscillator, fixed favorable-month list, sort, rank,
clipping, exponential weight, confidence statistic, current-month input,
curve, inventory, storage, event, volume, optimizer artifact, trained output,
banned signal indicator, or external runtime feed.

## Reputable-source criteria

- R1 `PASS_WITH_TWO_BLOCK_SINGLE_CARRIER_CFD_TRANSLATION_RISK`: complete,
  DOI-bearing peer-reviewed lineages support same-calendar commodity
  information, explicit crude-oil/WTI membership, own-return direction, and
  monthly renewal. The five/five sign-reversal conjunction is untested.
- R2 `PASS`: calendar, normalized endpoints, exact-year membership, complete
  block sizes, arithmetic means, strict disagreement, side, attempt, fixed
  risk, stop, spread, and lifecycle are deterministic and locked before Q02.
- R3 `PASS_WITH_TEN_YEAR_WARMUP_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`:
  registered native WTI D1 history and MT5 state supply every runtime field;
  history depth, labels, rolls, financing, gaps, and CFD basis remain risks.
- R4 `PASS`: timestamps, completed prices, logarithms, finite sums, division,
  comparisons, ATR risk controls, and execution state only; no trained output,
  banned signal indicator, or external runtime feed.

## Non-duplicate decision

The corrected-root canonical checker scanned 4,723 registry identities,
1,361 card files, and all 45 current Strategy Wiki nodes. It found no exact
collision and returned the expected fuzzy raw same-calendar neighbor. Receipt:
`artifacts/qm5_wti_samecal_regimeshift_preallocation_dedup_20260830.json`,
SHA-256
`75457AA3AFF5BF445FCDC11799CA2BC6ABD574DB0486CE6B5BD3E3F1AF3ACF17`.

Manual review fixes the executable boundary:

- `QM5_20099_wti-samecal` follows the full-sample equal mean every month.
  This candidate trades only a sign reversal between exact recent and older
  five-year blocks and follows the recent regime.
- `QM5_41223_wti-samecal-expw4` continuously decays influence by year age and
  follows its weighted mean. This candidate has no decay kernel and abstains
  unless the two fixed blocks disagree.
- `QM5_41211_wti-samecal-tstat` gates an equal-weight magnitude mean by sample
  standard error; `QM5_41212_wti-samecal-signscore` discards magnitudes into
  one full-sample Bernoulli count. Neither compares two chronological blocks.
- `QM5_41172_wti-mpettitt-shift-tr` detects a location change across daily
  observations inside the just-completed month and trades monthly trend. It
  does not compare exact same-calendar returns across ten years.

For recent-to-old exact-year returns
`[+.01,+.01,+.01,+.01,+.01,-.03,-.03,-.03,-.03,-.03]`, the full equal mean
is `-.01` and `QM5_20099` sells, while this candidate detects the strict
block sign reversal and buys. Stable all-positive or all-negative histories
make the existing mean and decay rules trade but force this candidate flat.
The split, disagreement state, and recent-block side are therefore jointly
load bearing. Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_WTI_SAMECAL_CHRONOLOGICAL_REGIME_SHIFT`.

## Kill and safety boundary

Q02 retires the unchanged candidate on zero positions, fewer than five
completed positions in any full post-warm-up year, nonpositive governed
economics, or any label, endpoint, block, mean, sign, side, attempt, fixed-risk,
stop, lifecycle, or determinism defect. A failed result may not be rescued by
changing the years, block sizes, direction, carrier, stop, hold, spread, tie
rule, or adding a fallback.

Direct WTI is a genuinely different carrier from the certified
XAU/SP500/NDX/XNG book, but structural distinction does not prove factor or
portfolio independence. Only unchanged Q09 evidence may judge realized
overlap. This approval excludes manual backtests; live/demo/shadow/stress/
optimization setfiles; terminal control; AutoTrading; `T_Live`; deploy or
live manifests; portfolio-gate changes; portfolio admission; correlation
waivers; and certification claims.
