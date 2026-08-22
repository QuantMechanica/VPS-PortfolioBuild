# QM5_9579 Build Evidence - Bandy ATR-Channel Breakout Trend D1

- Task: 34ffb386-bb5b-4c08-8319-c8b893fc50cc (uild_ea, priority 50, assigned to Gemini)
- EA: QM5_9579_bandy-atr-channel-breakout-trend
- Approved card: D:/QM/strategy_farm/artifacts/cards_approved/QM5_9579_bandy-atr-channel-breakout-trend.md
- Source MQ5 SHA-256: dde31d552fb197f3d16f311353b553d7956cb90a5b84ef2efb79cddf1f7fdd44
- EX5 SHA-256: 35c47c98faa8e7b5dfdeb466b91556136c704f869a00a7b1ded767e3f4ceff51
- Outcome: BUILD_READY_REVIEW

## Governed Identity and Registries

- EA ID 9579 registered in ramework/registry/ea_id_registry.csv with source 9ef19e06-5ca6-5b35-aa06-b8187aa0e016 and slug andy-atr-channel-breakout-trend.
- 13 active magic rows allocated in ramework/registry/magic_numbers.csv across slots 0..12 (base 95790000):
  - 0: GDAXI.DWX
  - 1: NDX.DWX
  - 2: SP500.DWX
  - 3: UK100.DWX
  - 4: WS30.DWX
  - 5: XAUUSD.DWX
  - 6: EURUSD.DWX
  - 7: GBPUSD.DWX
  - 8: USDJPY.DWX
  - 9: USDCHF.DWX
  - 10: AUDUSD.DWX
  - 11: USDCAD.DWX
  - 12: NZDUSD.DWX
- ramework/include/QM/QM_MagicResolver.mqh contains active 9579 entries across all 13 slots.

## Strategy Implementation

The EA implements Howard Bandy's ATR-Channel Breakout (Trend, Long/Short) D1 specification:
- Channel calculation on closed D1 bars: ref = SMA(close, 20), upper = ref + 1.5 * ATR(14), lower = ref - 1.5 * ATR(14).
- Entry signal: close > upper enters BUY; close < lower enters SELL on next bar open.
- Trailing Stop: ATR chandelier trailing stop ratcheted each closed D1 bar to close - 2.0 * ATR(14) (long) or close + 2.0 * ATR(14) (short).
- Time-stop: 30 daily bars maximum holding period.
- Catastrophic backstop: 5.0 * ATR(14).
- Spread filter: skip entry if spread > 0.25 * ATR(14).
- Risk model: ,000 fixed risk per trade in backtest (RISK_FIXED=1000, RISK_PERCENT=0.0).
- Framework conformance: OnTick MAE hook, news compliance gate, Friday close handling, zero-initialized QM_EntryRequest.

## Focused Verification

- alidate_spec_doc.py: PASS (1/1).
- uild_gate_hardening.py: PASS (0 failures, 0 warnings across all D2-D11 checks).
- alidate_build_guardrails.py: PASS (0 findings, 336 hr stale news ceiling).
- alidate_symbol_scope.py --fail-on-leak: PASS (SINGLE_SYMBOL_OK, 0 violations).
- gen_setfile.ps1: 13 setfiles generated in sets/ with strategy parameters and matching uild_hash.
