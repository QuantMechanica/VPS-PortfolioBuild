# QM5_41010_developing-poc-migration-scalper — Strategy Spec

**EA ID:** QM5_41010
**Slug:** developing-poc-migration-scalper
**Source:** developing-poc-migration-scalper-official-source
**Author of this spec:** Gemini
**Last revised:** 2026-08-18

---

## 1. Strategy Logic

Quantitative intraday developing Point of Control (d-POC) migration scalper operating on M15 bars. The EA continuously computes the volume profile and d-POC over a rolling intraday lookback window (InpProfileWindowBars). When the d-POC migrates in a given direction across the lookback period (delta d-POC = dPOC[1] - dPOC[1+Lookback]) and price closes beyond the active d-POC line by a buffer with volume exceeding 1.2x SMA(Vol, 20), the strategy enters a momentum scalping position in the direction of institutional value migration. Take profit is placed at 2.0x SL distance (1:2.0 R:R), with stop loss placed at the active d-POC level +/- buffer. The stop loss ratchets along with the migrating d-POC level to protect accumulated profits.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `InpLookbackBars` | 4 | 2-8 | Lookback bars for delta d-POC evaluation |
| `InpMinVolumeMult` | 1.20 | 1.0-1.5 | Minimum volume multiplier vs 20-period SMA |
| `InpBufferTicks` | 4 | 2-8 | Entry and SL buffer distance in ticks |
| `InpProfileWindowBars` | 32 | 16-64 | Rolling volume profile lookback window in bars |
| `InpBucketTicks` | 10 | 5-20 | Profile histogram bucket granularity in ticks |
| `InpAtrPeriod` | 14 | 10-30 | ATR period for spread & volatility filter |
| `InpSpreadAtrMult` | 1.8 | 1.0-3.0 | Maximum allowable spread as multiple of M15 ATR |
| `InpRrMultiplier` | 2.0 | 1.5-3.0 | Take profit risk-reward multiplier |
| `InpEnableRatchetTrailing` | true | true/false | Ratchet stop loss with migrating d-POC |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` — Tech-heavy index with strong institutional volume acceptance trends and rapid intraday POC shifts.
- `SP500.DWX` — Broad market equity index CFD exhibiting clear auction market value migration.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_M15)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 110 |
| Typical hold time | 1 to 6 hours |
| Expected drawdown profile | Tight controlled drawdown (<2.8%) |
| Regime preference | trend/breakout with volume acceptance |
| Win rate target (qualitative) | moderate-high |

---

## 6. Source Citation

**Source ID:** developing-poc-migration-scalper-official-source
**Source type:** book / research
**Pointer:** Steidlmayer, P. (1986). Markets & Market Logic. CBOT Market Profile Framework.
**R1–R4 verdict (Q00):** all PASS

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio |

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-18 | Initial build from approved card | Task 5111533d-3668-4f98-a036-c379de89ce7c |
