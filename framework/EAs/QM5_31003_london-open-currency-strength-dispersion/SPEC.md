# QM5_31003_london-open-currency-strength-dispersion — Strategy Spec

**EA ID:** QM5_31003
**Slug:** `london-open-currency-strength-dispersion`
**Source:** `london-open-currency-strength-dispersion-official-source`
**Author of this spec:** Codex
**Last revised:** 2026-08-16

## 1. Strategy Logic

At the first M15 entry evaluation in the configured 08:00 UTC hour, the EA computes 24-hour returns for the complete 28-pair G8 FX cross-section. Each currency's strength is the mean of its seven signed pair returns. A host pair buys only when its base is the single strongest currency, its quote is the single weakest, both exceed the default ±0.40% side thresholds, and total dispersion is at least 0.80%; the sell rule is symmetric.

The stop is 1.5 ATR(14) and the target is 2.5 times that stop distance. The strategy attempts at most one entry per UTC day and preserves the card's spread, rollover, exposure, loss, news, and Friday-close controls.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `InpEvalHourGMT` | `8` | `7–9` | UTC hour for the daily cross-sectional evaluation. |
| `InpMinDispersion` | `0.80` | `0.50–1.50` | Minimum strongest-minus-weakest spread in percentage points. |

The card's `InpRiskPercent` intent is handled by the framework risk inputs and is not duplicated.

## 3. Symbol Universe

**Trade hosts:**

- `GBPJPY.DWX` — primary card pair, slot 0.
- `EURUSD.DWX` — approved portable pair, slot 1.
- `AUDUSD.DWX` — approved portable pair, slot 2.

**Read-only signal dependencies:** the canonical 28 G8 crosses, all with the `.DWX` suffix. They supply the seven observations per currency but are never order targets from this EA instance.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Return horizon | 96 M15 bars, representing 24 hours |
| Evaluation cadence | Once daily at 08:00 UTC |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 110 ordering prior |
| Frequency band | 80–160 high-conviction trades per year |
| Typical hold time | Intraday to swing |
| Drawdown prior | Conservative card prior 15%; source claims are not evidence |
| Regime preference | London-open cross-sectional FX dispersion |

## 6. Source Citation

**Source ID:** `london-open-currency-strength-dispersion-official-source`

**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_31003_london-open-currency-strength-dispersion.md`; citation: “Lien, K. (2006). Day Trading and Swing Trading the Currency Market.”

R1 lineage is recorded and R2–R4 are marked PASS in the approved card.

## 7. Risk Model

| Environment | Active risk mode | Required value |
|---|---|---|
| Backtest | `RISK_FIXED` | Greater than zero; generated sets use 1000 |
| Demo / shadow / live | `RISK_PERCENT` | OWNER/deploy-manifest controlled |
| Inactive mode | The other risk input | Exactly zero |

Framework sizing uses the ATR-derived absolute stop. Build status is not a live authorization.

## Revision History

| Version | Date | Reason | Task |
|---|---|---|---|
| v1 | 2026-08-16 | Initial build from approved card | b934613a-ae5d-4590-bd9d-c5ad4ab54801 |

