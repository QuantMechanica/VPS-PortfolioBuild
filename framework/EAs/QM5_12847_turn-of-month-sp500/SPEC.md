<!--
QuantMechanica V5 — EA Spec Document
Required by Q01 Build & Spec gate (Vault: `03 Pipeline/Q01 Build & Spec.md`)
Validator: `framework/scripts/validate_spec_doc.py`
-->

# QM5_12847_turn-of-month-sp500 — Strategy Spec

**EA ID:** QM5_12847
**Slug:** `turn-of-month-sp500`
**Source:** `quantified-turn-of-month-20260701` (see `docs/research/YOUTUBE_STRATEGY_SYNTHESIS_BATCH3_2026-07-01.md`)
**Author of this spec:** Claude
**Last revised:** 2026-07-01

---

## 1. Strategy Logic

Long-only index seasonal strategy exploiting the well-documented Turn-of-Month (Ultimo) effect: equity index prices exhibit a persistent upward bias around the month boundary driven by mechanical fund inflows, salaries, retirement contributions, and window dressing. The EA enters long at the close of the Nth-last actual trading day of each calendar month (default N=5), counting from the D1 bar series to exclude weekends and holidays. It exits at the close of the Mth actual trading day of the following calendar month (default M=3). A bull-regime filter (daily close above the 200-bar SMA) suppresses entries in bear markets. One trade per month maximum; single-position-per-magic; time-based exit with an ATR(14) safety stop for position sizing.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `entry_td_from_end` | 5 | 4–6 | Nth-last trading day of the month to enter (bar-count, not calendar days) |
| `exit_td_of_next` | 3 | 2–4 | Mth trading day of the following month to exit |
| `regime_sma_period` | 200 | 100–300 | D1 SMA period for bull-regime gate |
| `use_regime_filter` | true | true/false | Enable/disable 200-SMA regime gate |
| `sl_atr_period` | 14 | 7–21 | ATR period for safety-stop sizing |
| `sl_atr_mult` | 3.0 | 2.0–5.0 | ATR multiplier for safety-stop sizing |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` — canonical S&P 500 instrument; primary evidence base for the Ultimo effect (backtest-only, broker routes no orders)
- `NDX.DWX` — Nasdaq 100; correlated US large-cap index, live-tradable transfer target
- `WS30.DWX` — Dow Jones 30; correlated US large-cap index, live-tradable transfer target
- `GDAXI.DWX` — DAX 40; global multi-index basket for tradeable-transfer validation

**Explicitly NOT for:**
- `EURUSD.DWX` and FX pairs — calendar month-end flows are equity-specific; FX lacks the fund-inflow mechanism

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~12 (one per calendar month, regime filter may suppress 1–3) |
| Typical hold time | ~8 trading days (entry_td_from_end + exit_td_of_next) |
| Expected drawdown profile | ~5% per-symbol; short hold limits exposure |
| Regime preference | trend / bull-regime only |
| Win rate target (qualitative) | medium (~55–65% based on published Ultimo research) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `quantified-turn-of-month-20260701`
**Source type:** video / AI synthesis
**Pointer:** `docs/research/YOUTUBE_STRATEGY_SYNTHESIS_BATCH3_2026-07-01.md`
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_12847_turn-of-month-sp500.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-01 | Initial build from card | 45615361-4789-4182-bd58-c651684ba44e |
