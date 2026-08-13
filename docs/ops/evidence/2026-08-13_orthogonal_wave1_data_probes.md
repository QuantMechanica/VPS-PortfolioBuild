# Orthogonal return sources wave 1 — read-only data probes

Date: 2026-08-13  
Router task: `166696e5-ab88-4841-9b40-58d50d50c7d1`  
Scope: read-only analysis of existing `T_Export` CSVs; no terminal launch and no farm database write.

## Outcome

| Probe | Measured result | Build gate | Verdict |
|---|---:|---:|---|
| A — extension fade versus small-gap fade | pooled daily-return correlation `-0.0160`; maximum absolute per-symbol correlation `0.1189` | `abs(correlation) < 0.4` | **GO**, subject to normal Q gates and a full-history rerun |
| B — 60-D1-bar log(XAU/XAG) z-score | AR(1) half-life `15.42` D1 bars; `26/35 = 74.29%` of independent `abs(z)>2` excursions reverted to `abs(z)<0.5` within 40 bars | reversion inside the 40-bar holding horizon | **GO**, subject to normal Q gates and a 2011–2017/2025 coverage rerun |

These are admission pre-checks, not pipeline verdicts. The requested 2015–2025 window is not fully present in the exports: the index overlap begins in July 2018, and the XAG D1 export ends on 2024-12-31. The GO decisions therefore permit card/build review only; they do not waive Q02, Q08, Q11, cost, news, or FTMO checks.

## Probe A method

The prototype used `GDAXI.DWX`, `WS30.DWX`, and `UK100.DWX` H1 bars plus their D1 bars. Unix timestamps were converted to the exchange-local zones `Europe/Berlin`, `America/New_York`, and `Europe/London`. The first H1 bar containing the cash open supplied the session-open anchor. Relevant EUR, USD, or GBP high-impact calendar rows suppressed a trade when an event was within two hours of its signal.

The extension fade used fixed, predeclared mechanics: H1 ATR(20), trigger at `abs(closed H1 close - session open) >= 1.0 * ATR`, enter on the next H1 open toward the anchor, target a 50% retrace, stop at `1.5 * ATR` from the anchor, maximum two entries per session, and mandatory end-of-session flatten. A price-only trend-day guard rejected a session when the prior D1 body was at least `1.5 * D1 ATR(14)` or the opening gap was at least `0.75 * D1 ATR(14)`.

The gap-fade comparator used `0.10 <= abs(open - prior session close) / D1 ATR(14) <= 0.60`, opposite-gap direction, prior close as target, a stop `1.2 * abs(gap)` beyond the session open, one entry per day, and end-of-session flatten. When both stop and target were inside one H1 bar, the stop was assumed first. Daily returns include zero on no-trade sessions. The pooled return is the equal-weight mean of the three symbol returns on common dates.

| Series | Available/common dates | Sessions | Extension trades | Gap trades | Corr., all days | Corr., active-union days |
|---|---|---:|---:|---:|---:|---:|
| GDAXI.DWX | 2018-07-20–2025-12-30 | 1,888 | 2,189 | 1,198 | -0.1189 | -0.1193 |
| WS30.DWX | 2018-07-20–2025-12-31 | 1,915 | 2,253 | 368 | -0.0366 | -0.0348 |
| UK100.DWX | 2018-07-20–2025-12-31 | 1,879 | 2,576 | 1,093 | -0.0007 | -0.0009 |
| Equal-weight pooled | 2018-07-20–2025-12-30 | 1,856 | — | — | **-0.0160** | **-0.0158** |

The gate passes comfortably on both all-session and active-union definitions. This does not establish positive expectancy. It only rejects the stated redundancy concern for this fixed prototype.

## Probe B method

XAU and XAG D1 closes were inner-joined by UTC date. For every closed bar after 59 observations, `r = ln(XAU close) - ln(XAG close)` and `z = (r - mean60(r)) / population_sd60(r)` were calculated. The AR(1) coefficient of the rolling z series, with intercept, was `0.956048`; `-ln(2)/ln(phi)` gives a half-life of `15.42` D1 bars.

An excursion began only on an outward crossing from `abs(z) <= 2` to `abs(z) > 2`. Overlapping entries were suppressed until reversion or the 40-bar horizon. A hit required `abs(z) < 0.5` within the next 40 D1 bars.

| Excursion side | Events | Hits within 40 bars | Hit rate | Median hit time |
|---|---:|---:|---:|---:|
| Gold rich / positive z | 19 | 13 | 68.42% | 20 D1 bars |
| Silver rich / negative z | 16 | 13 | 81.25% | 14 D1 bars |
| Total | 35 | 26 | **74.29%** | **19 D1 bars** |

Available common raw range: 2017-10-02–2024-12-31 (1,868 bars); rolling-z range: 2017-12-22–2024-12-31. The estimated half-life is below the proposed 40-bar time stop and the majority-hit condition holds on both sides.

## Input bindings

| File | SHA-256 |
|---|---|
| `GDAXI.DWX_H1.csv` | `1466F56C40E2527BC41DBDC162A0E2412DA871AE5A79626E090A3C99C48CA9CA` |
| `GDAXI.DWX_D1.csv` | `0B790D26FFBAF2687EDED7414BF1E70B0398935F0B9C583499CE07A5B91EA5E8` |
| `WS30.DWX_H1.csv` | `376EF58310C8D58B64A2D675D45E97FCA6041CBFBC6F4AA0A7D0EE24ED04C558` |
| `WS30.DWX_D1.csv` | `F719A46E527E19ECBABC1B1428EF703E926F1C0E0CFCE0650FE520132AA995B5` |
| `UK100.DWX_H1.csv` | `E0F9449B6287D435B78E13B0E1DCB58B55A56391592CDC0D51ECCFBE20E244C3` |
| `UK100.DWX_D1.csv` | `045BD0F258AC2E1E669ED813DAA212E771B2132E82A1D161325913EDB5FF37BA` |
| `XAUUSD.DWX_D1.csv` | `105AA27A6D0AFF0818B9B76B0EB081D917EA8FB90EC077B599A33EA65AB12F13` |
| `XAGUSD.DWX_D1.csv` | `680876D71982619DABBDE5B87E62E32B6275BC0CEDAC688C670F1A8E84FFDF20` |
| `T_EXPORT_USD_HIGH_2018_2025_NATIVE.csv` | `C1554E52D3456575F51D044CD0097E18B960C7F12485E9B45A07E36536B9AB3B` |
| `T_EXPORT_EUR_HIGH_2018_2025_NATIVE.csv` | `F619007AF0A0126F665AFE247B6828E21C36A642CA4E6714F962AE7573BF8137` |
| `T_EXPORT_GBP_HIGH_2018_2025_NATIVE.csv` | `8B4291BAE1E41911C66FB683B994BAECE4910C3623FEFFAA3D43F2C970C1BEE4` |

All inputs are under `D:/QM/mt5/T_Export/MQL5/Files/`.
