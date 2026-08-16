# Priority 72 hot-path sweep — deterministic classification

Date: 2026-08-16

Router task: `e792e7de-26d3-4062-a162-47d43b2ec3db`

Verdict: `REVIEW — NO NEW SOURCE MUTATION OR Q02 SEED REQUIRED`

## Scope and decision rule

The routed target order was `QM5_12538`, `QM5_10025`, `QM5_9107`,
`QM5_9940`, and `QM5_12486`.  Each target was admitted to the repair
template only if both conditions held:

1. expensive indicator/state computation remained reachable from `OnTick`
   without a closed-bar cache or gate; and
2. the terminal evidence showed progress stalling in the corresponding
   binary.

None of the five current binaries satisfies both conditions.  Four already
contain committed closed-bar repairs and have fresh, hash-bound terminal
evidence.  The remaining target, `QM5_9107`, is a 37-symbol monthly ranking
engine whose failure class is peer-history/data-volume readiness rather than
per-tick recomputation.  Its exact current binary already has one isolated
Q02 successor pending, so another enqueue would duplicate governed work.

## Per-EA disposition

| EA | Static reachability result | Current binary / terminal evidence | Disposition |
|---|---|---|---|
| `QM5_12538` | `Strategy_RefreshClosedBarState()` latches `g_strategy_cached_day_key` before the bounded McGinley/SuperTrend/Vortex reconstruction; later management/exit calls are O(1) cache hits. | Source `061a979c...`; EX5 `0157749c...`. Q02 `0c41b34a-a73c-4d36-b1ac-1b725f257478` completed `OK` on EURUSD D1 with 14 trades and PF 2.92; router verdict `FAIL` is economic/min-trades, not infrastructure. | Already repaired and requalified. No mutation or enqueue. |
| `QM5_10025` | `OnTick` returns unless `QM_IsNewBar(_Symbol, PERIOD_H4)` succeeds; all seven-symbol history, spread, and pair-selection work follows that gate. | Source `fd0a18d8...`; EX5 `9bf2691d...`. Q02 `8582efac-cbaf-4336-98af-950e6dd606a0` completed `OK` on NZDUSD H4 with 6 trades; `1a8e8377-a2f3-4533-9ae2-c4bcfc84aff0` completed as zero trades rather than timeout. Existing USDJPY/USDCAD rows are pending. | Current timeout template does not apply. No duplicate enqueue. |
| `QM5_9107` | The 37-peer `Strategy_RankPasses()` scan is D1/month gated, not an unguarded per-tick path. The expensive operation is cross-symbol monthly-history access (`Bars`/`iClose`) across the universe. | Current source `1cf9d189...`; EX5 `9c9f423b...`. Pre-repair Q02 `5512f5b6-831d-4589-8435-75d0c51dd03c` failed `BARS_ZERO,INCOMPLETE_RUNS`. Exact-current-binary isolated successor `942384d1-4ebc-4a08-9cff-5ddd4c9765f3` is already `pending` on XTIUSD D1. | Classify as peer-history/data-volume readiness. Do not force the per-tick template or duplicate the pending successor. |
| `QM5_9940` | Heiken-Ashi reconstruction is cached by `g_ha_cache_closed_bar`; `Strategy_RefreshHACache()` rebuilds only once per completed H1 bar. | Source `30de5f23...`; EX5 `6e5e7a69...`. Hash-bound Q02 `97a9799d-de3a-4809-b864-7297710d999c` completed `OK`, 214 trades, then Q04 `7542c68a-c37a-4dba-ada5-d120e911ed2d` produced an economic `FAIL`. | Repair is empirically proven through Q02. No further Q02 seed. |
| `QM5_12486` | `OnTick` latches `QM_IsNewBar(_Symbol, PERIOD_D1)` once and calls `Strategy_AdvanceStateOnNewBar()` only when true; entry and exit reuse the cached SuperTrend state. | Source `37a888d3...`; EX5 `1914888f...`. Q02 `171a5cfd-f696-4836-bffd-696e4c15c186` passed with 25 trades and PF 1.91, Q03 passed, and Q04 produced an economic `FAIL`. | Repair is empirically proven through Q03. No further Q02 seed. |

Full SHA-256 values are bound in the referenced `summary.json` files and were
recomputed from the canonical checkout during this review.

## Focused verification

Run from `C:\QM\repo`:

```powershell
python tools/strategy_farm/validate_build_guardrails.py `
  framework/EAs/QM5_12538_nnfx-canonical-stack2-st-vortex/QM5_12538_nnfx-canonical-stack2-st-vortex.mq5 `
  framework/EAs/QM5_10025_rw-fx-broad-pairs/QM5_10025_rw-fx-broad-pairs.mq5 `
  framework/EAs/QM5_9107_aa-mom-filter111/QM5_9107_aa-mom-filter111.mq5 `
  framework/EAs/QM5_9940_ff-ha-ma-fractal-h1/QM5_9940_ff-ha-ma-fractal-h1.mq5 `
  framework/EAs/QM5_12486_shv-supertrend/QM5_12486_shv-supertrend.mq5
python framework/EAs/QM5_9940_ff-ha-ma-fractal-h1/docs/test_ha_cache_contract.py
```

Results:

- build guardrails: `PASS` for all five sources, including the 336-hour
  stale-news ceiling;
- focused Heiken-Ashi cache contract: exit code `0`;
- source/EX5 hashes recomputed from `C:\QM\repo` match the current-binary
  identities recorded above;
- read-only farm-state inspection confirms no active rerun is needed for the
  four proven repairs and confirms the existing `QM5_9107` pending successor.

No EA source, EX5, setfile, registry, terminal, or work-item row was changed by
this sweep.  No T_Live or AutoTrading action was taken.
