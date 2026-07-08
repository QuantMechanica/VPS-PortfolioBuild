# ZHAO-ST-MOMREV-2026

Canonical source for QM5_13049 and QM5_13050.

Source:

- Zhao, Shen; Ding, Yiyi; Yu, Jianfeng; Kang, Wenjin. "Momentum and Reversal on the Short-Term Horizon: Evidence from Commodity Markets." January 2026. DOI 10.2139/ssrn.6425598.
- SSRN: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=6425598
- ResearchGate metadata mirror: https://www.researchgate.net/publication/403179200_Momentum_and_Reversal_on_the_Short-Term_Horizon_Evidence_from_Commodity_Markets

Cards extracted:

- `QM5_13049_xti-1w-mom-vol`: XTIUSD.DWX D1 one-week continuation after a large
  five-day move when realized volatility is not elevated.
- `QM5_13050_xti-1w-rev-vol`: XTIUSD.DWX D1 one-week reversal after a large
  five-day move when realized volatility is elevated.
- `QM5_13055_xbr-1w-mom-vol`: XBRUSD.DWX D1 one-week continuation after a large
  five-day move when realized volatility is not elevated.

Research note:

The paper documents short-horizon commodity futures momentum and reversal effects. The build uses only the short-term commodity momentum side as lineage: if recent non-residual commodity movement persists and the volatility backdrop is not elevated, one-week continuation can be expressed mechanically.

Runtime port:

The EAs do not consume the paper's cross-sectional decomposition, futures-chain
data, flow files, API data, or ML output. They port the idea to `XTIUSD.DWX`
and `XBRUSD.DWX` using broker D1 closes only. QM5_13049 uses prior 5 closed D1
return for direction, 20-D1 realized volatility percentile as a low-volatility
regime filter, ATR stop, time exit, and opposite-return exit. QM5_13050 uses
the same closed-bar return and realized-volatility primitives but trades the
documented reversal side: fade the prior 5-D1 move only when current 20-D1
realized volatility ranks high versus the prior 120 observations. QM5_13055
ports the continuation/low-volatility branch to Brent (`XBRUSD.DWX`) so the
pipeline can test a separate crude benchmark rather than another WTI or XNG
sleeve.
