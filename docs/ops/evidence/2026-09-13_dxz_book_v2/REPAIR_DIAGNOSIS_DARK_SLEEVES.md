# Dark live sleeves — root cause, and why a preset alone cannot repair them (2026-09-13)

Read-only investigation of `C:/QM/mt5/T_Live`. No T_Live file, chart, terminal or
AutoTrading state was touched.

## 1 · One root cause, three sleeves, and a perfect correlation

All three dark sleeves compare `_Symbol` against a hard-coded `".DWX"` string literal in
their `.mq5` source. On T_Live the chart carries the **bare broker symbol**
(`AUDUSD`, `EURGBP`, `USDJPY` — confirmed by the `"symbol"` field of every log line in
`MQL5/Files/QM/QM5_<id>_ea-<id>.log`). The comparison is therefore permanently false and
the EA never reaches its entry path.

The correlation across the deployed 24-sleeve book is exact:

| `.DWX` literal in `.mq5`? | sleeves | live trades |
|---|---|---|
| yes | 12778, 12969, 13117 | **0, all three** |
| no | the other 21 | all trading |

Reproduce:

```
cd C:/QM/repo
for d in 10403 10440 10513 10706 10911 10919 10939 11132 11165 11421 11708 12567 \
         12778 12969 12989 13117 13128 13213 13301 1556 1567; do
  f=$(ls framework/EAs/QM5_${d}_*/*.mq5 | head -1)
  n=$(grep -cE '"[A-Z0-9]{3,8}\.DWX"' "$f"); [ "$n" != "0" ] && echo "$d count=$n"
done
# -> 12778 count=5 / 12969 count=1 / 13117 count=3 ; nothing else
```

This is a direct violation of the Hard Rule **"Symbols are inputs, never code literals"**
(OWNER 2026-09-06, Vault `01 Identity/Hard Rules` annex; `V5_FRAMEWORK_DESIGN.md`
principle 7). The three sleeves predate the rule; they were never brought into line.

## 2 · Per sleeve

### QM5_12778 / AUDUSD (basket, D1, magic 127780000)

`framework/EAs/QM5_12778_edgelab-audusd-eurjpy-cointegration/QM5_12778_edgelab-audusd-eurjpy-cointegration.mq5`

```
:85   string g_leg_audusd = "AUDUSD.DWX";
:86   string g_leg_eurjpy = "EURJPY.DWX";
:106  return (_Symbol == g_leg_audusd || _Symbol == g_leg_eurjpy);   // Strategy_IsHostSymbol
:125  string allowed[4] = {"AUDUSD.DWX","EURJPY.DWX","EURUSD.DWX","EURAUD.DWX"};
:310  if(!Strategy_IsHostSymbol())   // OnTick bails here
:405  SymbolSelect("EURUSD.DWX", true);
:406  SymbolSelect("EURAUD.DWX", true);
```

Live evidence (`MQL5/Files/QM/QM5_12778_ea-12778.log`, 399 lines, 2026-07-13 → 2026-09-11,
last entry read 2026-09-11T19:46:35Z):

```
"event":"SYMBOL_GUARD_INIT","payload":{"mode":"basket","n_symbols":4,
  "symbols":["AUDUSD.DWX","EURJPY.DWX","EURUSD.DWX","EURAUD.DWX"]}
"event":"BASKET_WARMUP","payload":{"requested":4,"loaded":0,"skipped":4,...}
"event":"INIT_OK"
```

`loaded=0, skipped=4` on **every** warmup: none of the four `.DWX` names resolves on a
live broker account. No order, deal or trade event exists in the file.

**The deployed preset is not the problem.** `06_AUDUSD_D1_QM5_12778_...set` contains no
symbol key at all (only a comment mentioning the basket manifest) — there is nothing for
a preset to override, because the EA exposes no symbol input.

### QM5_13117 / EURGBP (basket, D1, magic 131170000)

Same shape: `:45-46` leg literals `"EURGBP.DWX"` / `"AUDJPY.DWX"`, `:64`
`Strategy_IsHostSymbol()` compares `_Symbol` against them, `:84` the guard allow-list is
`{"EURGBP.DWX","AUDJPY.DWX","GBPUSD.DWX","USDJPY.DWX"}`, `:291` OnTick bails.
Log: 380 lines from 2026-07-19, every warmup `loaded=0, skipped=4`, no trade event.

### QM5_12969 / USDJPY (session sleeve, M30, magic 129690000) — cause FOUND

`framework/EAs/QM5_12969_usdjpy-gotobi-nakane-fix/QM5_12969_usdjpy-gotobi-nakane-fix.mq5`

```
:42   bool Strategy_IsTarget()
      { return (_Symbol == "USDJPY.DWX" && _Period == PERIOD_M30 && qm_magic_slot_offset == 0); }
:197  bool Strategy_NoTradeFilter()
      { if(!Strategy_IsTarget()) return true;   // true == DO NOT TRADE
        ... }
```

