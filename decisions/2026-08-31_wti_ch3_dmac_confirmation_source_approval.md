# WTI Monthly CH3 / DMAC Confirmation — Source Approval

Date: 2026-08-31

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and one-slot magic allocation, one branch-only non-live build, strict
Q01 validation, and one paced Q02 enqueue only while the governed whole-host
CPU ceiling remains clear. This decision does not authorize a manual tester
run.

Authority: the current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`. The mission requires one genuinely different,
structural, low-frequency commodity exposure outside the certified
XAU/SP500/NDX/XNG book, reputable-source criteria, a `RISK_FIXED` backtest
preset, real non-duplicate work, and one Q02 enqueue. It excludes live and
portfolio-gate work.

## Candidate Identity

- proposed slug: `wti-ch3-dmac-confirm`
- proposed strategy ID: `SZAKMARY-WTI-CH3-DMAC-CONFIRM-2026_S01`
- proposed source ID: `SZAKMARY-WTI-CH3-DMAC-CONFIRM-2026`
- host / slot 0: exact `XTIUSD.DWX`, D1
- decision clock: first executable host D1 tick after a genuine broker-month
  transition
- channel state: the latest completed month-end close is strictly above or
  below all three immediately preceding completed month-end closes
- neutral-band state: the same latest close is above or below the arithmetic
  mean of the latest six completed month ends by strictly more than 2.5%
- participation: enter only when both source-defined states point in the same
  direction; disagreement or either flat state consumes the month flat
- lifecycle: one WTI package for one broker month, with one consumed attempt
  and a 40-calendar-day survivor repair

The deterministic registry process owns the EA ID. This source decision
neither reserves nor predicts an ID.

## Approved Source Basis And Complete-Read Evidence

The following durable repository records were read completely before this
decision:

1. `strategy-seeds/sources/SZAKMARY-WTI-MCH3-2010/source.md`, 110 lines,
   SHA-256
   `9E082864F7F6C85E88720FC7DC24674A8BE77C68C3479D441C7709B726691727`.
   It preserves the complete author-manuscript review for the monthly channel
   family, the final peer-reviewed citation, the explicit source horizons
   `L={3,6,9,12}`, strict extrema, flat-inside state, monthly renewal, WTI
   carrier boundary, and local data/cadence precheck.
2. `strategy-seeds/sources/SZAKMARY-WTI-DMAC16-2010/source.md`, 81 lines,
   SHA-256
   `3F27E3A48EBA504DA98FAD487B8F0DA3135E40D4BC15B19C6156A286E987BCC6`.
   It preserves the same peer-reviewed study's monthly dual-moving-average
   family and the source-selected one-versus-six-month, 2.5% neutral-band
   rule on WTI.

The underlying reputable source is Szakmary, Andrew C.; Shen, Qian; and
Sharma, Subhash C. (2010), "Trend-following trading strategies in commodity
futures: A re-examination," *Journal of Banking & Finance* 34(2), 409-426,
DOI `10.1016/j.jbankfin.2009.08.004`. The governed channel packet records a
complete read of the authors' accessible predecessor manuscript, "Price
Momentum and Trading Volume in Commodity Futures Markets," which supplies
the mechanical monthly rule. The final paper covers 28 commodity futures
over 48 years and tests both monthly channel and dual-moving-average families.

The source supports monthly commodity trend persistence, strict monthly
channel states, neutral-band moving-average states, one-month channel holds,
and crude-oil membership. It does not test this AND conjunction, a
single-WTI result, a Darwinex continuous CFD, the exact endpoint
reconstruction below, fixed-dollar risk, an ATR stop, or portfolio
decorrelation. No source return, Sharpe ratio, drawdown, trade density, cost,
WTI-only alpha, CFD equivalence, correlation, or portfolio result transfers.

## Locked Mechanic

At the first executable `XTIUSD.DWX` D1 tick after broker calendar month
changes from the immediately preceding D1 bar:

1. Close malformed or prior-month owned exposure before entry-only gates.
   Persist the new broker `yyyymm` attempt before history, signal, news,
   spread, quote, ATR, sizing, or submission; never retry that month.
2. Reconstruct exactly six consecutive completed broker-calendar month-end
   closes from bounded D1 history, newest first:

   ```text
   C0 = just-completed month end
   C1 = one month older
   ...
   C5 = five months older
   ```

   Require six distinct consecutive month keys, strictly increasing endpoint
   times in chronological order, a confirming current-month D1 bar, and
   positive finite closes. Missing or invalid history consumes the month
   flat; no shorter sample or substitute month is allowed.
3. Compute both states without current-month leakage:

   ```text
   channel = BUY  when C0 > max(C1,C2,C3)
             SELL when C0 < min(C1,C2,C3)
             FLAT otherwise

   mean6 = (C0+C1+C2+C3+C4+C5) / 6
   dmac  = BUY  when C0 > mean6 * 1.025
           SELL when C0 < mean6 * 0.975
           FLAT otherwise

   signal = BUY  only when channel=BUY  and dmac=BUY
            SELL only when channel=SELL and dmac=SELL
            FLAT otherwise
   ```

   Every inequality is strict. Equality, nonfinite arithmetic, disagreement,
   or either flat state consumes the month flat. Magnitude never changes risk.
4. Apply exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
   `PORTFOLIO_WEIGHT=1`. Attach one frozen `4.0 * ATR(20,D1)` broker hard
   stop, no target, and reject crossed or negative-spread quotes plus a
   genuinely positive spread above 1,500 points.
5. Close at the first later broker-month boundary even when the next signal
   repeats. A forty-day elapsed-calendar guard repairs only a survivor. Close
   duplicate, wrong-symbol, invalid-side, wrong-magic, or stopless owned
   exposure immediately.
6. Lock both current news axes and legacy news mode OFF and disable framework
   Friday flattening because the structural hold spans weekends.
7. Never retry, carry an old package through renewal, scale in, pyramid, grid,
   martingale, optimize, change either parent horizon/band, use intramonth
   prices, add a trend filter, or substitute OR/vote/weighted-combination
   logic.

The six exact completed endpoints, prior-three strict channel, six-close
arithmetic mean, 2.5% band, AND agreement, monthly attempt, fixed risk, frozen
stop, and monthly renewal are load-bearing.

## Reputable-Source Criteria

- R1 `PASS_WITH_UNTESTED_CONJUNCTION_AND_SINGLE_CFD_TRANSLATION_RISK`: one
  named-author, DOI-bearing, peer-reviewed commodity-futures study with a
  durable complete-manuscript review supplies both parent rule families and
  explicit crude-oil membership. The conjunction and CFD port remain
  untested.
- R2 `PASS`: month clock, exact six endpoints, strict channel, arithmetic
  mean, exact 2.5% band, AND agreement, flat states, attempt ledger, risk,
  stop, spread, and exits are locked.
- R3 `PASS_WITH_CONTINUOUS_FUTURES_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 history plus MT5-native broker time, quotes, metadata,
  positions, deals, and terminal state supply every runtime field. History,
  financing, roll, gap, and CFD-basis risks remain.
