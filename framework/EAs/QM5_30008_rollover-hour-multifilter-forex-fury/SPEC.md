# QM5_30008_rollover-hour-multifilter-forex-fury — Strategy Spec

**EA ID:** QM5_30008
**Slug:** `rollover-hour-multifilter-forex-fury`
**Source:** `rollover-hour-multifilter-forex-fury-official-source`
**Author of this spec:** Codex
**Last revised:** 2026-08-16

## 1. Strategy Logic

During the card's 23:00–00:00 UTC rollover hour, the EA buys an M15 touch of the SMA(20) minus 0.15% envelope when the close remains above SMA(50), and sells the symmetric upper-envelope touch below SMA(50). Entries are blocked from 23:55 through 00:05 UTC, leaving the card's mandatory rollover safety gap intact. Orders carry a fixed 250-point stop and 50-point target and are force-closed at the next 00:30 UTC boundary.

The card's spread, one-position, daily-loss, total-drawdown, news, and Friday-close controls remain active.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `InpStartHourGMT` | `23` | `22–23` | UTC trading-window start hour. |
| `InpEndHourGMT` | `0` | `0–1` | UTC trading-window end hour, wrap-safe. |
| `InpTPPoints` | `50` | `30–100` | Fixed target in quote points. |
| `InpSLPoints` | `250` | `150–400` | Fixed stop in quote points. |

## 3. Symbol Universe

- `EURUSD.DWX` — primary card symbol, slot 0.
- `GBPUSD.DWX` — portable card symbol, slot 1.
- `USDCHF.DWX` — portable card symbol, slot 2.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Clock | Broker time converted to UTC with the framework DST helper |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 110 ordering prior |
| Frequency band | 80–160 high-conviction trades per year |
| Typical hold time | Under 90 minutes; flat at 00:30 UTC |
| Drawdown prior | Conservative card prior 15%; source claims are not evidence |
| Regime preference | Low-liquidity rollover envelope reversion |

## 6. Source Citation

**Source ID:** `rollover-hour-multifilter-forex-fury-official-source`

**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_30008_rollover-hour-multifilter-forex-fury.md`; citation: “Forex Fury Official Specification & Audited Myfxbook Verified Track Record.”

R1 lineage is recorded and R2–R4 are marked PASS in the approved card.

## 7. Risk Model

| Environment | Active risk mode | Required value |
|---|---|---|
| Backtest | `RISK_FIXED` | Greater than zero; generated sets use 1000 |
| Demo / shadow / live | `RISK_PERCENT` | OWNER/deploy-manifest controlled |
| Inactive mode | The other risk input | Exactly zero |

The V5 framework owns sizing and all build output remains non-live.

## Revision History

| Version | Date | Reason | Task |
|---|---|---|---|
| v1 | 2026-08-16 | Initial build from approved card | b934613a-ae5d-4590-bd9d-c5ad4ab54801 |

