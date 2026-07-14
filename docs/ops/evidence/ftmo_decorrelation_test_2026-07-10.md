# FTMO decorrelation test (workstream B) — 2026-07-10

**Status: INVALIDATED FOR BOOK DECISIONS.** The subsequent MT5 reconciliation
shows that the reported EURUSD premise was wrong and the GBPUSD stream does not
match its report. `10569/EURUSD` is PF `0.82`, Net Profit `-$27,029.81` in the
fresh MT5 report, not PF `1.20`. `10706/GBPUSD` has 364 stream trades versus 367
report trades and a corrected-net gap of `-$11,192.55`. The correlation numbers
may describe the available stream samples, but neither sleeve may be added and
the breach simulation is not decision-grade.

Question: do FX sleeves (uncorrelated with the index+gold core) cut the book's max-breach
tail (~30%, now the co-binding failure) and thereby compress time-to-+10%?

Core = density-improved 14-sleeve book (12 − 10163 + 10118/10916/10546). FX candidates
recompiled fresh-MAE + backtested on T8–T10, 2017–2025, Model 4:
- 10569 EURUSD.DWX H4 (original claim PF 1.20; reconciled MT5 PF 0.82) — 341 trades
- 10706 GBPUSD.DWX H1 (stream claim PF 1.28; MT5 PF 1.31 with a 3-trade mismatch) — 364 stream trades
- 11891 GBPJPY.DWX D1 (PF 1.54) — did not produce a fresh stream in the window (cold-cache /
  low D1 activity); it is also the weakest decorrelator (JPY cross ≈ correlates w/ the USDJPY engine)

## Correlation (realized daily PnL vs 14-sleeve core)
| candidate | corr to core |
|---|---|
| 10569 EURUSD | **+0.029** |
| 10706 GBPUSD | **+0.034** |

The pure-USD FX sleeves are genuinely **uncorrelated** with the index+gold core.

## Augmented-book speed/breach (matched 20% daily-breach budget, tool: ftmo_decorrelation_test.py)
| book | sleeves | P(+10%) | med cal days | daily-breach | max-breach |
|---|---|---|---|---|---|
| core 14 | 14 | 52.3% | 40 | 19% | 29% |
| core + 10569 EURUSD | 15 | 51.5% | 40 | 19% | 29% |
| core + 10706 GBPUSD | 15 | 53.1% | 40 | 19% | 28% |
| core + all FX | 16–17 | 52.0% | 40 | 20% | 28% |

Adding uncorrelated FX at median weight barely moves max-breach (29%→28%) and pass (flat).

## The real finding — a structural MODEL limitation
The conservative reconstruction sets `open_mae[day] = Σ mae_acct of every trade open that day`
— it assumes **all positions bottom simultaneously**, *independent of correlation*. So the model
**cannot reward decorrelation**: adding any sleeve only adds worst-case MAE, whether or not it
actually co-draws-down with the core. This is why:
- the density gain (A) was modest (added edge barely beat the added worst-case MAE), and
- decorrelation reads as ~neutral here even though the FX sleeves are genuinely uncorrelated.

Two biases that partly offset: the model **understates** decorrelation benefit (worst-case
alignment), while commission-free .DWX backtests **overstate** FX profitability (FTMO FX
commission ≈ $45/trade is real and absent here — see reference_commission_by_asset_class).

## Verdict / recommendation
- **Decorrelation-via-FX is directionally right but NOT quantifiable with current tools.** The
  worst-case-aligned MAE model structurally can't credit it.
- **The density delta (A) is also invalidated by stream/report mismatches** and
  must not ship until its inputs reconcile and the experiment is rerun.
- To settle decorrelation properly, the next tooling investment is a **Stufe-2 joint-MAE model**:
  per-bar portfolio equity using the ACTUAL co-movement of sleeve MAEs (not the worst-case sum),
  plus FX commission injection. Only that can price whether uncorrelated FX cuts the tail enough
  to outweigh its commission drag.
- The farm's FX/energy pool is also **thin** (10 high-freq candidates; mandate was index/gold),
  so material FX reweighting isn't well-supported by inventory yet — a Codex build target if we
  commit to the decorrelation lever.
