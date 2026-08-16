# QM5_30002_zigzag-gold-breakout-happy-gold — Strategy Spec

**EA ID:** QM5_30002
**Slug:** `zigzag-gold-breakout-happy-gold`
**Source:** `zigzag-gold-breakout-happy-gold-official-source`
**Author of this spec:** Codex
**Last revised:** 2026-08-16

## 1. Strategy Logic

On each closed XAUUSD M15 bar, the EA reconstructs the most recent confirmed ZigZag high and low with card constants depth 12, deviation 5 points, and backstep 3. It buys a close above the confirmed high only when the close is above the H4 EMA(50), and sells the symmetric downside break. Orders use the card's fixed 240-point stop and 360-point target; after 150 points of profit, the stop ratchets 100 points behind price.

The entry path also applies the card's ATR-relative spread gate, 23:55–00:05 UTC rollover blackout, one-position limit, and daily/total equity circuit breakers. Framework news and Friday-close controls remain active.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `InpZZDepth` | `12` | `8–24` | ZigZag pivot depth. |
| `InpH4EMAPeriod` | `50` | `20–100` | H4 trend EMA period. |
| `InpTPPoints` | `360` | `200–600` | Fixed target in XAU quote points. |
| `InpSLPoints` | `240` | `150–400` | Fixed stop in XAU quote points. |

Framework risk, news, Friday-close, seed, and stress inputs are defined in `framework/V5_FRAMEWORK_DESIGN.md`.

## 3. Symbol Universe

**Designed for:**

- `XAUUSD.DWX` — the card's single-symbol gold market, registered at symbol slot 0.

No other symbol is authorized by the approved card.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe reference | H4 EMA(50) |
| Bar gating | Framework `QM_IsNewBar()` |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 110 ordering prior |
| Frequency band | 80–160 high-conviction trades per year |
| Typical hold time | Intraday, minutes to hours |
| Drawdown prior | Conservative card prior 15%; source performance claims are not pipeline evidence |
| Regime preference | Confirmed pivot breakouts aligned with the H4 trend |

## 6. Source Citation

**Source ID:** `zigzag-gold-breakout-happy-gold-official-source`

**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_30002_zigzag-gold-breakout-happy-gold.md`; citation: “Happy Gold Official EA Specification. 5+ Years Live Track Record.”

R1 lineage is recorded and R2–R4 are marked PASS in the OWNER-approved card. Those source claims do not substitute for Q-phase evidence.

## 7. Risk Model

| Environment | Active risk mode | Required value |
|---|---|---|
| Backtest | `RISK_FIXED` | Greater than zero; generated sets use 1000 |
| Demo / shadow / live | `RISK_PERCENT` | OWNER/deploy-manifest controlled |
| Inactive mode | The other risk input | Exactly zero |

The framework risk sizer owns lot calculation from the absolute stop. Build approval is non-live and does not authorize deployment.

## Revision History

| Version | Date | Reason | Task |
|---|---|---|---|
| v1 | 2026-08-16 | Initial build from approved card | b934613a-ae5d-4590-bd9d-c5ad4ab54801 |

