# QM5_12847_turn-of-month-sp500 — Strategy Spec

**EA ID:** QM5_12847
**Slug:** `turn-of-month-sp500`
**Source:** `quantified-turn-of-month-20260701` (see `docs/research/YOUTUBE_STRATEGY_SYNTHESIS_BATCH3_2026-07-01`)
**Author of this spec:** Claude
**Last revised:** 2026-07-01

---

## 1. Strategy Logic

Long-only D1 seasonal strategy exploiting the Turn-of-the-Month (Ultimo) effect: equity indices exhibit persistent upward bias around the month boundary due to mechanical month-end fund inflows, salary/retirement contributions, and institutional window-dressing.

Entry fires at the close of the Nth-last trading day of the calendar month (default N=5), counting actual D1 bars within the calendar month rather than calendar days. Exit fires at the close of the Mth trading day of the following calendar month (default M=3). An optional 200-bar D1 SMA gate restricts entries to bull-regime environments (price above SMA). One trade per calendar month; a 3×ATR(14) protective stop anchors lot sizing but the primary exit is the time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `entry_td_from_end` | 5 | 4–6 | Nth-last trading day of month to enter; counts actual D1 bars (not calendar days) |
| `exit_td_of_next` | 3 | 2–4 | Mth trading day of the NEXT calendar month to close the position |
| `regime_sma_period` | 200 | 100–300 | SMA period (D1) for the bull-regime filter; only enter when close > SMA |
| `use_regime_filter` | true | on/off | Toggle the 200-SMA regime gate on or off |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` — canonical S&P 500 instrument; primary source for the documented Ultimo edge; backtest-only (broker does not route orders)
- `NDX.DWX` — Nasdaq 100; live-tradeable transfer instrument; same month-end flow driver; strong historical TOM effect
- `WS30.DWX` — Dow Jones 30; live-tradeable transfer instrument; correlated month-end seasonal pattern
- `GDAXI.DWX` — DAX 40; global multi-index expansion; European month-end flows are documented, though effect may differ

**Explicitly NOT for:**
- Forex pairs — month-end flows are equity-index specific; no structural TOM effect in FX
- Commodities — no comparable month-end institutional-flow driver

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
| Trades / year / symbol | ~12 (one per calendar month; fewer if regime filter blocks) |
| Typical hold time | ~6–8 trading days (Nth-last of month + first M days of next month) |
| Expected drawdown profile | Low; short hold time, low-commission index class |
| Regime preference | Trending / bull market (gated by 200 SMA) |
| Win rate target (qualitative) | medium–high (edge is directional with tailwind from flows) |

---

## 6. Source Citation

**Source ID:** `quantified-turn-of-month-20260701`
**Source type:** video / synthesis
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
