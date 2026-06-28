# QM5_12742_nnfx-configurable-engine - Strategy Spec

**EA ID:** QM5_12742
**Slug:** `nnfx-configurable-engine`
**Source:** `nnfx-vp-canonical-2026-06-12` (see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_12742_nnfx-configurable-engine.md`)
**Author of this spec:** Codex
**Last revised:** 2026-06-28

---

## 1. Strategy Logic

This EA mechanises the No Nonsense Forex slot model as a deterministic, configurable trend-following engine. Each closed bar is evaluated through five selectable slots: baseline, primary confirmation, optional secondary confirmation, volume/volatility gate, and exit mode.

Default long entry:

- Price has crossed above the selected baseline within the last `nnfx_entry_window_bars`.
- The latest closed bar remains above the baseline.
- The close is no farther than `nnfx_proximity_atr_mult` ATR from the baseline.
- The selected C1 confirmation is bullish.
- C2 is either OFF or bullish.
- The selected volume gate passes.

Default short entry is the symmetric inverse. Initial stop is `nnfx_stop_atr_mult` ATR from entry. The default management closes half the position at `nnfx_partial_atr_mult` ATR profit, moves the runner to breakeven, and exits on the selected exit mode. The default exit mode is PSAR reversal; alternatives are C1 flip, Kijun recross, or Chandelier stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_timeframe` | `PERIOD_D1` | `PERIOD_H4` or `PERIOD_D1` | Signal timeframe; chart period must match. |
| `nnfx_baseline` | `NNFX_BASELINE_HMA` | KIJUN, HMA, T3, ALMA, MCGINLEY, ZLSMA, EMA | Baseline trend filter and recent-cross trigger. |
| `nnfx_c1` | `NNFX_C1_STC` | SUPERTREND, SSL, AROON, VORTEX, STC, QQE, FISHER | Primary confirmation slot. |
| `nnfx_c2` | `NNFX_C2_OFF` | OFF, VORTEX, AROON, TRIX | Optional secondary confirmation; OFF keeps the lean cadence profile. |
| `nnfx_volume` | `NNFX_VOLUME_ATR_EXPANSION` | ATR_EXPANSION, ADX_RISING, CMF, WAE | Volume or volatility gate. |
| `nnfx_exit` | `NNFX_EXIT_PSAR` | PSAR, C1_FLIP, KIJUN_RECROSS, CHANDELIER | Strategic exit trigger for the runner. |
| `nnfx_entry_window_bars` | `7` | `1-30` | Maximum closed bars since baseline cross. |
| `nnfx_proximity_atr_mult` | `1.0` | `0.1-5.0` | Maximum distance from baseline at entry, in ATR units. |
| `nnfx_stop_atr_mult` | `1.5` | `0.5-5.0` | Initial stop distance in ATR units. |
| `nnfx_partial_atr_mult` | `1.0` | `0.5-5.0` | Profit distance for default half close. |
| `nnfx_atr_period` | `14` | `5-100` | ATR period for risk, proximity, and ATR expansion. |
| `nnfx_baseline_period` | `20` | `5-200` | Main baseline period. |
| `nnfx_c1_period` | `14` | `5-100` | Primary confirmation period. |
| `nnfx_c2_period` | `14` | `5-100` | Secondary confirmation period. |
| `nnfx_volume_period` | `20` | `5-100` | Volume gate lookback. |
| `nnfx_max_spread_points` | `80` | `1-500` | Spread ceiling in points. |
| `nnfx_partial_close_enabled` | `true` | `true/false` | Enables half close at the partial target. |
| `nnfx_move_to_be_enabled` | `true` | `true/false` | Moves runner stop to breakeven after partial target. |

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX` - FX major; diversity probe for commission-sensitive NNFX.
- `GBPUSD.DWX` - FX major; independent trend/cost profile.
- `USDJPY.DWX` - FX major; rate-sensitive trend profile.
- `AUDUSD.DWX` - FX major; commodity-linked trend profile.
- `XTIUSD.DWX` - crude oil; cost-aware trend candidate outside the certified book.
- `XNGUSD.DWX` - natural gas; high-volatility energy trend candidate.
- `XAUUSD.DWX` - gold; historically better cost fit for slower trend systems.
- `XAGUSD.DWX` - silver; correlated but distinct metal trend candidate.
- `NDX.DWX` - index trend candidate.
- `SP500.DWX` - broad index trend candidate.
- `GDAXI.DWX` - European index trend candidate.
- `WS30.DWX` - Dow index trend candidate.

**Explicitly NOT for:**

- Non-`.DWX` symbols - the V5 farm and magic registry are built around Darwinex Zero `.DWX` symbols.
- Intraday scalping symbols/timeframes below H4 - the source model is low-frequency, closed-bar trend following.
- Symbols without stable D1/H4 history - Q02/Q04 require enough closed-bar history for gross and walk-forward gates.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` after management/exit checks; entries are closed-bar only |

The EA also exposes `strategy_timeframe=PERIOD_H4` for later curated setfile grids, but the initial V5 backtest setfiles are D1.

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 15-40; card expectation 25 |
| Typical hold time | days to weeks |
| Expected drawdown profile | trend-following whipsaws during range regimes, ATR-bounded per trade |
| Regime preference | trend / volatility expansion |
| Win rate target (qualitative) | medium-low, with asymmetric runners |

The farm objective is not another full-stack NNFX cadence-starved test. This build prioritises lean combinations, especially C2 OFF plus faster confirmations, to determine whether the Q04 wall was caused by over-filtered full-stack logic rather than by the component family itself.

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `nnfx-vp-canonical-2026-06-12`
**Source type:** reputable published trading methodology / OWNER-approved card
**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_12742_nnfx-configurable-engine.md`
**R1-R4 verdict (Q00):** all PASS; see approved card artifact.

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
| v1 | 2026-06-28 | Initial build from approved strategy card | build commit pending |
