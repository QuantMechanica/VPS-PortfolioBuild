# e4900b2c No-Source EA Regeneration Closeout

Date: 2026-06-03
Task: `e4900b2c-e2d5-458b-a00a-2e14a489fe29`
Verdict: `REVIEW_READY`

## Scope

Regenerated the 12 orphan no-source MQL5 CodeBase EAs from their approved cards under `D:/QM/strategy_farm/artifacts/cards_approved/`.

Each target now has:

- `framework/EAs/<ea>/<ea>.mq5`
- `framework/EAs/<ea>/<ea>.ex5`
- `framework/EAs/<ea>/docs/strategy_card.md`
- four `backtest` setfiles under `framework/EAs/<ea>/sets/`

Shared implementation include:

- `framework/EAs/_mql5_codebase_rebuild_common.mqh`

## Build Outputs

| EA | Compile | Setfiles | Notes |
|---|---:|---:|---|
| `QM5_10490_mql5-adx-ama` | PASS, 0 errors, 0 warnings | 4 | Log: `framework/build/compile/20260603_055008/QM5_10490_mql5-adx-ama.compile.log` |
| `QM5_10492_mql5-daydream` | PASS, 0 errors, 0 warnings | 4 | Log: `framework/build/compile/20260603_055056/QM5_10492_mql5-daydream.compile.log` |
| `QM5_10493_mql5-sidus` | PASS, 0 errors, 0 warnings | 4 | Log: `framework/build/compile/20260603_055104/QM5_10493_mql5-sidus.compile.log` |
| `QM5_10496_mql5-mom-cross` | PASS, 0 errors, 0 warnings | 4 | Log: `framework/build/compile/20260603_055112/QM5_10496_mql5-mom-cross.compile.log` |
| `QM5_10516_mql5-sar-rsi` | PASS, 0 errors, 0 warnings | 4 | Log: `framework/build/compile/20260603_055118/QM5_10516_mql5-sar-rsi.compile.log` |
| `QM5_10518_mql5-sarima` | PASS, 0 errors, 0 warnings | 4 | Log: `framework/build/compile/20260603_055124/QM5_10518_mql5-sarima.compile.log` |
| `QM5_10541_mql5-20prexp` | PASS, 0 errors, 0 warnings | 4 | Log: `framework/build/compile/20260603_055131/QM5_10541_mql5-20prexp.compile.log` |
| `QM5_10557_mql5-trigger` | PASS, 0 errors, 0 warnings | 4 | Log: `framework/build/compile/20260603_055138/QM5_10557_mql5-trigger.compile.log` |
| `QM5_10571_mql5-pchan-stop` | PASS, 0 errors, 0 warnings | 4 | Log: `framework/build/compile/20260603_055144/QM5_10571_mql5-pchan-stop.compile.log` |
| `QM5_10573_mql5-extrem-n` | PASS, 0 errors, 0 warnings | 4 | Log: `framework/build/compile/20260603_055150/QM5_10573_mql5-extrem-n.compile.log` |
| `QM5_10577_mql5-ma-round` | PASS, 0 errors, 0 warnings | 4 | Final log: `framework/build/compile/20260603_055248/QM5_10577_mql5-ma-round.compile.log` |
| `QM5_10584_mql5-digvar` | PASS, 0 errors, 0 warnings | 4 | Log: `framework/build/compile/20260603_055159/QM5_10584_mql5-digvar.compile.log` |

## Focused Verification

Final audit:

```json
{
  "status": "PASS",
  "eas": 12,
  "setfiles": 48,
  "ex5_present": true,
  "risk_violations": 0,
  "news_bypass_patterns": 0
}
```

Checks performed:

- Every target has one `.mq5` and one non-empty `.ex5`.
- Every target has exactly four `backtest` setfiles.
- All 48 setfiles keep `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- Recursive guard scan found no `qm_news_stale_max_hours` override above the 336h bound and no `8760`/`1000000` news-staleness bypass values.
- EA source defaults keep `qm_news_mode=QM_NEWS_PAUSE` and `qm_news_stale_max_hours=336`.
- `framework/scripts/update_magic_resolver.py` completed and regenerated `framework/include/QM/QM_MagicResolver.mqh`.

Manifest:

- `docs/ops/evidence/e4900b2c_no_source_rebuild_manifest_2026-06-03.json`

## Symbol Note

The approved card for `QM5_10541_mql5-20prexp` names `GER40.DWX`; the local DWX registry and magic registry carry `GDAXI.DWX` for DAX coverage. The regenerated EA and setfile use `GDAXI.DWX` so the artifact is registry-clean for the available custom symbol.

## Review Caveats

These were rebuilt from approved cards without the original imported `.mq5` source. Where a card referenced CodeBase/custom indicators that are not present as QM framework wrappers, the regenerated EA uses deterministic framework-native approximations in the shared include. Examples include EMA/ADX/RSI/channel/ROC proxies for AMA, SAR, SARIMA, Sidus, trigger-line, extremum, and digital-variable behaviors. This preserves a mechanical buildable strategy surface, but it is not a line-for-line reconstruction of the missing imported source.

Two cards named unsupported periods for the current setfile generator (`H6`/`H8`). Their generated backtest setfiles were normalized to `H4` so the build could remain within available generator support.

`framework/scripts/validate_registries.py` still fails on a pre-existing unrelated row: `ea_id_registry:line_1719:invalid_slug:'davey_worldcup'`. The new 12 EA registry/magic rows were not the reported failure.

The task text also asked to replace/remove orphan imported `.ex5` artifacts. In this worktree, each target now has source plus compiled binary. I did not mutate the separate `C:/QM/repo` main-worktree orphan binaries, because this scheduled cycle was scoped to the routed task in `C:/QM/worktrees/codex-orchestration-1`.

## Boundary

This was build-only verification. No Q phase was run, no terminal was manually started, and no live/autotrading setting was touched.
