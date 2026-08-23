# QM5_41005 rework build evidence — 2026-08-23

- Task: `30ceeacd-0647-485a-9886-725af2139d61`
- EA: `QM5_41005_richard-donchian-50day-cta-benchmark`
- Approved card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_41005_richard-donchian-50day-cta-benchmark.md`
- Approved-card SHA-256: `136f86acf0fce1abaaf285591a15880fd935a5c29a51e2c5d762e44b8102e80c`
- Reworked source SHA-256: `7be25a6c0d0eeff3f45f4c2f0728dd22270e8abb4a17aab90ce4f6fab00f1ba6`
- Build artifact: `C:\QM\repo\artifacts\builds\30ceeacd-0647-485a-9886-725af2139d61.json`

## Rework completed

The D1 50-day entry and 20-day opposite-channel exit are now computed once per framework new bar and consumed from cache, with ATR(20) stop distance and ATR(14) spread filtering likewise cached. The EA declares its D1 execution contract, validates strategy inputs, defaults backtests to fixed risk, and applies the approved account-wide 2% daily entry halt, 2.5% daily hard stop, and 5% total-drawdown kill-switch limits. Management and exit handling run before the news entry gate.

## Focused verification

- `validate_spec_doc.py`: PASS.
- `validate_build_guardrails.py --max-news-stale-hours 336`: PASS; five files checked, no findings.
- `validate_symbol_scope.py --fail-on-leak`: `SINGLE_SYMBOL_OK`; zero violations.
- `raw_mq5_quarantine.py check --purpose compile`: `RAW_MQ5_SOURCE_ALLOWED`.
- Registry/set audit: slots `0..3`, magic `410050000..410050003`, and registered symbols `XTIUSD.DWX`, `XAUUSD.DWX`, `SP500.DWX`, `EURUSD.DWX` agree; every backtest set retains `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- Forbidden-literal scan and `git diff --check`: clean.

## Compile interlock

The strict build wrapper refused an ad-hoc compile with `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` because protected T1–T10 processes were active. No process was stopped. The required governed fallback, `farmctl enqueue-compile QM5_41005`, then refused the bound existing build with `EX5_ALREADY_PRESENT` and `BOUND_SETFILE_HASH_EXISTS`; `force_rebuild_authorized` was false. Consequently no fresh EX5 was emitted and no smoke or pipeline verdict is claimed. The existing EX5 is explicitly stale relative to this source (EX5 SHA-256 `12e35b8185adb912bc6023947a5cea20c5c7a540e16542669c924d1aa0b585d6`, modified `2026-08-18T17:23:02Z`).

Disposition: rework is complete and static verification passes; fresh strict compilation remains held by the governed interlock and requires authorized force rebuild.
