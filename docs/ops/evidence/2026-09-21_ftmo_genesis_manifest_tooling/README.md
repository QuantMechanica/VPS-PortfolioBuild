# FTMO Genesis Manifest + Sunday preflight tooling

Task: `94a15624-4ab2-4f0a-9e6f-aa18107f4f3f`  
Authority: `OWNER-DEC-FTMO-FINAL-MEGA-20260921` sections Q and R  
Scope: read-only rehearsal against the running D2g6 `PRE_SUNDAY_LIVE_TRIAL`; this is not the Sunday representative generation and is not launch authority.

## Verdict

The tooling is implemented and its D2g6 rehearsal is deterministic:

- Genesis verification: **PASS**, 0 drift rows. The six sleeves, the account governor, installed Demo EX5 files, installed presets, repo sources, rules snapshot, build receipt, and both deterministic registries are hash-bound.
- Manifest SHA-256: `2f079710d5cd2d051ea2499b82c9127ef6ca18c763fafe7ec8abfb453b4a6f06`.
- Account identity is masked as `*******732`; no password, token, or complete login is emitted.
- Sunday preflight rehearsal: **NO_GO** — 17 GREEN / 8 RED / 3 NOT_CHECKABLE.
- The terminal and its current AutoTrading state were only read. The tools contain no install, launch, attach, or AutoTrading mutation path.

The NO_GO result is expected and useful. It prevents the current pre-Sunday trial from being mistaken for the Sunday generation. The eight RED checks are: governed Daily-Loss anchor, Prague rollover configuration, Kill-Switch runtime proof, book tag/generation identity, fill-fidelity evidence, DST audit, news audit, and sleeve-attribution sidecar. Launch-day account-clean and post-attach proofs remain explicitly NOT_CHECKABLE.

## Delivered behavior

`tools/strategy_farm/ftmo/genesis_manifest.py`:

- `build` accepts both `qm.ftmo-demo-roster/v1` and `qm.ftmo-book-roster/v1`, validates `magic = ea_id*10000+slot`, binds selected active registry rows, and writes canonical JSON plus Markdown.
- Every sleeve records source, installed EX5, installed setfile, symbol, timeframe, magic, slot, role, risk and normalized weight. The manifest also records FTMO risk limits, Daily/Maximum Loss controls, rollover, news/weekend/session policies, governor, request-safety limits, logging, attribution sidecar and generation identity.
- `verify` recomputes every bound hash and registry semantic and exits non-zero on any drift.
- `seal-launch` fills a UTC launch timestamp exactly once. A launched manifest cannot be rebuilt or resealed; a changed generation requires a new file.
- `manifest_sha256` is SHA-256 of canonical sorted JSON with that field set to null, avoiding a self-referential hash.

`tools/strategy_farm/ftmo/sunday_preflight.py`:

- Emits schema `qm.ftmo-sunday-preflight/v1` with one row for every OWNER section-R check and only `GREEN`, `RED`, or `NOT_CHECKABLE` states.
- Recomputes artifact, EX5, setfile, registry, governor, Daily/Maximum Loss, rollover-helper, combined-open-risk, generation identity and weight checks.
- Requires explicit evidence declarations for runtime/research checks; a claimed GREEN is rejected if its evidence path does not exist (and can optionally require an exact marker).
- A critical RED yields `NO_GO`; absent launch-dependent proof yields `PENDING`, never GO.

## Rehearsal artifacts

- `docs/ftmo/genesis/FTMO_DEMO_GENESIS_MANIFEST_FTMO_DEMO_BOOK_V3_D2G6_20260918.json` and `.md`
- `docs/ftmo/genesis/FTMO_DEMO_GENESIS_MANIFEST_FTMO_DEMO_BOOK_V3_D2G6_20260918.verify.json`
- `docs/ftmo/genesis/SUNDAY_PREFLIGHT_FTMO_DEMO_BOOK_V3_D2G6_20260918.json` and `.md`
- `preflight_evidence_rehearsal.json` (explicit inputs for non-automatic checks)

The rehearsal manifest has `launch_timestamp_utc = null`, `status = PRELAUNCH_MUTABLE`, and `inventory_scope = READ_ONLY_PRE_SUNDAY_REHEARSAL`. It may be regenerated as the current D2g6 artifacts evolve, but it must not be presented as the immutable Sunday launch manifest.

## Verification

```text
python -m pytest tools/strategy_farm/tests/test_ftmo_genesis_manifest.py -q
.....                                                                    [100%]
5 passed

python tools/strategy_farm/ftmo/genesis_manifest.py verify <rehearsal-manifest> --report <verify-json>
status=PASS, drift_count=0

python tools/strategy_farm/ftmo/sunday_preflight.py <rehearsal-manifest> --evidence-config <config> --output-json <json> --output-md <md>
decision=NO_GO, GREEN=17, RED=8, NOT_CHECKABLE=3, exit=2 (expected fail-closed result)
```

The focused tests cover a clean manifest, installed-EX5 drift, missing Kill-Switch configuration proof, launched-file immutability, and one-time sealing.
