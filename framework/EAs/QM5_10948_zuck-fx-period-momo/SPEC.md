# QM5_10948_zuck-fx-period-momo - Strategy Spec

**EA ID:** QM5_10948
**Slug:** `zuck-fx-period-momo`
**Source:** `21ef3dfd-fac6-5d5d-b9a0-5ba447992f94` (see `strategy-seeds/sources/21ef3dfd-fac6-5d5d-b9a0-5ba447992f94/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-17

---

## 1. Strategy Logic

The EA trades H1 continuation on major FX pairs. On each new H1 bar it compares the last closed bar return, `close[1] / close[2] - 1`, against a fraction of ATR(14) divided by the last close. If the return is greater than `+0.20 * ATR(14) / close[1]`, it buys; if the return is less than the negative threshold, it sells. The baseline exits after one H1 bar, with an emergency stop placed one ATR from entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 14 | 1+ | ATR period used for trigger normalization and stop distance. |
| `strategy_trigger_atr_frac` | 0.20 | 0.10-0.50 in P3 card sweep | One-bar return must exceed this fraction of ATR/close. |
| `strategy_hold_bars` | 1 | 1-4 in P3 card sweep | H1 bars to hold before strategy time exit. |
| `strategy_atr_stop_mult` | 1.0 | 0.75-1.5 in P3 card sweep | Initial stop distance in ATR multiples. |
| `strategy_max_spread_atr_frac` | 0.15 | fixed baseline | Maximum spread as a fraction of ATR(14). |
| `strategy_monday_start_hour` | 6 | fixed baseline | Earliest Monday broker hour for new entries. |
| `strategy_friday_stop_hour` | 18 | fixed baseline | First Friday broker hour that blocks new entries. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - primary deutsche-mark successor proxy from the card.
- `USDJPY.DWX` - native DWX yen pair matching the source's yen serial-correlation theme.
- `GBPJPY.DWX` - native DWX JPY cross for the card's JPY cross basket.
- `EURJPY.DWX` - native DWX JPY cross and EUR/JPY momentum proxy.

**Explicitly NOT for:**
- Non-DWX symbols - build and P2 backtests require canonical `.DWX` symbols from `dwx_symbol_matrix.csv`.
- Equity index or commodity symbols - the card is specifically an FX period-momentum strategy.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the V5 skeleton entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `420` |
| Typical hold time | `1 H1 bar` |
| Expected drawdown profile | ATR hard-stop losses with short holding period; high trade count should distribute losses across the FX basket. |
| Regime preference | FX serial-correlation / short-horizon momentum |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `21ef3dfd-fac6-5d5d-b9a0-5ba447992f94`
**Source type:** `book`
**Pointer:** Gregory Zuckerman, "The Man Who Solved the Market", Portfolio/Penguin, 2019, ISBN 9780735217980; official author page listed in the card.
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10948_zuck-fx-period-momo.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-17 | Initial build from card | c6cd5d00-0149-4eeb-b8dd-9b99ce0bd4bb |