- R4 `PASS`: timestamps, completed closes, extrema, fixed addition,
  multiplication, division, comparisons, ATR risk controls, and execution
  state only; no trained output, banned signal indicator, external runtime
  feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The corrected-root canonical receipt
`artifacts/qm5_wti_ch3_dmac_confirm_preallocation_dedup_20260831.json`,
SHA-256
`B61748E06968490A41476ED976043288A5C49046244B04EBFF0394B44364DF40`,
scanned 4,740 registry identities, 1,378 cards, and all 45 current Strategy
Wiki nodes. It found no exact or above-threshold fuzzy identity.

Manual parent review establishes a different decision surface:

| newest-to-oldest closes `C0..C5` | CH3 | DMAC | candidate |
|---|---|---|---|
| `[103,100,99,98,120,120]` | BUY | SELL | FLAT |
| `[110,111,109,108,80,80]` | FLAT | BUY | FLAT |
| `[120,110,105,100,95,90]` | BUY | BUY | BUY |
| `[80,90,95,100,105,110]` | SELL | SELL | SELL |

`QM5_20008_wti-month-ch3` trades the first fixture and ignores the second.
`QM5_13100_wti-dmac16` trades both and can carry an unchanged state across
months. This candidate stays flat in both fixtures and renews every accepted
package after one month. Removing either parent or changing AND to OR
recreates a materially different built strategy.

Verdict:
`SEMANTICALLY_DISTINCT_WTI_MONTHLY_CH3_BREAKOUT_AND_DMAC16_NEUTRAL_BAND_CONFIRMATION_SLEEVE`.

## Kill And Safety Boundary

Expected cadence is approximately five to eight completed WTI positions per
full year, derived only from the parent CH3 precheck and the stricter
agreement relation; this is not a performance result. Q02 retires on zero
positions, fewer than five in any full scored year, nonpositive governed
economics, wrong or nonconsecutive month ends, current-month leakage, wrong
channel/mean/band/agreement state, repeated entry, missing stop, wrong
lifecycle, nondeterminism, invalid risk mode, or insufficient history.
Failure may not be rescued by relaxing the conjunction or changing a parent
rule.

The WTI carrier and monthly trend structure target exposure outside the
certified XAU/SP500/NDX/XNG set, but they do not prove low correlation. Only
unchanged Q09 may measure realized portfolio overlap.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization presets; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission;
decorrelation claims; and correlation waivers. Q02 may be enqueued once only
after strict Q01 and only if the governed whole-host CPU check remains clear.
At a ceiling, stop before queue mutation and record a non-live handoff.
