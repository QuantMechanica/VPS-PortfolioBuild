# QM5_11585_neely-weller-channel-buffer-band-d1 - Strategy Spec

**EA ID:** QM5_11585
**Slug:** `neely-weller-channel-buffer-band-d1`
**Source:** `577eb0aa-7880-5c0a-a8f9-56cd126c19f9`
**Author of this spec:** Codex
**Last revised:** 2026-06-28

---

## 1. Strategy Logic

This EA trades the Neely-Weller daily foreign-exchange channel rule with a buffer band. On each closed D1 bar it compares the latest close to the highest and lowest closes from the prior channel window, widened by the configured buffer fraction. A close above the buffered high opens or flips long; a close below the buffered low opens or flips short. Open trades carry an ATR-based safety stop and otherwise exit on an opposite buffered-channel break.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_channel_len` | 20 | 5-40 | Number of prior D1 closes used for the channel high/low. |
| `strategy_buffer_band` | 0.001 | 0.0005-0.003 | Fractional buffer beyond the channel edge before a break is valid. |
| `strategy_atr_period` | 14 | 2+ | ATR period for the protective stop. |
| `strategy_sl_atr_mult` | 3.0 | 1.0+ | ATR multiple used for the safety stop. |
| `strategy_spread_pct_of_stop` | 15.0 | 0+ | Maximum modeled spread as a percent of stop distance; zero spread passes. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - major FX pair from the approved R3 basket.
- `GBPUSD.DWX` - major FX pair from the approved R3 basket.
- `USDJPY.DWX` - major FX pair from the approved R3 basket.
- `USDCHF.DWX` - major FX pair from the approved R3 basket.
- `AUDUSD.DWX` - major FX pair from the approved R3 basket.
- `NZDUSD.DWX` - major FX pair from the approved R3 basket.

**Explicitly NOT for:**
- `GER40.DWX` / `FRA40.DWX` - not in the approved card basket and not canonical DWX symbols in this repo.
- `XAUUSD.DWX` / `XTIUSD.DWX` - not part of the Neely-Weller FX-major channel-rule test basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 10 |
| Typical hold time | 5-40 trading days, depending on channel flips |
| Expected drawdown profile | Trend-following FX drawdowns during range-bound whipsaw periods |
| Regime preference | Daily FX trend continuation after buffered channel breaks |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `577eb0aa-7880-5c0a-a8f9-56cd126c19f9`
**Source type:** paper
**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_11585_neely-weller-channel-buffer-band-d1.md`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11585_neely-weller-channel-buffer-band-d1.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV to mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-28 | Complete partial build metadata for Q02 enqueue | Added SPEC, activated registry/magic rows, and repaired setfile-ready build infra. |
