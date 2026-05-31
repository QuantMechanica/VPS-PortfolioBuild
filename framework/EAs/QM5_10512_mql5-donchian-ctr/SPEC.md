# QM5_10512_mql5-donchian-ctr - Strategy Spec

**EA ID:** QM5_10512
**Slug:** `mql5-donchian-ctr`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

The EA evaluates completed H1 bars. It buys when the Donchian upper buffer for bar 1 is greater than the Donchian upper buffer for bar 2, and sells when the Donchian lower buffer for bar 1 is lower than the Donchian lower buffer for bar 2. It allows only one active position for the symbol and magic number, and it blocks new entries until at least 24 hours have elapsed after the previous entry. Exits are handled by a hard stop at the opposite channel side or ATR floor, a 1.5R take-profit, and a close on the opposite Donchian expansion signal.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H1` | `PERIOD_CURRENT` or MT5 timeframe enum | Timeframe used for Donchian and ATR reads. |
| `strategy_donchian_period` | `20` | `2-200` | Number of completed bars used to build the Donchian upper and lower buffers. |
| `strategy_atr_period` | `14` | `1-100` | ATR period used for the stop floor. |
| `strategy_atr_floor_mult` | `1.5` | `0.1-10.0` | Minimum stop distance in ATR multiples. |
| `strategy_tp_r_mult` | `1.5` | `0.1-10.0` | Take-profit distance in R multiples from entry to stop. |
| `strategy_cooldown_hours` | `24` | `0-240` | Minimum elapsed hours after a prior entry before a new entry is allowed. |
| `strategy_allow_shorts` | `true` | `true/false` | Enables the short-side lower-buffer expansion rule. |
| `strategy_max_spread_points` | `0` | `0-10000` | Optional spread ceiling; zero disables this strategy-level spread filter. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed major FX pair with DWX data.
- `GBPUSD.DWX` - card-listed major FX pair with DWX data.
- `USDJPY.DWX` - card-listed major FX pair with DWX data.
- `XAUUSD.DWX` - card-listed liquid metal symbol with DWX data.

**Explicitly NOT for:**
- Non-DWX symbols - build and backtest artifacts must use canonical `.DWX` names.
- Symbols absent from `framework/registry/dwx_symbol_matrix.csv` - no broker/custom-symbol data is available for P2.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `45` |
| Typical hold time | Hours to days, bounded by opposite expansion, hard stop, or 1.5R target |
| Expected drawdown profile | Channel-expansion losses are capped by opposite-channel or ATR-floor stop sizing |
| Regime preference | Donchian channel expansion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** MQL5 CodeBase
**Pointer:** `https://www.mql5.com/en/code/20444`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10512_mql5-donchian-ctr.md`

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
| v1 | 2026-05-28 | Initial build from card | fbf1d663-29e5-4b70-b09f-5bffc0cec12e |
