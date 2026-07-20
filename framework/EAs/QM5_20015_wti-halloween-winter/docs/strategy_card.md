# QM5_20015 WTI November-May Winter-Season Sleeve

**Status:** APPROVED under the 2026-07-20 OWNER commodity-sleeve mission  
**Source:** `BURAKOV-WTI-HALLOWEEN-2018`  
**Canonical card:** `strategy-seeds/cards/wti-halloween-winter_card.md`

## Hypothesis and source boundary

Burakov, Freidin and Solovyev (2018), "The Halloween Effect on Energy
Markets: An Empirical Study," use monthly IMF energy prices over 1985-2016.
Their alternative-two West Texas result compares the last October close with
the following last May close. Table 2 reports average winter return `16.65%`
versus summer `-5.3%`, with winter higher in `23/32` years; Table 3 reports
preferred Wilcoxon `p=0.0031`.

The paper's Table 2 repeats the alternative-one month captions, but Section 3
explicitly defines alternative two as October-May and May-October endpoints.
The build follows the methods definition: long November-May and flat
June-October.

## Mechanical carrier

- Host: `XTIUSD.DWX`, D1, magic slot 0.
- On each November-May broker-month boundary, close the old package and open
  one new long package.
- On the June boundary, flatten and remain flat through October.
- Never re-enter after a stop, rejection or restart inside the same month.
- Use completed D1 `ATR(20)` with a frozen `4.0 * ATR` broker stop, no target,
  a 35-day stale guard and a 1500-point spread cap.
- Disable Friday close to preserve the month-spanning source window.
- Backtest only with `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

Monthly close/reopen packaging is a disclosed V5 adaptation of the paper's
single continuous seasonal hold. The paper did not test ATR stops, monthly
renewal, transaction costs, Darwinex CFDs or portfolio correlation.

## Non-duplicate and safety boundary

No existing WTI EA is unconditionally long every November-May month and flat
June-October. `QM5_20008` is a symmetric price channel, `QM5_12726` fades only
November, and `QM5_12813` is an XTI/XNG seasonal basket. Equity Halloween EAs
trade a different asset and source lineage.

Q02 must prove the expected seven packages/year and kill the design below five
completed packages/year or for weak net expectancy. Later gates must measure
realized correlation to the index/metal/XNG book. This card authorizes no live
setfile, T_Live action, AutoTrading, deploy/T_Live manifest, portfolio
admission or portfolio-gate change.
