# FABLE-DEC-VELOCITY-INTAKE-20260920 — governed force-rebuild wave for the Velocity intake

**Authority:** OWNER-DEC-FABLE-FULL-EXECUTIVE-AUTHORITY-20260917 (Fable executes; OWNER 2026-09-20:
"solange Kapazitäten irgendwo vorhanden sind, kannst du die Priorität auch jetzt schon auf das
Velocity-Buch legen"). Scope: **COMPILE_EA force-rebuild only** for the intraday cards listed below —
no verdict, gate, live, deployment or portfolio authority. Every rebuilt `.ex5` is a NEW build
identity from Q02 (23.08. identity rule); old rows stay as append-only evidence.

**Why a rebuild is needed:** these EAs carry a COMPILE_OK receipt from 2026-08-26 but the binary the
receipt binds is no longer on disk — the worktree janitor restored the tracked pre-receipt `.ex5`
(class fixed in `cb53061862`) or the untracked binary was never committed (class fixed in
`65dbf8a704`). `intake-first-q02` therefore refuses with `compile_ex5_sha256_mismatch` /
`canonical_ex5_not_exactly_one`, and the ordinary compile guard refuses the rebuild with
`WORK_ITEMS_EXIST` / `EX5_ALREADY_PRESENT`. Fail-closed in the same shape as
OWNER-DEC-REQUEUE-LIFT-20260916-D4: the code list AND this document must both name an EA.

| EA | timeframe | stale COMPILE_OK | refusal at intake |
|---|---|---|---|
| QM5_11299 lwma144-smma5-fractal-m5-scalp | M5 | 42f036ac | compile_ex5_sha256_mismatch |
| QM5_11496 carter-t-ema100-psar-macd64128-m5 | M5 | 4fa03b66 | compile_ex5_sha256_mismatch |
| QM5_11516 carter-t-sma7-21-cci5-m15 | M15 | 20d69e5e | compile_ex5_sha256_mismatch |
| QM5_11518 carter-t-ema5-100-mtf-m15-h1 | M15 | c892c9dd | compile_ex5_sha256_mismatch |
| QM5_11291 tc20-ema18-28-wma5-12-rsi21-h1 | H1 | d0cb9e32 | canonical_ex5_not_exactly_one |
| QM5_11292 trix14-signal-cross | H1 | 74a0858e | canonical_ex5_not_exactly_one |

Procedure: `farmctl enqueue-compile <label>` → `release_compile_wave.py --apply` → COMPILE_OK →
binary committed under its receipt (janitor or manual, explicit pathspecs) → `intake-first-q02 --apply`
(RAM-ranked canary, never SP500). Revocation: remove the EA from this document.
