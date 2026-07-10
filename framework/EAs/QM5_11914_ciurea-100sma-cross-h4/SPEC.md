# QM5_11914_ciurea-100sma-cross-h4 - Strategy Spec

**EA ID:** QM5_11914
**Slug:** `ciurea-100sma-cross-h4`
**Source:** `a5e8f4b2-6c91-5d47-8b39-d2a6c4e7f3b8`
**Author of this spec:** Codex
**Last revised:** 2026-07-10

---

## 1. Strategy Logic

On each closed H4 bar, the EA compares the close with the 100-period simple
moving average. It buys when the close crosses from below to above the average
and sells when the close crosses from above to below it. An opposite cross
closes the current position before the EA flips direction. Each entry carries a
3 x ATR(14) protective stop, while a 250-bar time stop prevents an indefinitely
stalled position.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_sma_period` | 100 | 20-250 | H4 simple-moving-average period used by the close-cross signal. |
| `strategy_atr_period` | 14 | 5-50 | H4 ATR period used for the protective stop. |
| `strategy_atr_sl_mult` | 3.0 | 1.0-5.0 | Protective-stop distance in ATR units. |
| `strategy_time_stop_bars` | 250 | 50-500 | Maximum holding time in H4 bars. |

Framework inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are
not repeated here.

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX`, `GBPUSD.DWX` - the two FX majors tested in the source study.
- `USDJPY.DWX`, `USDCAD.DWX`, `USDCHF.DWX` - liquid USD-major portability tests.
- `AUDUSD.DWX`, `NZDUSD.DWX` - liquid commodity-currency portability tests.
- `EURJPY.DWX`, `GBPJPY.DWX`, `AUDJPY.DWX` - liquid JPY-cross portability tests.

**Explicitly NOT for:**

- Indices, metals, energy, and crypto - this build tests the source's H4 FX
  close-cross claim and does not assume cross-asset portability.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` on the H4 host chart |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 55 |
| Typical hold time | several H4 bars to several weeks; capped at 250 H4 bars |
| Expected drawdown profile | whipsaw losses in sideways markets; hard ATR risk cap per trade |
| Regime preference | persistent FX trends |
| Win rate target (qualitative) | low-to-medium; source reports roughly 37%-42% |

---

## 6. Source Citation

**Source ID:** `a5e8f4b2-6c91-5d47-8b39-d2a6c4e7f3b8`
**Source type:** retail FX empirical study
**Pointer:** Cristina Ciurea, "The Truth Behind Commonly Used Indicators",
ScientificForex.com, mirrored at `https://www.mql5.com/en/blogs/post/736967`.
**R1-R4 verdict (Q00):** all PASS per
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_11914_ciurea-100sma-cross-h4.md`.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV-to-mode validation is enforced by `QM_FrameworkInit`
(`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-10 | Completed Q01 artefacts and repaired Q02 OnInit infrastructure | Farm task `53d907d1-a86b-411d-8459-d526faceadee` |
