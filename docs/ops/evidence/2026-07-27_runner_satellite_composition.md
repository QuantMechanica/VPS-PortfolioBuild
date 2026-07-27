# Runner + decorrelated satellite composition

Date: 2026-07-27. Decision: measurement only; no combined EA was built and no backtest was queued.

## Binding method

The live Q09 gate rejects `corr_eff >= 0.40`, admits the strong zone only at `corr_eff < 0.15` with positive marginal contribution, and otherwise requires `delta Sharpe >= 0.020` (`tools/strategy_farm/portfolio/portfolio_admission.py:69-71,124-160`). `corr_eff` is the stricter of full-history and the book's top-quartile 20-day-volatility regime, with at least 20 regime days (`portfolio_admission.py:76-90,208-249`).

The gate-clean, entry-time-complete pool contains 15 sleeves. Parameters and membership were chosen on 2017-10-09..2022-09-15 (first 60%); 2022-09-16..2025-12-30 is untouched OOS. Equal weights implement a fixed risk budget. The stream universe, dormancy-safe inputs, pessimistic multi-day handling, calendar and censoring machinery come from `challenge_book_60d.py`; censored 60-day starts are failures.

## Result

Runner alone IS: med60 2.933%, |wDay| 1.764%, wDD p90 6.865%, FUND_SCORE 0.427. OOS: med60 4.525%, |wDay| 1.664%, wDD p90 9.290%, FUND_SCORE 0.487.

Q09-passing sets: **35**. Effective independent samples are conservatively about 30 IS and 20 OOS; the much larger overlapping-window counts are not independent.

