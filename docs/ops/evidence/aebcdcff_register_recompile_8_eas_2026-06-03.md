# Register + Recompile 8 Unregistered EAs

Task: `aebcdcff-740f-4ac5-945b-995249f343d4`
Date: 2026-06-03
Worktree: `C:/QM/repo`

## Scope

Registered and force-recompiled:

- `QM5_10590_mql5-elderimp`
- `QM5_10668_tv-vwap-orb-pb`
- `QM5_10704_tv-bos-retest`
- `QM5_10705_tv-liq-trap_v2`
- `QM5_10707_tv-asian-reclaim`
- `QM5_10715_tv-asian-box`
- `QM5_10720_tv-htf-fvg`
- `QM5_10726_tv-frac-react`

## Registry

Appended 41 active rows to `framework/registry/magic_numbers.csv`; no existing rows were modified.
Rows per EA:

- `10590`: 4 symbols
- `10668`: 4 symbols
- `10704`: 6 symbols
- `10705`: 6 symbols
- `10707`: 5 symbols
- `10715`: 6 symbols
- `10720`: 5 symbols
- `10726`: 5 symbols

Regenerated resolver:

```text
python framework/scripts/update_magic_resolver.py
[OK] wrote framework\include\QM\QM_MagicResolver.mqh - 5265 rows, sha=D887A97F583D32B2...
```

## Guardrails

Command:

```text
python tools/strategy_farm/validate_build_guardrails.py framework/EAs/QM5_10590_mql5-elderimp framework/EAs/QM5_10668_tv-vwap-orb-pb framework/EAs/QM5_10704_tv-bos-retest framework/EAs/QM5_10705_tv-liq-trap_v2 framework/EAs/QM5_10707_tv-asian-reclaim framework/EAs/QM5_10715_tv-asian-box framework/EAs/QM5_10720_tv-htf-fvg framework/EAs/QM5_10726_tv-frac-react
```

Result: `PASS` for all 8 EA dirs. Each result used `max_news_stale_hours=336` and had no findings.

## Compile Evidence

Command per EA:

```text
python tools/strategy_farm/compile_ea.py --ea-label <label> --force --json
```

Results:

| EA | Verdict | Errors | Warnings | Symbol scope | EX5 bytes | Compile log |
| --- | --- | ---: | ---: | --- | ---: | --- |
| `QM5_10590_mql5-elderimp` | `COMPILED` | 0 | 0 | `SINGLE_SYMBOL_OK` | 196492 | `C:/QM/repo/framework/build/compile/20260603_085028/QM5_10590_mql5-elderimp.compile.log` |
| `QM5_10668_tv-vwap-orb-pb` | `COMPILED` | 0 | 0 | `SINGLE_SYMBOL_OK` | 197452 | `C:/QM/repo/framework/build/compile/20260603_085036/QM5_10668_tv-vwap-orb-pb.compile.log` |
| `QM5_10704_tv-bos-retest` | `COMPILED` | 0 | 0 | `SINGLE_SYMBOL_OK` | 202846 | `C:/QM/repo/framework/build/compile/20260603_085045/QM5_10704_tv-bos-retest.compile.log` |
| `QM5_10705_tv-liq-trap_v2` | `COMPILED` | 0 | 0 | `SINGLE_SYMBOL_OK` | 190588 | `C:/QM/repo/framework/build/compile/20260603_085051/QM5_10705_tv-liq-trap_v2.compile.log` |
| `QM5_10707_tv-asian-reclaim` | `COMPILED` | 0 | 0 | `SINGLE_SYMBOL_OK` | 196570 | `C:/QM/repo/framework/build/compile/20260603_085058/QM5_10707_tv-asian-reclaim.compile.log` |
| `QM5_10715_tv-asian-box` | `COMPILED` | 0 | 0 | `SINGLE_SYMBOL_OK` | 204084 | `C:/QM/repo/framework/build/compile/20260603_085107/QM5_10715_tv-asian-box.compile.log` |
| `QM5_10720_tv-htf-fvg` | `COMPILED` | 0 | 0 | `SINGLE_SYMBOL_OK` | 196094 | `C:/QM/repo/framework/build/compile/20260603_085115/QM5_10720_tv-htf-fvg.compile.log` |
| `QM5_10726_tv-frac-react` | `COMPILED` | 0 | 0 | `SINGLE_SYMBOL_OK` | 194654 | `C:/QM/repo/framework/build/compile/20260603_085123/QM5_10726_tv-frac-react.compile.log` |

Fresh `.ex5` mtimes are all `2026-06-03T08:50:35Z` through `2026-06-03T08:51:29Z`.

## Changed Files

Expected tracked changes:

- `framework/registry/magic_numbers.csv`
- `framework/include/QM/QM_MagicResolver.mqh`

Expected untracked EA dirs, to be reviewed and landed together by Claude:

- `framework/EAs/QM5_10590_mql5-elderimp/`
- `framework/EAs/QM5_10668_tv-vwap-orb-pb/`
- `framework/EAs/QM5_10704_tv-bos-retest/`
- `framework/EAs/QM5_10705_tv-liq-trap_v2/`
- `framework/EAs/QM5_10707_tv-asian-reclaim/`
- `framework/EAs/QM5_10715_tv-asian-box/`
- `framework/EAs/QM5_10720_tv-htf-fvg/`
- `framework/EAs/QM5_10726_tv-frac-react/`

## Verdict

`REVIEW`: registry rows appended, resolver regenerated, guardrails PASS, and all 8 EAs force-compiled with `COMPILED` / 0 errors / 0 warnings.
