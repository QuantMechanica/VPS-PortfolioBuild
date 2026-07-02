# Survivor-Port Strategy Cards Evidence

Task: `034a3582-c53c-4bf7-bb0d-ba43caf0cd32`  
Date: 2026-06-25  
Agent: Codex  
Scope: Create approved survivor-port strategy cards from `docs/research/EDGE_PUSH_2026-06-25.md` section C-2.

## Source Context Read

- `C:/QM/repo/docs/research/EDGE_PUSH_2026-06-25.md`
- `docs/ops/EDGE_LAB_CHARTER_2026-05-22.md`
- `docs/ops/PROFITABILITY_TRACK_2026-05-21.md`
- Source survivor cards:
  - `D:/QM/strategy_farm/artifacts/cards_approved/QM5_10440_mql5-ohlc-mtf.md`
  - `D:/QM/strategy_farm/artifacts/cards_approved/QM5_10513_mql5-ichimoku.md`
  - `D:/QM/strategy_farm/artifacts/cards_approved/QM5_10940_grimes-nested-pb.md`
  - `D:/QM/strategy_farm/artifacts/cards_approved/QM5_10692_tv-ls-ms.md`
  - `D:/QM/strategy_farm/artifacts/cards_approved/QM5_11124_tm-r2-index.md`
  - `D:/QM/strategy_farm/artifacts/cards_approved/QM5_11132_tm-cum-rsi2.md`
- Example Claude cards:
  - `QM5_12561_session-open-pdh-breakout.md`
  - `QM5_12562_fx-london-open-breakout.md`
  - `QM5_12563_donchian-turtle-trend-commodity.md`

## Created Approved Cards

All cards were written to `D:/QM/strategy_farm/artifacts/cards_approved/`.

| EA | Slug | Source survivor | Target symbols | Period |
|---|---|---|---|---|
| `QM5_12564` | `ohlc-mtf-index-energy` | `QM5_10440` | `WS30.DWX`, `UK100.DWX`, `XTIUSD.DWX`, `XAGUSD.DWX` | H1 |
| `QM5_12565` | `ls-ms-cross-sweep` | `QM5_10692` | `EURJPY.DWX`, `GBPJPY.DWX`, `AUDUSD.DWX`, `XAGUSD.DWX`, `XTIUSD.DWX`, `WS30.DWX` | M15 |
| `QM5_12566` | `nested-pb-cross-asset` | `QM5_10940` | `AUDJPY.DWX`, `EURJPY.DWX`, `XTIUSD.DWX`, `XAGUSD.DWX`, `WS30.DWX` | H4 |
| `QM5_12567` | `cum-rsi2-commodity` | `QM5_11132` | `XTIUSD.DWX`, `XAGUSD.DWX`, `XNGUSD.DWX`, `XAUUSD.DWX` | D1 |
| `QM5_12568` | `ichimoku-jpy-xag-trend` | `QM5_10513` | `AUDJPY.DWX`, `CADJPY.DWX`, `EURJPY.DWX`, `XAGUSD.DWX` | D1 |
| `QM5_12569` | `r2-euro-index` | `QM5_11124` | `GDAXI.DWX`, `UK100.DWX` | D1 |

Notes:
- Created one variant per survivor to satisfy the "for each, create 1-2 variant cards" requirement with a reviewable six-card batch.
- Mechanics were kept faithful to the survivor cards; only the instrument universe was changed.
- `SP500.DWX` was avoided because it is backtest-only in the matrix.
- `GER40.DWX` was avoided because the local canonical DWX matrix uses `GDAXI.DWX`.

## EA ID Reservation

Reserved through the canonical registry in `C:/QM/repo/framework/registry/ea_id_registry.csv` using:

```powershell
python tools/strategy_farm/farmctl.py reserve-ea-ids --strategy-id <uuid> --slug <slug> --start-after 12563 --owner Codex --created-at 2026-06-25
```

Strategy IDs:

| EA | Strategy ID |
|---|---|
| `QM5_12564` | `4b081ccd-290a-5128-a92e-02a9383e7ed4` |
| `QM5_12565` | `4eb2feb0-99a8-5e52-9c44-98c7f7ac0096` |
| `QM5_12566` | `dc8bdfa5-66a6-50d0-8961-4a3a03928395` |
| `QM5_12567` | `ee172909-2f40-5169-9fa3-c1dc0657dee0` |
| `QM5_12568` | `d7b83b78-73ba-5c66-b191-22db115630e0` |
| `QM5_12569` | `e69a0adc-3232-555b-b512-6087d6658a83` |

One concurrent reservation attempt for `r2-euro-index` hit a Windows `PermissionError` while replacing the CSV. It was retried sequentially and reserved cleanly as `QM5_12569`.

## Verification

Canonical prebuild validation and schema check:

```powershell
cd C:/QM/repo
python - <<'PY'
# Imported C:/QM/repo/tools/strategy_farm/farmctl.py and ran:
# parse_card_frontmatter(card)
# prebuild_validate_card(D:/QM/strategy_farm, card, fm)
# strategy_card_schema_issues(card, fm)
PY
```

Result:

```text
QM5_12564_ohlc-mtf-index-energy.md: prebuild_ok=True schema_ok=True errors=[] schema=[]
QM5_12565_ls-ms-cross-sweep.md: prebuild_ok=True schema_ok=True errors=[] schema=[]
QM5_12566_nested-pb-cross-asset.md: prebuild_ok=True schema_ok=True errors=[] schema=[]
QM5_12567_cum-rsi2-commodity.md: prebuild_ok=True schema_ok=True errors=[] schema=[]
QM5_12568_ichimoku-jpy-xag-trend.md: prebuild_ok=True schema_ok=True errors=[] schema=[]
QM5_12569_r2-euro-index.md: prebuild_ok=True schema_ok=True errors=[] schema=[]
PREBUILD_AND_SCHEMA_OK True
```

DWX symbol/period coverage check against `C:/QM/repo/framework/registry/dwx_symbol_history_ranges.csv`:

```text
QM5_12564: H1 coverage_ok=True
QM5_12565: M15 coverage_ok=True
QM5_12566: H4 coverage_ok=True
QM5_12567: D1 coverage_ok=True
QM5_12568: D1 coverage_ok=True
QM5_12569: D1 coverage_ok=True
COVERAGE_OK True
```

Guardrail review:
- No `qm_news_stale_max_hours` changes.
- No set files created.
- No terminal launched.
- No live/AutoTrading action.
- All cards specify `RISK_FIXED = 1000` for P2 baseline and no martingale/grid/ML.

