# QM5_1355 williams-vix-fix-fx-h4 — Claude code review

- **Task:** review_ea `860da8d2-37db-4218-91f1-5c95b10897e4` (source_agent: gemini, source_execution_backend: agy)
- **Card:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1355_williams-vix-fix-fx-h4.md`
- **Reviewer:** Claude, 2026-08-10
- **Verdict:** NEEDS_FIX (two independent defects found; left in REVIEW per Hard Rule "Codex review is mandatory before acceptance" — not self-approved to APPROVED/PIPELINE)

## Mechanical verification (independently re-run, not trusted from source_verdict)

- `compile_ea.py --ea-id 1355 --force`: COMPILED, 0 errors / 0 warnings.
- `validate_build_guardrails.py`: PASS, 0 findings (9 files checked).
- `build_check.ps1 -EALabel QM5_1355_williams-vix-fix-fx-h4 -SkipCompile`: PASS, 0 failures / 0 warnings.
- 8 backtest setfiles present for all card `target_symbols` (NDX/WS30/GDAXI/UK100/SP500/XAUUSD/EURUSD/GBPUSD.DWX), RISK_FIXED=1000 / RISK_PERCENT=0 confirmed in setfile content.

## Defect 1 (confirmed independently, matches concurrent claude session's finding): unused strategy inputs, hardcoded literals

`strategy_wvf_lookback` (=22), `strategy_wvf_ma_period` (=20), `strategy_wvf_range_pct` (=0.85)
are declared as `input` at QM5_1355_williams-vix-fix-fx-h4.mq5:36-39 but never referenced anywhere
else in the file:

- `WVF(int shift)` hardcodes `for(int i = 0; i < 22; i++)` (line 78) instead of
  `strategy_wvf_lookback`.
- `GetWvfStats(...)` hardcodes `for(int i = 0; i < 20; i++)` twice (lines 92, 100) and
  `sd = MathSqrt(sum_sq / 20.0)` (line 104) instead of `strategy_wvf_ma_period`.
- `GetWvfStats(...)` hardcodes `range_high = 0.85 * max_wvf_51;` (line 112) instead of
  `strategy_wvf_range_pct`.

Values match the input defaults today, so P0-baseline behavior is correct, but any Q08
neighborhood-parameter-stability sweep or P3 grid that varies these three inputs would
have **zero actual effect** on the compiled logic — invalidating that gate's evidence
for this EA.

## Defect 2 (new, found in this review): stop-loss anchored to the wrong bar

Card `Stop Loss` section: `min(low[t−1], entry − 1.5 × ATR(14, H4))`, with the explicit
clarification "the spike-bar low is the structural invalidation level." The card's
entry logic (Mechanik + Entry sections) establishes `t` as the decay/confirmation bar
and `t−1` as the spike bar (the bar where `WVF > max(Upper, Range_high)` fires; entry
requires `WVF_t < WVF_{t-1}` decay confirmation the following bar).

The EA's variable-to-bar mapping, verified against its own entry logic:
- `g_wvf_1 = WVF(1)` → bar `t` (decay/confirmation bar).
- `g_wvf_2 = WVF(2)` → bar `t-1` (spike bar) — confirmed by
  `Strategy_EntrySignal`'s spike-trigger check using `g_wvf_2`/`g_wvf_ma_2`/`g_wvf_sd_2`/
  `g_wvf_range_high_2` (QM5_1355...mq5:185-188), and the local-max check
  `g_wvf_2 <= wvf3` requiring `WVF[t-1] > WVF[t-2]` (line 191).

Given that mapping, the "spike-bar low" the card calls for is `iLow(_Symbol, PERIOD_H4, 2)`
(shift 2, bar `t-1`). The implementation instead uses:

```
double low1 = iLow(_Symbol, PERIOD_H4, 1); // shift=1 == bar t, the DECAY bar, not the spike bar
double sl = MathMin(low1, ask_now - strategy_sl_atr_mult * g_atr_1);
```

(QM5_1355_williams-vix-fix-fx-h4.mq5:194-195) — shift 1, i.e. bar `t`'s low, not bar
`t-1`'s low.

**Why this matters:** in the intended spike-then-decay pattern, the spike bar (`t-1`)
is the sell-off extreme (that is what makes `WVF` spike — the low is far below the
recent highest close). The decay/confirmation bar (`t`) is already recovering (its own
entry condition requires `close[t] > open[t]`, a bullish candle) and therefore
typically prints a *higher* low than the spike bar. Using `low[t]` instead of
`low[t-1]` produces a tighter (less protective) stop than the card's designed
"structural invalidation level" in the common case, changing the trade's realized R
distribution and stop-out frequency relative to what R2/R4 were evaluated against.
The `MathMin(..., entry - 1.5*ATR)` fallback softens but does not eliminate the
deviation — whichever anchor is lower still wins, and `low[t]` frequently beats
`entry - 1.5*ATR` in numeric terms even though it isn't the bar the card specifies.

**Fix:** change `iLow(_Symbol, PERIOD_H4, 1)` to `iLow(_Symbol, PERIOD_H4, 2)` at
QM5_1355_williams-vix-fix-fx-h4.mq5:194.

## Card-fidelity checks that passed (no defect)

- WVF formula (22-bar highest-close window, current-bar low) matches card exactly
  (verified index arithmetic: `close[shift..shift+21]` = `close[t-21..t]`).
- Bollinger-style spike bands (`WVF_MA`, `WVF_SD` over 20 bars, `Upper = MA + 2*SD`,
  `Range_high = 0.85 * max(WVF, 51 bars)`) match card formulas.
- Spike-then-decay entry state machine correctly resolves the card's internally
  ambiguous prose (point 1 vs point 2 read literally contradict each other on which
  bar is "the spike"); the implementation's bar mapping is consistent with the card's
  own parenthetical clarification and with the SL section's "spike-bar low" language
  (which is exactly how Defect 2 above was cross-checked).
- EMA200 macro-bias filter, bullish confirmation candle, one-position-per-magic,
  one-spike-cycle re-entry suppression, TP1 (1.5x ATR partial), TP2 (3.0x ATR full),
  re-spike loss-prevention exit (within 5 bars), 24-bar time-stop, session window
  06:00-22:00, spread guard (EMA proxy for "20-bar median" — reasonable substitution,
  not flagged as a defect) all match the card.
