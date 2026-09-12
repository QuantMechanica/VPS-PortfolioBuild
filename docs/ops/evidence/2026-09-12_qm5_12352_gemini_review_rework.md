# QM5_12352 Gemini build review rework

Date: 2026-09-12

Router review task: `23a6f9a0-0044-428d-af46-4774e028f60d`

Source build task: `5146007d-b1b8-4acf-b239-1ed29e56d16f`

EA: `QM5_12352_orev-bb-rsi`

## Decision

The governed build preflight fails on exact card/registry universe agreement, before any zero-trade mechanics diagnosis or source repair is authorized.

The runtime approved card exists at `D:/QM/strategy_farm/artifacts/cards_approved/QM5_12352_orev-bb-rsi.md`, has `g0_status: APPROVED`, and has SHA-256 `6d4bbbcb199988d0d12e7fc499791aee0b3df78690b904127ab7482beb4b60d3`. `ea_id_registry.csv` contains the active 12352 row with slug `orev-bb-rsi` and the card's source ID.

The card's exact target universe is EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX, **GER40.DWX**, NDX.DWX, and WS30.DWX. The active magic registry and setfiles instead allocate slot 4 to **GDAXI.DWX**; there is no GER40.DWX magic row or setfile. The other six rows agree. This is a deterministic authority/setup mismatch, not permission to treat the two names as interchangeable.

## Zero-trade disposition

The prior review records a zero-trade smoke plus blocked build result. Under the zero-trade recovery ordering, an already-proven setup mismatch must be repaired before inspecting or altering strategy mechanics. Accordingly, this review did not relax RSI/Bollinger/trend thresholds, did not add diagnostics, and did not rerun a test. The historical zero-trade outcome remains neither PASS nor a strategy rejection.

The current MQ5 is intentionally byte-unchanged at 8,276 bytes, SHA-256 `5aa52c4ee694b8eb6ebbe2ddeef734b8e828d18f00c7e608378d193df7a8ab11`. No new `.ex5` or build verdict is claimed.

## Required unblock

1. OWNER/Strategy Governance must decide the approved contract identity: amend the card to canonical `GDAXI.DWX`, or allocate the exact approved `GER40.DWX` only if it is a validated registered custom symbol.
2. The governed registry writer must make the magic rows and resolver agree with that OWNER decision; Development must produce the exact matching setfile universe.
3. Re-run build preflight. Only after it passes may the zero-trade workflow bind and classify a fresh test at harness/setup/entry/order layers.
4. Any implementation-only repair must preserve the approved entry/exit economics, compile through `COMPILE_EA`, and return to Codex review. No pipeline phase may rely on the old Gemini PASS claim.

No registry/card/source/setfile was modified, no compile was requested, no terminal was started, no backtest was run or interrupted, and neither `T_Live` nor AutoTrading was touched.

RESULT: BLOCKED_PRECHECK — approved GER40.DWX conflicts with allocated GDAXI.DWX; zero-trade recovery and build rework cannot proceed until OWNER plus governed registry-writer repair.
