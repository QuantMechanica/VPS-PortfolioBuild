# FUERTES-MOMIVOL-2015 — Source Packet

## Approval

- Approval basis: OWNER mission directive dated 2026-07-10 to card and build one
  new structural commodity/energy sleeve for Q02.
- Extraction scope: the momentum plus idiosyncratic-volatility double-screen
  strategy only. The term-structure leg is excluded because the Darwinex `.DWX`
  runtime does not expose a futures curve.
- Source review: complete open accepted manuscript, including tables and
  appendices, reviewed on 2026-07-10.

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

