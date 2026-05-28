# QM5_1164 Unger Gold Donchian Bias

## Scope
- Strategy Card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1164_unger-gold-donchian-bias.md`
- EA label: `QM5_1164_unger-gold-donchian-bias`
- Framework: QuantMechanica V5
- Build only: no backtests or pipeline phases.

## Mapping
- Universe: `XAUUSD.DWX`.
- Timeframe: `M15`.
- Entry: completed M15 close breaks the prior Donchian channel.
- Long bias window: `08:00-12:00` New York time.
- Short bias window: `20:00-02:00` New York time.
- Position limit: one open position per magic, one entry per bias window.
- Stop: `1.5 * ATR(14, M15)`.
- Take profit: none.
- Exit: time-based flat by the active window end.
- News: high-impact DXZ skip-day default, matching the Card's macro-release caution.

## Risk
- Backtest setfiles use fixed risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Live setfiles use percentage risk: `RISK_PERCENT=0.25`, `RISK_FIXED=0`.

## Registry
- `ea_id=1164`
- `symbol_slot=0`
- `symbol=XAUUSD.DWX`
- `magic=11640000`

## Validation
- `framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_1164_unger-gold-donchian-bias/QM5_1164_unger-gold-donchian-bias.mq5 -Strict`
- `framework/scripts/build_check.ps1 -EALabel QM5_1164_unger-gold-donchian-bias -Strict`