| Rank | Members | IS FUND_SCORE | OOS FUND_SCORE | IS wDD p90 | OOS wDD p90 |
|---:|---|---:|---:|---:|---:|
| 1 | 9936:USDJPY, 10145:XAUUSD, 13301:GDAXI | 0.654 | 0.641 | 2.506% | 3.464% |
| 2 | 9936:USDJPY, 12969:USDJPY, 13301:GDAXI | 0.650 | 0.709 | 2.408% | 3.302% |
| 3 | 9936:USDJPY, 13108:XTIUSD, 13301:GDAXI | 0.643 | 0.578 | 2.401% | 4.007% |
| 4 | 9936:USDJPY, 10145:XAUUSD, 12969:USDJPY, 13301:GDAXI | 0.638 | 0.799 | 1.841% | 2.386% |
| 5 | 9936:USDJPY, 20010:XAUUSD, 10145:XAUUSD, 13301:GDAXI | 0.622 | 0.666 | 1.984% | 2.738% |
| 6 | 9936:USDJPY, 12969:USDJPY, 13108:XTIUSD, 13301:GDAXI | 0.614 | 0.616 | 1.820% | 2.972% |
| 7 | 9936:USDJPY, 10145:XAUUSD, 13108:XTIUSD, 13301:GDAXI | 0.612 | 0.614 | 1.879% | 3.051% |
| 8 | 9936:USDJPY, 12969:USDJPY, 13301:GDAXI, 20010:XAUUSD | 0.606 | 0.766 | 1.897% | 2.340% |
| 9 | 9936:USDJPY, 13301:GDAXI, 20010:XAUUSD | 0.600 | 0.670 | 2.532% | 3.330% |
| 10 | 9936:USDJPY, 13108:XTIUSD, 13301:GDAXI, 9403:GDAXI | 0.591 | 0.638 | 2.217% | 2.954% |
| 11 | 9936:USDJPY, 10145:XAUUSD, 13301:GDAXI, 9403:GDAXI | 0.591 | 0.711 | 2.362% | 2.741% |
| 12 | 9936:USDJPY, 12969:USDJPY, 13301:GDAXI, 9403:GDAXI | 0.584 | 0.728 | 2.322% | 2.575% |
| 13 | 9936:USDJPY, 13108:XTIUSD, 20010:XAUUSD, 13301:GDAXI | 0.569 | 0.623 | 1.738% | 2.951% |
| 14 | 9936:USDJPY, 10145:XAUUSD, 13108:XTIUSD, 9403:GDAXI | 0.561 | 0.556 | 2.012% | 2.899% |
| 15 | 9936:USDJPY, 13301:GDAXI, 20010:XAUUSD, 9403:GDAXI | 0.540 | 0.730 | 2.357% | 2.697% |
| 16 | 9936:USDJPY, 13301:GDAXI, 9403:GDAXI | 0.537 | 0.700 | 3.146% | 3.480% |
| 17 | 9936:USDJPY, 10145:XAUUSD, 13108:XTIUSD | 0.532 | 0.527 | 2.309% | 3.659% |
| 18 | 9936:USDJPY, 12969:USDJPY, 13108:XTIUSD, 9403:GDAXI | 0.527 | 0.564 | 2.060% | 2.573% |
| 19 | 9936:USDJPY, 10145:XAUUSD, 12969:USDJPY, 9403:GDAXI | 0.510 | 0.644 | 2.207% | 2.357% |
| 20 | 9936:USDJPY, 13108:XTIUSD, 9403:GDAXI | 0.508 | 0.531 | 2.772% | 3.635% |
| 21 | 9936:USDJPY, 13108:XTIUSD, 20010:XAUUSD, 9403:GDAXI | 0.505 | 0.547 | 2.104% | 2.850% |
| 22 | 9936:USDJPY, 12969:USDJPY, 13108:XTIUSD | 0.493 | 0.614 | 2.378% | 3.218% |
| 23 | 9936:USDJPY, 10145:XAUUSD, 12969:USDJPY | 0.485 | 0.551 | 2.438% | 3.252% |
| 24 | 9936:USDJPY, 10145:XAUUSD, 9403:GDAXI | 0.484 | 0.594 | 2.960% | 3.321% |
| 25 | 9936:USDJPY, 20010:XAUUSD, 10145:XAUUSD, 9403:GDAXI | 0.479 | 0.579 | 2.233% | 2.714% |
| 26 | 9936:USDJPY, 10145:XAUUSD, 12969:USDJPY, 13108:XTIUSD | 0.476 | 0.574 | 1.739% | 2.654% |
| 27 | 9936:USDJPY, 20010:XAUUSD, 10145:XAUUSD | 0.464 | 0.511 | 2.479% | 3.612% |
| 28 | 9936:USDJPY, 13108:XTIUSD, 20010:XAUUSD, 10145:XAUUSD | 0.458 | 0.518 | 1.741% | 2.898% |
| 29 | 9936:USDJPY, 13108:XTIUSD, 20010:XAUUSD | 0.458 | 0.527 | 2.262% | 3.543% |
| 30 | 9936:USDJPY, 12969:USDJPY, 20010:XAUUSD | 0.456 | 0.547 | 2.283% | 3.287% |
| 31 | 9936:USDJPY, 12969:USDJPY, 9403:GDAXI | 0.454 | 0.632 | 2.946% | 2.957% |
| 32 | 9936:USDJPY, 12969:USDJPY, 20010:XAUUSD, 9403:GDAXI | 0.451 | 0.681 | 2.221% | 2.246% |
| 33 | 9936:USDJPY, 12969:USDJPY, 20010:XAUUSD, 10145:XAUUSD | 0.449 | 0.529 | 1.835% | 2.662% |
| 34 | 9936:USDJPY, 20010:XAUUSD, 9403:GDAXI | 0.436 | 0.626 | 2.965% | 3.133% |
| 35 | 9936:USDJPY, 12969:USDJPY, 13108:XTIUSD, 20010:XAUUSD | 0.417 | 0.597 | 1.660% | 2.589% |

Every pairwise IS daily correlation and every sequential gate decision is preserved in `2026-07-27_runner_satellite_composition.json`. This is the complete matrix and unrounded evidence.

## Interpretation

The top IS-selected passing set improves OOS FUND_SCORE from 0.487 to 0.641. Of the 35 Q09-passing sets, 1 lower FUND_SCORE versus the runner on IS and 0 lower it on OOS. Those negative results remain in the table: Q09 admission is necessary, not proof that drift dilution beats drawdown reduction.
