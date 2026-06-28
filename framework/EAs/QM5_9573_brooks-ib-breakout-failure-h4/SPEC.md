# QM5_9573_brooks-ib-breakout-failure-h4 — Strategy Spec

**EA ID:** QM5_9573
**Slug:** `brooks-ib-breakout-failure-h4`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Author of this spec:** Codex
**Last revised:** 2026-06-28

---

## 1. Strategy Logic

This EA trades failed H4 breakouts from a single inside-bar compression. A mother bar must have range between 0.8 and 2.5 ATR(14), followed by a strict inside bar whose range is at most 65% of the mother range. If the next bar breaks one side of the mother by 0.10 ATR and then the same bar or the next closed bar fails back inside the mother by 0.05 ATR while closing in the failure half of its range, the EA fades the breakout at the next bar open.

For failed up-breaks it sells, sets the stop above the breakout/failure highs plus 0.3 ATR, targets the mother low, and caps the target at 2.5R. Failed down-breaks mirror this logic. Any still-open position exits after 10 H4 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_atr_period` | 14 | 5-50 | ATR period used for mother-bar, breakout, failure, spread, and stop buffers. |
| `strategy_mother_atr_min` | 0.80 | 0.1-5.0 | Minimum mother-bar range as a multiple of ATR. |
| `strategy_mother_atr_max` | 2.50 | 0.5-8.0 | Maximum mother-bar range as a multiple of ATR to reject spike aftermaths. |
| `strategy_inside_range_max` | 0.65 | 0.1-0.95 | Maximum inside-bar range as a fraction of mother-bar range. |
| `strategy_break_atr_mult` | 0.10 | 0.01-1.0 | ATR buffer required beyond the mother high/low to count as a breakout. |
| `strategy_failure_atr_mult` | 0.05 | 0.01-1.0 | ATR buffer required back inside the mother bar for failure confirmation. |
| `strategy_sl_atr_mult` | 0.30 | 0.05-3.0 | Stop buffer beyond the breakout/failure extreme. |
| `strategy_spread_atr_mult` | 0.20 | 0.01-1.0 | Skip entries when live spread exceeds this fraction of ATR. |
| `strategy_max_rr` | 2.50 | 0.5-10.0 | Maximum reward-to-risk distance for the capped target. |
| `strategy_time_stop_h4_bars` | 10 | 1-100 | Exit any open position after this many H4 bars. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `AUDUSD.DWX`, `USDCAD.DWX`, `USDCHF.DWX`, `NZDUSD.DWX` — liquid FX majors from the approved card and verified DWX matrix.
- `XAUUSD.DWX`, `XTIUSD.DWX` — metal and oil CFDs from the approved card and verified DWX matrix.
- `GDAXI.DWX`, `NDX.DWX`, `WS30.DWX`, `UK100.DWX` — index CFDs from the approved card and verified DWX matrix.

**Explicitly NOT for:**
- `FRA40.DWX`, `JP225.DWX` — present on the approved card but not registered in `framework/registry/dwx_symbol_matrix.csv` at build time.
- Non-DWX symbols — magic and symbol-slot mapping are registered only for the verified `.DWX` subset.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the V5 framework |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 30 |
| Typical hold time | 4-40 hours |
| Expected drawdown profile | Burst losses during persistent trend continuation after false failure closes. |
| Regime preference | Mean-reverting failed breakout after inside-bar compression. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** forum / book lineage
**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9573_brooks-ib-breakout-failure-h4.md`
**R1-R4 verdict (Q00):** all PASS per approved strategy card

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio, typically 0.3% - 0.5% |

ENV to mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-28 | Initial build from approved card | build commit pending |