On T_Live `_Symbol == "USDJPY"`, so `Strategy_IsTarget()` is false and
`Strategy_NoTradeFilter()` returns "no trade" on every single tick. The sleeve is
structurally incapable of entering — the seven dark weeks are fully explained.

This **refutes** the three hypotheses in the brief: it is *not* the JST session window
(`strategy_entry_jst_hhmm=200` / `exit=955` match the repository strategy exactly), *not*
a timezone bug (`Strategy_BrokerToJST` is never reached), *not* min-lot
(`QM_RiskSizerQuantizeLots` is never reached). Corroborating log evidence
(`QM5_12969_ea-12969.log`, 336 lines, 2026-07-13 → 2026-09-11): the EA ticks and its
management path runs — eight `FRIDAY_CLOSE` events with `"closed":0` — but no entry,
order or deal event ever appears. Backtest expectation was 331 trades (~47/yr,
`KS_BASELINE_LOADED n=331` on T_Live); live = 0. Status: **RESOLVED, cause identified.**

## 3 · The fix (identical for all three) — Codex, not a preset

1. Replace each `".DWX"` literal with an `input string` carrying the **bare broker name**
   (Hard Rule 2026-09-06). Contract pinned by the draft presets under
   `C:/QM/deploy/DXZ_V2_20260913/repair/` — the patch must use exactly these keys:
   * 12778: `strategy_leg_a_symbol=AUDUSD`, `strategy_leg_b_symbol=EURJPY`,
     `strategy_conv_symbol_1=EURUSD`, `strategy_conv_symbol_2=EURAUD`
   * 13117: `strategy_leg_a_symbol=EURGBP`, `strategy_leg_b_symbol=AUDJPY`,
     `strategy_conv_symbol_1=GBPUSD`, `strategy_conv_symbol_2=USDJPY`
   * 12969: `strategy_host_symbol=USDJPY`
   `QM_SymbolGuardInit` / `SymbolSelect` must be fed from the same inputs, and the
   tester keeps working because `.DWX` is then just another input value.
   `QM_MagicChecked` already tolerates both spellings — `QM_MagicSymbolCanonical`
   (`QM_MagicResolver.mqh:134`) strips the suffix — so the magic registry needs no change.
2. Recompile. **A recompiled binary is a new identity from Q02 on (DL-089).** It must be
   requalified before it may carry live risk; a repaired binary that fails requalification
   is excluded from the *next* book and does not trigger a live change on anything else.
3. Only then does the repaired preset mean anything.

## 4 · Blocking consequence for the v2 book — 2 of the 6 NEW sleeves have the same defect

The same grep over the six proposed new sleeves:

| ea | symbol | `.DWX` literals | live-safe on a bare-symbol chart? |
|---|---|---|---|
| 9641 | WS30 | 0 | yes |
| 10700 | XAUUSD | 0 | yes |
| 13013 | NDX | 0 | yes |
| 1537 | XAGUSD | 8 (registry name table only) | **yes, conditionally** — `QM1537_HostSymbol()` returns the `strategy_calendar_symbol` **input** when set (`:81-84`), so the staged preset sets `strategy_calendar_symbol=XAGUSD.DWX` and `Strategy_HostRegistrationMatches()` (`:167-170`) passes. Prices are read only from `_Symbol`. Calendar `QM5_1537_monthly_sleeves_v1.csv` is read via `FILE_COMMON` and is present at `C:/Users/Administrator/AppData/Roaming/MetaQuotes/Terminal/Common/Files/`. |
| 13054 | XTIUSD | 1 — `:57 return (_Symbol == "XTIUSD.DWX" && _Period == PERIOD_D1);` gating `:227` | **NO — dark on arrival** |
| 21505 | XAGUSD | 2 — `:81 return (_Symbol == "XAGUSD.DWX" && _Period == PERIOD_D1);` gating `:329`; `:419` position filter | **NO — dark on arrival** |

Deploying 13054 and 21505 as-is would reproduce the 12778/13117/12969 failure exactly.
They need the same source patch + recompile + DL-089 requalification before deployment.

## 5 · Evidence paths

* Deployed presets (read-only): `C:/QM/mt5/T_Live/MT5_Base/MQL5/Presets/{06,17,24}_*.set`
* EA logs (read-only): `C:/QM/mt5/T_Live/MT5_Base/MQL5/Files/QM/QM5_{12778,12969,13117}_ea-*.log`
* Repair preset drafts + diff proofs: `C:/QM/deploy/DXZ_V2_20260913/repair/`,
  `C:/QM/deploy/DXZ_V2_20260913/diffs/repair__*.diff`,
  `C:/QM/deploy/DXZ_V2_20260913/repair_report.json`
* Prior disposition (superseded on cause, not on caution):
  `docs/ops/evidence/2026-09-02_dark_live_sleeves_disposition.md`
