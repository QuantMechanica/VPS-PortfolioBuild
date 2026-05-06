# V5 Symbol Commission And Swap Baseline

Status: Drafted for QM-00044 (2026-05-06).

Scope: canonical `.DWX` symbols used by V5 baseline backtests.

Hard-rule notes:
- No fantasy numbers: commission figures below are copied from MT5 tester group file.
- Swap values are symbol-contract properties (`SYMBOL_SWAP_LONG`, `SYMBOL_SWAP_SHORT`) and must be captured from MT5 runtime per symbol before P2 sign-off.

Commission source file: `D:/QM/mt5/T1/MQL5/Profiles/Tester/Groups/Darwinex-Live_real.txt`
Symbol registry source: `C:/QM/repo/framework/registry/dwx_symbol_matrix.csv`

| symbol | asset_class | custom path (registry) | commission matcher | commission value | mode | swap source status |
|---|---|---|---|---:|---|---|
| AUDCAD.DWX | forex | `` | `Custom\Forex\*` | 2.5000 | `CommissionMode=1` | Pending MT5 runtime snapshot (`SYMBOL_SWAP_LONG/SHORT`) |
| AUDCHF.DWX | forex | `` | `Custom\Forex\*` | 2.5000 | `CommissionMode=1` | Pending MT5 runtime snapshot (`SYMBOL_SWAP_LONG/SHORT`) |
| AUDJPY.DWX | forex | `` | `Custom\Forex\*` | 2.5000 | `CommissionMode=1` | Pending MT5 runtime snapshot (`SYMBOL_SWAP_LONG/SHORT`) |
| AUDNZD.DWX | forex | `` | `Custom\Forex\*` | 2.5000 | `CommissionMode=1` | Pending MT5 runtime snapshot (`SYMBOL_SWAP_LONG/SHORT`) |
| AUDUSD.DWX | forex | `` | `Custom\Forex\*` | 2.5000 | `CommissionMode=1` | Pending MT5 runtime snapshot (`SYMBOL_SWAP_LONG/SHORT`) |
| CADCHF.DWX | forex | `` | `Custom\Forex\*` | 2.5000 | `CommissionMode=1` | Pending MT5 runtime snapshot (`SYMBOL_SWAP_LONG/SHORT`) |
| CADJPY.DWX | forex | `` | `Custom\Forex\*` | 2.5000 | `CommissionMode=1` | Pending MT5 runtime snapshot (`SYMBOL_SWAP_LONG/SHORT`) |
| CHFJPY.DWX | forex | `` | `Custom\Forex\*` | 2.5000 | `CommissionMode=1` | Pending MT5 runtime snapshot (`SYMBOL_SWAP_LONG/SHORT`) |
| EURAUD.DWX | forex | `` | `Custom\Forex\*` | 2.5000 | `CommissionMode=1` | Pending MT5 runtime snapshot (`SYMBOL_SWAP_LONG/SHORT`) |
| EURCAD.DWX | forex | `` | `Custom\Forex\*` | 2.5000 | `CommissionMode=1` | Pending MT5 runtime snapshot (`SYMBOL_SWAP_LONG/SHORT`) |
| EURCHF.DWX | forex | `` | `Custom\Forex\*` | 2.5000 | `CommissionMode=1` | Pending MT5 runtime snapshot (`SYMBOL_SWAP_LONG/SHORT`) |
| EURGBP.DWX | forex | `` | `Custom\Forex\*` | 2.5000 | `CommissionMode=1` | Pending MT5 runtime snapshot (`SYMBOL_SWAP_LONG/SHORT`) |
| EURJPY.DWX | forex | `` | `Custom\Forex\*` | 2.5000 | `CommissionMode=1` | Pending MT5 runtime snapshot (`SYMBOL_SWAP_LONG/SHORT`) |
| EURNZD.DWX | forex | `` | `Custom\Forex\*` | 2.5000 | `CommissionMode=1` | Pending MT5 runtime snapshot (`SYMBOL_SWAP_LONG/SHORT`) |
| EURUSD.DWX | forex | `` | `Custom\Forex\*` | 2.5000 | `CommissionMode=1` | Pending MT5 runtime snapshot (`SYMBOL_SWAP_LONG/SHORT`) |
| GBPAUD.DWX | forex | `Custom/Forex/GBPAUD.DWX` | `Custom\Forex\*` | 2.5000 | `CommissionMode=1` | Pending MT5 runtime snapshot (`SYMBOL_SWAP_LONG/SHORT`) |
| GBPCAD.DWX | forex | `Custom/Forex/GBPCAD.DWX` | `Custom\Forex\*` | 2.5000 | `CommissionMode=1` | Pending MT5 runtime snapshot (`SYMBOL_SWAP_LONG/SHORT`) |
| GBPCHF.DWX | forex | `Custom/Forex/GBPCHF.DWX` | `Custom\Forex\*` | 2.5000 | `CommissionMode=1` | Pending MT5 runtime snapshot (`SYMBOL_SWAP_LONG/SHORT`) |
| GBPJPY.DWX | forex | `Custom/Forex/GBPJPY.DWX` | `Custom\Forex\*` | 2.5000 | `CommissionMode=1` | Pending MT5 runtime snapshot (`SYMBOL_SWAP_LONG/SHORT`) |
| GBPNZD.DWX | forex | `Custom/Forex/GBPNZD.DWX` | `Custom\Forex\*` | 2.5000 | `CommissionMode=1` | Pending MT5 runtime snapshot (`SYMBOL_SWAP_LONG/SHORT`) |
| GBPUSD.DWX | forex | `Custom/Forex/GBPUSD.DWX` | `Custom\Forex\*` | 2.5000 | `CommissionMode=1` | Pending MT5 runtime snapshot (`SYMBOL_SWAP_LONG/SHORT`) |
| GDAXI.DWX | indices | `Custom/Indices/Index DAX/GDAXI.DWX` | `Custom\Indices\Index DAX\*` | 2.7500 | `CommissionMode=3` | Pending MT5 runtime snapshot (`SYMBOL_SWAP_LONG/SHORT`) |
| NDX.DWX | indices | `Custom/Indices/Index 3/NDX.DWX` | `Custom\Indices\Index 3\*` | 2.7500 | `CommissionMode=3` | Pending MT5 runtime snapshot (`SYMBOL_SWAP_LONG/SHORT`) |
| NZDCAD.DWX | forex | `Custom/Forex/NZDCAD.DWX` | `Custom\Forex\*` | 2.5000 | `CommissionMode=1` | Pending MT5 runtime snapshot (`SYMBOL_SWAP_LONG/SHORT`) |
| NZDCHF.DWX | forex | `Custom/Forex/NZDCHF.DWX` | `Custom\Forex\*` | 2.5000 | `CommissionMode=1` | Pending MT5 runtime snapshot (`SYMBOL_SWAP_LONG/SHORT`) |
| NZDJPY.DWX | forex | `Custom/Forex/NZDJPY.DWX` | `Custom\Forex\*` | 2.5000 | `CommissionMode=1` | Pending MT5 runtime snapshot (`SYMBOL_SWAP_LONG/SHORT`) |
| NZDUSD.DWX | forex | `Custom/Forex/NZDUSD.DWX` | `Custom\Forex\*` | 2.5000 | `CommissionMode=1` | Pending MT5 runtime snapshot (`SYMBOL_SWAP_LONG/SHORT`) |
| UK100.DWX | indices | `Custom/Indices/Index 3/UK100.DWX` | `Custom\Indices\Index 3\*` | 2.7500 | `CommissionMode=3` | Pending MT5 runtime snapshot (`SYMBOL_SWAP_LONG/SHORT`) |
| USDCAD.DWX | forex | `Custom/Forex/USDCAD.DWX` | `Custom\Forex\*` | 2.5000 | `CommissionMode=1` | Pending MT5 runtime snapshot (`SYMBOL_SWAP_LONG/SHORT`) |
| USDCHF.DWX | forex | `Custom/Forex/USDCHF.DWX` | `Custom\Forex\*` | 2.5000 | `CommissionMode=1` | Pending MT5 runtime snapshot (`SYMBOL_SWAP_LONG/SHORT`) |
| USDJPY.DWX | forex | `Custom/Forex/USDJPY.DWX` | `Custom\Forex\*` | 2.5000 | `CommissionMode=1` | Pending MT5 runtime snapshot (`SYMBOL_SWAP_LONG/SHORT`) |
| WS30.DWX | indices | `Custom/Indices/Index 1/WS30.DWX` | `Custom\Indices\Index 1\*` | 0.3500 | `CommissionMode=3` | Pending MT5 runtime snapshot (`SYMBOL_SWAP_LONG/SHORT`) |
| XAGUSD.DWX | commodities | `Custom/Commodities/Metals/XAGUSD.DWX` | `Custom\Commodities\*` | 0.0025 | `CommissionMode=4` | Pending MT5 runtime snapshot (`SYMBOL_SWAP_LONG/SHORT`) |
| XAUUSD.DWX | commodities | `Custom/Commodities/Metals/XAUUSD.DWX` | `Custom\Commodities\*` | 0.0025 | `CommissionMode=4` | Pending MT5 runtime snapshot (`SYMBOL_SWAP_LONG/SHORT`) |
| XNGUSD.DWX | commodities | `Custom/Commodities/Energies/XNGUSD.DWX` | `Custom\Commodities\*` | 0.0025 | `CommissionMode=4` | Pending MT5 runtime snapshot (`SYMBOL_SWAP_LONG/SHORT`) |
| XTIUSD.DWX | commodities | `Custom/Commodities/Energies/XTIUSD.DWX` | `Custom\Commodities\*` | 0.0025 | `CommissionMode=4` | Pending MT5 runtime snapshot (`SYMBOL_SWAP_LONG/SHORT`) |

## Required Follow-up (swap capture)

1. Run a terminal-side script on T1 that exports for each symbol: `SYMBOL_SWAP_MODE`, `SYMBOL_SWAP_LONG`, `SYMBOL_SWAP_SHORT`, `SYMBOL_SWAP_ROLLOVER3DAYS`.
2. Save artifact under `docs/ops/` and link it from this file.
3. Re-run after broker contract-spec updates and commit delta evidence.
