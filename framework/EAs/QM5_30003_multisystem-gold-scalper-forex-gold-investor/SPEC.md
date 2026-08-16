# QM5_30003_multisystem-gold-scalper-forex-gold-investor — Strategy Spec

**EA ID:** QM5_30003
**Slug:** `multisystem-gold-scalper-forex-gold-investor`
**Source:** `multisystem-gold-scalper-forex-gold-investor-official-source`
**Author of this spec:** Codex
**Last revised:** 2026-08-16

## 1. Strategy Logic

The approved card names three parallel XAUUSD M15 triggers but does not numerically define them. The most literal deterministic implementation uses: (1) a 20-bar ordinary-least-squares channel fade at ±1.5 residual standard deviations, (2) a breakout of the 00:00–06:00 UTC Asian range during 06:00–12:00 UTC, and (3) a newly closed H4 bar whose range is at least 1.5 ATR(14) and whose directional close breaks the prior H4 extreme. The first active module in that order supplies the direction.

The card's fixed 25-pip stop and 30-pip target are represented as 250 and 300 XAU quote points, consistent with the gold point convention in the adjacent Century card. They are placed server-side because the V5 risk sizer requires an absolute stop and fail-safe risk control takes precedence over the card's client-hidden presentation. A 12-hour time exit, ATR-relative spread gate, rollover blackout, one-position limit, equity circuit breakers, central news blackout, and Friday close are active.

These channel/session/surge constants and the server-side realization are explicit review questions; they were not silently presented as source-defined facts.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `InpEnableMod1` | `true` | boolean | Enable the linear-regression channel fade. |
| `InpEnableMod2` | `true` | boolean | Enable the Asian-session range breakout. |
| `InpMaxHoldHours` | `12` | `4–24` | Maximum position age before strategy close. |

Module 3 is always active because the card exposes no enable input for it. Framework inputs are documented centrally.

## 3. Symbol Universe

**Designed for:**

- `XAUUSD.DWX` — the approved card's single-symbol gold market, registered at slot 0.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe reference | H4 volatility-surge module |
| Bar gating | Framework M15 gate plus `QM_IsNewBar(_Symbol, PERIOD_H4)` for module 3 |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 110 ordering prior |
| Frequency band | 80–160 high-conviction trades per year |
| Typical hold time | Intraday, hard maximum 12 hours |
| Drawdown prior | Conservative card prior 15%; source claims are not evidence |
| Regime preference | Mixed mean-reversion, session breakout, and H4 expansion |

## 6. Source Citation

**Source ID:** `multisystem-gold-scalper-forex-gold-investor-official-source`

**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_30003_multisystem-gold-scalper-forex-gold-investor.md`; citation: “Forex Gold Investor Live Performance. FXBlue & Myfxbook Audited.”

R1 lineage is recorded and R2–R4 are marked PASS in the approved card. Review must adjudicate the implementation choices listed in section 1 before pipeline acceptance.

## 7. Risk Model

| Environment | Active risk mode | Required value |
|---|---|---|
| Backtest | `RISK_FIXED` | Greater than zero; generated sets use 1000 |
| Demo / shadow / live | `RISK_PERCENT` | OWNER/deploy-manifest controlled |
| Inactive mode | The other risk input | Exactly zero |

Lot sizing remains framework-owned. No build or review result authorizes live use.

## Revision History

| Version | Date | Reason | Task |
|---|---|---|---|
| v1 | 2026-08-16 | Initial literal build with declared card ambiguities | b934613a-ae5d-4590-bd9d-c5ad4ab54801 |

