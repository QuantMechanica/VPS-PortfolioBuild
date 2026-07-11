# FUERTES-MOMIVOL-2015 — Source Packet

## Approval

- Approval basis: OWNER mission directive dated 2026-07-10 to card and build one
  new structural commodity/energy sleeve for Q02.
- Reopen basis: OWNER commodity/energy sleeve mission dated 2026-07-11 approved
  extraction and build of one additional non-duplicate structural edge.
- Extraction scope: the momentum plus idiosyncratic-volatility double screen
  (`S01`) and the source's standalone idiosyncratic-volatility strategy (`S02`).
  The term-structure leg remains excluded because the Darwinex `.DWX` runtime
  does not expose a futures curve.
- Source review: complete open accepted manuscript, including tables and
  appendices, reviewed on 2026-07-10 and read again end-to-end for the bounded
  `S02` extraction on 2026-07-11.

## Primary Citation

Fuertes, Ana-Maria; Miffre, Joelle; and Fernandez-Perez, Adrian (2015),
"Commodity Strategies Based on Momentum, Term Structure and Idiosyncratic
Volatility," *Journal of Futures Markets* 35(3), 274-297.
DOI: https://doi.org/10.1002/fut.21656.

Open accepted manuscript:
https://openaccess.city.ac.uk/id/eprint/6418/1/JFM_SSRN_13Jan2014.pdf

## Relevant Source Locations

- pp. 6-10: rolling OLS residual standard deviation as the IVol signal; ranking
  windows of 1, 3, 6, and 12 months; equal-weight commodity factor alternative;
  monthly portfolio formation and one-month hold.
- pp. 13-19: combined-score construction and the double-screen robustness test.
- Table 7, p. 34: momentum-IVol double-screen results; the 3-month version has
  the strongest reported mean and risk-adjusted result in that pair.
- p. 16: sensitivity test allowing one top and one bottom commodity rather than
  diversified quintiles.
- Table 6, p. 33: long-short commodity portfolios have low contemporaneous
  equity correlation in the source sample. This is context, not a QM portfolio
  claim.
- Appendix A, p. 40: crude oil frequently entered the source long book and
  natural gas frequently entered the short book; this does not fix the QM
  direction, which remains data-ranked every month.

## Bounded Mechanization

The source ranks a broad futures cross-section. QM has four native commodity
proxies with suitable D1 history: XTIUSD.DWX, XNGUSD.DWX, XAUUSD.DWX, and
XAGUSD.DWX. The EA uses their equal-weight daily return as the common commodity
factor, estimates rolling OLS residual volatility separately for XTI and XNG,
and trades a two-leg energy package only when the relative-momentum and IVol
rankings agree. XAU and XAG are read-only factor members.

This is a falsifiable two-energy carrier, not a replication of the paper's
27-contract portfolio. It imports no source performance threshold.

### S02 — Pure Energy Idiosyncratic Volatility

The paper separately defines an individual IVol strategy: estimate rolling OLS
residual volatility against a traditional commodity benchmark, buy the lowest-
IVol cross-section, sell the highest-IVol cross-section, and rebalance monthly.
Tables 1-3 report that standalone rule independently of momentum and term
structure. The source tests 1-, 3-, 6-, and 12-month formation windows; the
12-month S&P-GSCI specification has the strongest reported standalone mean and
Sharpe ratio among those four baselines. The equal-weight commodity benchmark
is also an explicitly tested traditional-factor alternative.

`QM5_13133_energy-ivol` narrows that rule to a two-leg XTI/XNG carrier. It uses
252 completed D1 returns, regresses each energy leg on the equal-weight return
of XTI, XNG, XAU, and XAG, buys the lower residual-volatility energy leg, and
shorts the higher residual-volatility leg for one broker month. XAU and XAG are
read-only factor members. The paired CFD order is sized toward equal dollar
notional after ATR-risk translation; a post-rounding mismatch guard rejects a
materially directional package.

This rule is not `QM5_13113_energy-mom-ivol`: that EA uses a 63-D1 double screen
and stays flat unless the momentum and IVol rankings agree. `S02` has no
momentum input or agreement gate. It is also not total-volatility selection,
ratio/spread reversion, BAB, skew, kurtosis, MAX, carry, trend, calendar logic,
or `QM5_12567` cumulative RSI2.

No source return, Sharpe ratio, constituent frequency, futures-roll behavior,
or correlation statistic is imported as a QM expectation. Q02 must falsify the
two-CFD carrier and Q09 alone may establish realized portfolio orthogonality.
