# FTMO trial set-file path

**Router task:** `f810f5af-f330-4709-ac00-952510be68f4`  
**Verdict:** `PASS_BUILD_ONLY_OWNER_CONFIRM_CLIENT_SYMBOLS`  
**Dry-run output:** `D:/QM/reports/ftmo_trial/sets_20260905_055750/`  
**Manifest:** `D:/QM/reports/ftmo_trial/sets_20260905_055750/manifest.json`

The live-like FTMO trial risk-mode gap is implemented without weakening `ftmo_lane_runner.validate_set_guardrails`. That runner remains backtest-only and still requires `RISK_FIXED > 0`, `RISK_PERCENT = 0`, and `qm_news_stale_max_hours <= 336`. The new, separate `tools/strategy_farm/portfolio/ftmo_trial_setfiles.py` path emits `environment: trial`, `risk_mode: PERCENT`, `RISK_FIXED=0`, and positive `RISK_PERCENT` only into a destination matching:

`D:/QM/reports/ftmo_trial/sets_<timestamp>/`

Any other directory—including any path under T_Live—is refused. Existing output directories are also refused, making each dry run immutable by construction. Nothing was deployed, copied to a terminal, or executed.

## Risk and identity contract

The generator binds `tools/strategy_farm/config/concentration_tail_limits.v1.json` at SHA-256 `77a3b67312d199e06ad39c10a4404ab505b4041de0701ce4312a13c8cdf827da` and requires its `OWNER_RATIFIED` status and 2.5% stop-risk budget. With no ratified unequal eight-sleeve allocation, it uses the transparent equal allocation **0.3125% per sleeve**, totaling exactly **2.5%**.

Static concentration totals are:

- FX: 1.25% (50% of budget), below the 60% asset-class cap;
- energy: 0.625% (25%), below the 60% cap;
- metal: 0.625% (25%), below the 60% cap;
- largest symbol totals: USOIL.cash 0.625% and XAGUSD 0.625% (25% each), below the 40% symbol cap.

Session concurrency and realized tail loss are runtime quantities and are not fabricated by this static generator. They remain duties of the governor/telemetry and the later trial assessment.

Every set preserves all strategy inputs from its canonical backtest set except the declared risk/news keys, binds the current `.ex5` SHA-256 in its header, resolves the active registry slot, and records `magic = ea_id*10000 + slot`. The validator checks unique assignments, exact risk mode, the registry slot, stale-news ceiling, trial-only banner, and internal news contract.

## Generated set files

| EA | trial chart symbol | TF | magic | risk % | output SHA-256 |
|---:|---|---|---:|---:|---|
| 10706 | GBPUSD | H1 | 107060001 | 0.3125 | `a52b04db02972f5f56c121d739fdbecc72efcd74f0e41c248a1b420a176fbdaa` |
| 11421 | EURUSD | D1 | 114210000 | 0.3125 | `598be7770ba182040b892745ab32ec7dc118ea676b5c6a9a4cb4773a06c04b51` |
| 11422 | USDCAD | D1 | 114220004 | 0.3125 | `517ae6803f541d5bc3807a461e3cfc3cc491a2ef3b9ef51948f334858c45c474` |
| 11910 | NZDUSD | D1 | 119100006 | 0.3125 | `bc81b20a42c898f610be4a9c7fb20e8785d214f440c2cf35b5af31e5b4b9001d` |
| 13054 | USOIL.cash | D1 | 130540000 | 0.3125 | `61be577a444356e81570ad9e5416c3599f227a0eca9bdca59276ed811f64d908` |
| 1537 | XAGUSD | D1 | 15370001 | 0.3125 | `7c083e70a003b5c86d49332875cf2c45786d058450b7fde2c1039d96cbb241a9` |
| 20048 | USOIL.cash | D1 | 200480000 | 0.3125 | `5a6ddcba67eb2bc9540b1b3e47deabdca6e53cefe9cb0e5980a8ed20af61ffa8` |
| 21505 | XAGUSD | D1 | 215050000 | 0.3125 | `8e1bcb2235770b3418fc09423fae202a5aac8dc797f5df2bf3eb9a2f0cfc3d6f` |

The trial chart-symbol mappings come from the 2026-09-05 official-symbol snapshot: the four FX pairs, XAGUSD, and `XTIUSD.DWX -> USOIL.cash`. Each set carries `OWNER_CONFIRM_CLIENT_SYMBOL_BEFORE_RUN`. Client-platform spelling and availability must be confirmed before a for-record run; these artifacts do not remove that readiness blocker.

## News semantics

FTMO Swing's **provider temporal restriction is OFF**: the provider permits news/weekend holding. QuantMechanica's Edge-Lab **internal mandatory news blackout remains ON**. The generated files therefore document both layers explicitly and pin `qm_news_stale_max_hours=336`; the validator rejects 337 or any larger weakening. The task does not alter EA mechanics or the production news seed. If the seed is stale, the remedy remains refreshing the calendar, never increasing the ceiling.

## Verification

```text
python -m pytest -q tools/strategy_farm/tests/test_ftmo_trial_setfiles.py
....                                                                     [100%]
4 passed in 0.88s

python -m py_compile tools/strategy_farm/portfolio/ftmo_trial_setfiles.py
PASS

python tools/strategy_farm/portfolio/ftmo_trial_setfiles.py --output-dir D:/QM/reports/ftmo_trial/sets_20260905_055750
{"status":"PASS","sets":8,"output_dir":"D:\\QM\\reports\\ftmo_trial\\sets_20260905_055750"}
```

Tests prove unsafe/non-trial destinations are refused, all canonical strategy assignments are preserved, eight active registry magics are unique, total/symbol/class risk caps reconcile, output hashes bind, and a stale-news limit above 336 fails closed.

## Status

This closes the set-generation tooling gap only. It does not authorize or perform deployment. The OWNER-created account/profile, exact client symbol confirmation, candidate binary staging, telemetry installation, MNT-004 state decision, and ratified for-record scoring ceremony remain separate prerequisites.
