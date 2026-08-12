# P1.9 remaining registry-only EA-ID re-keys — 2026-07-20

Owner: Codex (`agents/codex`)
Scope: the six registry-only ACTIVE collisions reported by
`ea_id_slug_uniqueness` after the 1158/1258 pass
State: COMPLETE

## Keep/re-key decisions

Before any edit, each original numeric ID was checked with an anchored bare-ID
query (`rg '^<bare_id>,'`) in both registries. The retained slug was the only
slug with an exact production directory, MQ5, EX5, and active magic rows. Every
re-keyed slug had no EA directory, MQ5/EX5, or magic row. This is registry-only;
no source, binary, magic, or resolver regeneration is warranted.

| Original ID | Retained active owner | Registry-only row retired | Replacement active ID | Decision evidence |
|---:|---|---|---:|---|
| 1492 | `connors-vix-spike-reversal-h4` | `as-raa-balanced` | 12625 | Retained slug owns exact MQ5/EX5 and five active magic rows; displaced slug owns none. |
| 9197 | `mql5-bb-stoch-mtf` | `mql5-macd-obv-div` | 12098 | Retained slug owns exact MQ5/EX5 and three active magic rows; 12098 was the preallocated matching registry alias. |
| 9198 | `mql5-cci-zero` | `mql5-ha-ema-trend` | 12099 | Retained slug owns exact MQ5/EX5 and three active magic rows; 12099 was the preallocated matching registry alias. |
| 11277 | `blade-m5-ema-zone-scalp` | `blade-m5-ema-zone-scalp-alt` | 12626 | Retained slug owns exact MQ5/EX5 and three active magic rows; the requested `-alt` identity is preserved at the new ID. |
| 11427 | `connors-rsi2-sma200-pullback-d1` | `connors-rsi2-sma200-pullback-d1-alt` | 12627 | Retained slug owns exact MQ5/EX5 and five active magic rows; the requested `-alt` identity is preserved at the new ID. |
| 11857 | `blade-macd-stoch-divergence-h1` | `blade-macd-stoch-divergence-h1-alt` | 12628 | Retained slug owns exact MQ5/EX5 and four active magic rows; the requested `-alt` identity is preserved at the new ID. |

The strategy IDs and original owner/creation metadata were preserved. The old
six rows remain as `retired` provenance; each replacement is the sole active row
at its normalized numeric ID.

## 12xxx allocation proof

All replacement IDs satisfy the requested `12077+` 12xxx block. Existing
matching aliases 12098 and 12099 were normalized rather than creating a second
active ID for the same slug, following the proven 12075/12076 P1.9 pattern.

The contiguous range 12077–12097 is already registered. Although 12553–12560
are absent from `ea_id_registry.csv`, tracked research evidence already assigns
those numbers to written strategy cards, so they were not reused. Exact scans
for 12625–12628 found:

```text
rg --files | rg 'QM5_(12625|12626|12627|12628)(?:_|\b)'
NO_WORKTREE_PATH_MATCHES

git grep ... 'QM5_(12625|12626|12627|12628)'
NO_TRACKED_QM5_MENTIONS

git grep ... 'ea_id: ... (12625|12626|12627|12628)|EA ID ...'
NO_TRACKED_ALLOCATION_MENTIONS

rg '^(12625|12626|12627|12628),|^QM5_(12625|12626|12627|12628),'
    framework/registry -g '*.csv'
NO_REGISTRY_ROWS
```

The fetched board-advisor/canonical registry snapshot also ended this sub-block
at 12624, so no concurrent tracked claim was hidden from the worktree view.

## Artifact preservation

The retained binaries had identical SHA-256 values before and after the registry
edit:

| EA | SHA-256 |
|---|---|
| `QM5_1492_connors-vix-spike-reversal-h4.ex5` | `F95D9141852097DEC8C698C04750995F2CAAF85118E2CF541AA3737C8AAF95EE` |
| `QM5_9197_mql5-bb-stoch-mtf.ex5` | `045908ED0F6152573017F50834EED97B3E91CD613CFB65FE7F2A28FBAFE30FD1` |
| `QM5_9198_mql5-cci-zero.ex5` | `A701883AF8F15796E4D8CC18A5021C36687C197F207459E3BA5678DB7B2C87AF` |
| `QM5_11277_blade-m5-ema-zone-scalp.ex5` | `026EC624674E1B69A21D362B183A5E399B1351D72CACD0CE85C8F9C9ECA2FD81` |
| `QM5_11427_connors-rsi2-sma200-pullback-d1.ex5` | `30DBC88F5FF95A0EAAF2B7E92BBB943BEC2BECE361C28F862D0FB409288D004F` |
| `QM5_11857_blade-macd-stoch-divergence-h1.ex5` | `27570D9A9515E16275B4F1283C8342DF6A8AFE3286B1AF531285F5A9E6256FD2` |

Post-edit exact scans returned `NO_NEW_ID_MAGIC_ROWS` for 12098, 12099, and
12625–12628, plus `NO_LOSER_SOURCE_OR_BINARY_PATHS` for all six displaced
slugs. `framework/EAs` and `framework/registry/magic_numbers.csv` have no diff.
The pre-existing unrelated modification to `QM_MagicResolver.mqh` was present at
task start, was not touched, and is excluded from the explicit commit pathspec.

## Deterministic validation

`test_registry_rekey_p19.py` now pins, for all six pairs, the retained active
owner, retired old claim, replacement strategy identity, absence of loser
directories/magics, and continued presence of the winner MQ5/EX5/magic rows.

```text
QM_AGENT_ID=codex python -m pytest -q
  tools/strategy_farm/tests/test_registry_rekey_p19.py
  tools/strategy_farm/tests/test_health_registry_uniqueness.py
............                                                             [100%]
12 passed in 0.79s

health.chk_ea_id_slug_uniqueness(Path.cwd())
status=OK value=0
detail=every active numeric ea_id maps to at most one distinct active slug
```

`git diff --check` passed (only the repository's configured LF/CRLF notices).
Factory automation was not interrupted; no MetaEditor build, tester, or manual
execution session was started.
