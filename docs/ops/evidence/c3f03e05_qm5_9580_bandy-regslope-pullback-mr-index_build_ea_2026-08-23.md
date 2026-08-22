# QM5_9580 Build Evidence - Bandy Regression-Slope Pullback Index Mean Reversion D1

- Task: c3f03e05-3064-4a1e-93ff-097150115ffe (uild_ea, priority 50, assigned to Gemini)
- EA: QM5_9580_bandy-regslope-pullback-mr-index
- Approved card: D:/QM/strategy_farm/artifacts/cards_approved/QM5_9580_bandy-regslope-pullback-mr-index.md
- Source MQ5 SHA-256: 5ec3aa4d8249340e85702365a53d291c120730419971dfe711df6a31e797ccbf
- EX5 SHA-256: 2d3f34e7fec21f31fa29fec2ee447beb296449c51c4e5694fa04ddef2ae4336
- Outcome: BUILD_READY_REVIEW

## Governed Identity and Registries

- EA ID 9580 registered in ramework/registry/ea_id_registry.csv with source 9ef19e06-5ca6-5b35-aa06-b8187aa0e016 and slug andy-regslope-pullback-mr-index.
- 13 active magic rows allocated in ramework/registry/magic_numbers.csv across slots 0..12 (base 95800000):
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
- ramework/include/QM/QM_MagicResolver.mqh contains active 9580 entries across all 13 slots.

## Strategy Implementation

The EA implements Howard Bandy's Regression-Slope Pullback (Index, Long-Only Trend-Pullback) D1 specification:
- Regime Gate: OLS linear regression slope > 0.0 and R2 >= 0.30 over 50 closed D1 bars, combined with Close > SMA(200).
- Pullback Trigger: RSI(2) <= 10.0 on closed D1 bar.
- Entry: Long only at market on next bar open (QM_BUY).
- Exit Signal: RSI(2) >= 70.0 on closed D1 bar.
- Time Stop: Exit after 5 trading days if RSI exit has not triggered.
- Catastrophic Stop Loss: 2.5 * ATR(14).
- Spread filter: skip entry if spread > 0.25 * ATR(14).
- Risk model: ,000 fixed risk per trade in backtest (RISK_FIXED=1000, RISK_PERCENT=0.0).
- Framework conformance: OnTick MAE hook, news compliance gate, Friday close handling, zero-initialized QM_EntryRequest.

## Focused Verification

- alidate_spec_doc.py: PASS (1/1).
- uild_gate_hardening.py: PASS (0 failures, 0 warnings across all D2-D11 checks).
- alidate_build_guardrails.py: PASS (0 findings, 336 hr stale news ceiling).
- alidate_symbol_scope.py --fail-on-leak: PASS (SINGLE_SYMBOL_OK, 0 violations).
- gen_setfile.ps1: 13 setfiles generated in sets/ with strategy parameters and matching uild_hash.
