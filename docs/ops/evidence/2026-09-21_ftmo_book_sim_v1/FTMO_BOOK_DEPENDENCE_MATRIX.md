# FTMO_BOOK_DEPENDENCE_MATRIX

Schema: `qm.ftmo-book-dependence-matrix/v1`. Prague-day basis: `Europe/Prague`.

The table preserves separate dependence dimensions; no composite score is used.

Top fail-together pair: **10403_XAUUSD_D1/41219_XAUUSD_D1**.
Clusters: `[["10403_XAUUSD_D1", "10700_XAUUSD_H1", "41219_XAUUSD_D1"]]`.

| pair | daily r | downside r | loss overlap / indep | trade-day / indep | position overlap | same-dir | tail / indep | worst20 | max open-risk proxy USD | flags |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 10403_XAUUSD_D1/10700_XAUUSD_H1 | 0.020 | -0.473 | 1.265 | 1.361 | 0.328 | 0.710 | 0.000 | 0 | 628.50 | symbol, news |
| 10403_XAUUSD_D1/10706_GBPUSD_H1 | 0.002 | -0.422 | 0.423 | 0.964 | 0.318 | - | 0.000 | 0 | 647.59 | news |
| 10403_XAUUSD_D1/11422_USDCAD_D1 | 0.108 | -0.426 | 2.285 | 1.484 | 0.380 | - | 0.000 | 0 | 629.15 | session, news |
| 10403_XAUUSD_D1/13213_USDJPY_H1 | -0.046 | -0.427 | 1.031 | 0.974 | 0.333 | - | 2.583 | 2 | 581.50 | news |
| 10403_XAUUSD_D1/41219_XAUUSD_D1 | -0.089 | -0.421 | 2.374 | 1.686 | 0.395 | 0.002 | 0.000 | 0 | 393.89 | symbol, session, news |
| 10700_XAUUSD_H1/10706_GBPUSD_H1 | -0.010 | -0.515 | 1.379 | 1.312 | 0.232 | - | 0.000 | 0 | 813.37 | session, news |
| 10700_XAUUSD_H1/11422_USDCAD_D1 | 0.030 | -0.582 | 1.684 | 1.014 | 0.176 | - | 0.000 | 0 | 671.20 | news |
| 10700_XAUUSD_H1/13213_USDJPY_H1 | -0.007 | -0.366 | 1.049 | 0.950 | 0.204 | - | 0.000 | 0 | 562.91 | news |
| 10700_XAUUSD_H1/41219_XAUUSD_D1 | 0.011 | -0.538 | 0.491 | 1.058 | 0.188 | 0.252 | 0.000 | 0 | 532.92 | symbol, news |
| 10706_GBPUSD_H1/11422_USDCAD_D1 | -0.007 | -0.495 | 0.715 | 0.679 | 0.211 | - | 0.000 | 0 | 668.84 | news |
| 10706_GBPUSD_H1/13213_USDJPY_H1 | 0.073 | -0.325 | 1.070 | 0.918 | 0.232 | - | 2.873 | 1 | 811.24 | news |
| 10706_GBPUSD_H1/41219_XAUUSD_D1 | -0.005 | -0.524 | 0.000 | 0.991 | 0.055 | - | 0.000 | 0 | 575.53 | news |
| 11422_USDCAD_D1/13213_USDJPY_H1 | 0.031 | -0.367 | 1.072 | 0.986 | 0.207 | - | 0.000 | 0 | 496.60 | news |
| 11422_USDCAD_D1/41219_XAUUSD_D1 | -0.021 | -0.555 | 1.783 | 1.841 | 0.263 | - | 0.000 | 0 | 442.76 | session, news |
| 13213_USDJPY_H1/41219_XAUUSD_D1 | 0.004 | -0.406 | 0.676 | 1.106 | 0.222 | - | 0.000 | 0 | 471.11 | news |

Position overlap uses exact closed-trade entry/exit intervals. Open risk is a conservative per-trade MAE proxy, not tick-exact floating P/L.
