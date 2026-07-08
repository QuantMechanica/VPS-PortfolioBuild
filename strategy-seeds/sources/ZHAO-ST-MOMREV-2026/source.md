# ZHAO-ST-MOMREV-2026

Canonical source for QM5_13049.

Source:

- Zhao, Shen; Ding, Yiyi; Yu, Jianfeng; Kang, Wenjin. "Momentum and Reversal on the Short-Term Horizon: Evidence from Commodity Markets." January 2026. DOI 10.2139/ssrn.6425598.
- SSRN: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=6425598
- ResearchGate metadata mirror: https://www.researchgate.net/publication/403179200_Momentum_and_Reversal_on_the_Short-Term_Horizon_Evidence_from_Commodity_Markets

Research note:

The paper documents short-horizon commodity futures momentum and reversal effects. The build uses only the short-term commodity momentum side as lineage: if recent non-residual commodity movement persists and the volatility backdrop is not elevated, one-week continuation can be expressed mechanically.

Runtime port:

The EA does not consume the paper's cross-sectional decomposition, futures-chain data, flow files, API data, or ML output. It ports the idea to `XTIUSD.DWX` using broker D1 closes only: prior 5 closed D1 return for direction, 20-D1 realized volatility percentile as a low-volatility regime filter, ATR stop, time exit, and opposite-return exit.
