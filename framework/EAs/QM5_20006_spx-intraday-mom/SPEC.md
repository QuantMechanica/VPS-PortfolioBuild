# QM5_20006_spx-intraday-mom — Strategy Spec

**EA ID:** QM5_20006
**Slug:** `spx-intraday-mom`
**Source:** `FTMO_V3_ROLE3_SOURCING_2026-07-19` (see `artifacts/cards_approved/QM5_20006_spx-intraday-mom.md`)
**Author of this spec:** Claude (headless build lane)
**Last revised:** 2026-07-19

---

## 1. Strategy Logic

At 22:30 broker time (the open of the S&P 500's last cash-session half-hour), the EA
computes the first-half-hour return `r_fh = Close(17:00 broker) / PrevSessionClose(23:00
broker) - 1` — the first half-hour close divided by the prior session's cash close,
including the overnight gap. If `|r_fh|` clears a magnitude filter (`>= vol_mult *
median(|r_fh|)` over the trailing `vol_lookback` sessions), the EA opens a market
position in the direction of `r_fh` (long if positive, short if negative). The position
carries only a non-alpha catastrophe stop (`stop_atr_mult * ATR(M30,14)`) and is flattened
by a hard time exit at 22:59 broker — always flat overnight. Fridays are skipped
entirely. Source: intraday momentum from late-informed trading and infrequent-rebalancing
flow concentration (Gao/Han/Li/Zhou 2018 JFE; Bogousslavsky 2016 JF).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_vol_mult` | 0.5 | 0.0–1.0 | Magnitude-filter multiplier vs the trailing median \|r_fh\|. |
| `strategy_vol_lookback` | 20 | 10–30 | Sessions in the trailing median baseline. |
| `strategy_stop_atr_mult` | 2.0 | 1.5–3.0 | Catastrophe-stop ATR(M30,14) multiplier (non-alpha). |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT, qm_news_mode,
> qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*) are documented in
> `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` — the card's research/backtest symbol (S&P 500 cash-session microstructure
  effect); backtest-only availability is acceptable per card frontmatter
  `single_symbol_only: true`.

**Explicitly NOT for:**
- `NDX.DWX` / `WS30.DWX` — card names NDX only as a robustness cross-check, not a
  registered build target; frontmatter `single_symbol_only: true` forbids expansion at
  build time (see `open_questions`).

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~185 (150-220/yr per card, magnitude-filtered, Fridays skipped) |
| Typical hold time | 29 minutes (22:30-22:59 broker) |
| Expected drawdown profile | ~8% (card `expected_dd_pct`) |
| Regime preference | intraday momentum, stronger on high-volatility/high-volume days |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

**Source ID:** `FTMO_V3_ROLE3_SOURCING_2026-07-19`
**Source type:** paper
**Pointer:** Gao/Han/Li/Zhou (2018) JFE 129:394-414 DOI 10.1016/j.jfineco.2018.05.009;
Zarattini/Aziz/Barbon (2024) SFI 24-97 SSRN 4824172; Bogousslavsky (2016) JF DOI
10.1111/jofi.12480
**R1–R4 verdict (Q00):** all PASS — see `artifacts/cards_approved/QM5_20006_spx-intraday-mom.md`

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
| v1 | 2026-07-19 | Initial build from card | task ec12b037-2775-444b-97d2-d85fd84bbbee |
