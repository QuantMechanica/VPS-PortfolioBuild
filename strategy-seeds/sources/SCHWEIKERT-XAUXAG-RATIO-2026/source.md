# Governed source packet — gold/silver ratio reversion

Source approval: OWNER commodity/energy sleeve mission received 2026-07-25,
explicitly naming `XAUUSD~XAGUSD (gold/silver ratio reversion, market-neutral
basket)` as an allowed candidate and requiring reputable-source criteria.

## Completely read sources

1. Karsten Schweikert (2018), “Are gold and silver cointegrated? New evidence
   from quantile cointegrating regressions,” *Journal of Banking & Finance* 88,
   44–51, DOI `10.1016/j.jbankfin.2017.11.010`.
   Publisher abstract and section summary read 2026-07-25:
   https://www.sciencedirect.com/science/article/pii/S0378426617302807
2. OlaOluwa S. Yaya, Xuan Vinh Vo, and Hammed A. Olayinka (2021), “Gold and
   silver prices, their stocks and market fear gauges: Testing fractional
   cointegration using a robust approach,” *Resources Policy* 72, 102045,
   DOI `10.1016/j.resourpol.2021.102045`.
   Publisher abstract read 2026-07-25:
   https://www.sciencedirect.com/science/article/abs/pii/S0301420721000623

## Bounded extraction

Both papers support a long-run, potentially time-varying relationship between
gold and silver prices and explicitly discuss cointegration/mean reversion.
Schweikert warns that a constant cointegrating vector can fail and reports
state dependence. Therefore the QM card does not claim a universal equilibrium:
it uses a short rolling D1 log-ratio normalization, hard per-leg stops, and
requires Q02 onward to falsify the CFD implementation.

The papers do not specify a 60-day window, z=2 entry, z=0.5 exit, ATR stop,
Darwinex CFD mapping, or trade sizing. Those are transparent QM implementation
hypotheses, not source claims. No paper result is treated as proof of future
profitability or portfolio decorrelation.
