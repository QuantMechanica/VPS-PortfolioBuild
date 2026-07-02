# QM5_12962_wti-jul-prem - Strategy Spec

**EA ID:** QM5_12962
**Slug:** `wti-jul-prem`
**Source:** `artifacts/cards_approved/QM5_12962_wti-jul-prem_card.md`
**Author of this spec:** Codex
**Last revised:** 2026-07-02

## 1. Strategy Logic

This EA implements a low-frequency structural WTI calendar sleeve from the
approved EIA petroleum product seasonality source packet. On each new D1 bar,
it trades only `XTIUSD.DWX`, opens a long position only when the broker-calendar
D1 bar is in July, and uses the prior completed D1 ATR for a hard stop. The
position is flattened on the next D1 bar, at month rollover, or by a one-day
stale-position guard.

The strategy is intentionally not the broad EIA WTI season map, not the
April-to-June driving-season swing card, not the existing single-month WTI
cards, and not any inventory, refinery, spread, ratio, basket, roll, or RSI
commodity sleeve.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_entry_month` | 7 | 7 | Broker-calendar month allowed for entries |
| `strategy_atr_period` | 20 | 14-30 | D1 ATR period for hard stop sizing |
| `strategy_atr_sl_mult` | 2.25 | 1.5-3.0 | ATR multiplier for fixed hard stop |
| `strategy_max_hold_days` | 1 | 1-2 | Stale-position calendar-day guard |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- Primary target: `XTIUSD.DWX`.
- Registered magic slot: slot 0, magic `129620000`.
- The EA explicitly rejects all symbols other than `XTIUSD.DWX`.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 18-22 before Q02 validation.
- Typical hold: one D1 bar unless stopped earlier.
- Regime preference: July peak driving-season crude-oil exposure.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

Source `EIA-WTI-SEASON-2024`: U.S. Energy Information Administration, "Gasoline
price fluctuations", Energy Explained,
https://www.eia.gov/energyexplained/gasoline/price-fluctuations.php. The local
approved source packet records the EIA product-demand seasonality premise and
does not require runtime external data.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.

## Revision History

| Version | Date | Change | Task |
|---|---|---|---|
| v1 | 2026-07-02 | Initial build from approved EIA July WTI seasonality card | QM5_12962 |
