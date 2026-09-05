# Review 4 — FTMO positive-evidence acceptance test R5

Router task: `2b25f7a4-4dc2-48e5-a820-e32de459f4c9`

## Verdict

**PASS — RATIFIABLE as a predeclared positive-evidence test.** R5 applies the
three mechanical findings from Review 3 correctly. It is suitable for OWNER
ratification before any evaluation result is opened. Ratification cannot lift
NO-BUY today: the document expressly keeps the lift path inert until its named
population/power choices and C-6 estimator are resolved, and it leaves purchase
as a separate signed OWNER decision.

Reviewed bytes:

- path: `docs/ops/OWNER_VORLAGE_2026-09-05_ftmo_positive_evidence_test.md`
- commit: `d9fa021091`
- raw SHA-256: `a220324e7a4697d9799d82938d453c6171b809fdf6217b9522f6930a51e998a4`
- LF-normalized SHA-256: `de549514fd75e68adb6f972a39451c89b43d7f7e35961e6e3da197903bfa923d`
- line count: 506
- current file content matches the `d9fa021091` tree.

## Findings

### F1 — right censoring: closed

The text now matches `evaluate_phase()` and `rolling_outcomes()`:

- `rolling_outcomes()` admits every eligible start; it does not require a full
  remaining horizon.
- `evaluate_phase()` returns a breach or PASS immediately when an observed day
  satisfies that condition. It returns `TIMEOUT` only if the available trace
  ends without a terminal event.
- A synthetic 96-day daily trace reproduced exactly 96 rolling starts, 37 with
  a complete 60-calendar-day horizon and 59 horizon-truncated starts. Therefore
  `96 - 37` is not the number of right-censored results; that count depends on
  the unopened outcomes. R5 states this correctly in the revision note, §1,
  §C.4 R-2d, and §G.

### F2 — seal digests: closed

All static digests declared in §E were recomputed against the current bytes.
Every authoritative LF digest matches:

| Seal item | File(s) | Result |
|---|---|---|
| 3 | FTMO rulepack | `298ef128…` MATCH |
| 5 | `ftmo_timebox_eval.py` | `5a3f522d…` MATCH |
| 6 | P1 MC / first-passage / rules engine / rule contract | `80e57bce…` / `fc3b58c9…` / `2c79ccd2…` / `02adb2eb…` MATCH |
| 7 | builder / scorer / counter | `5cf70d3f…` / `cb9c3989…` / `e3ba4737…` MATCH |
| 8 | DSR / Q16 lineage / census | `906bef88…` / `177313cb…` / `1c0ffccd…` MATCH |
| 12 | concentration/tail policy | `ef8b10ec…` MATCH |
| 15 | probability contract JSON | `5b4e24eb…` MATCH; raw equals LF |
| 16 | probability contract loader | `c6c8ddf6…` MATCH; raw equals LF |
| 17 | Layer-A correlation producer | `4b3c2888…` MATCH |
| 18 | probability/correlation contract | `e25eceb8…` MATCH |

Dynamic seal items remain correctly specified as seal-time artifacts rather
than pretending that not-yet-created evidence already has a digest.

### F3 — R-2 coupling wording: closed

R5 no longer derives independence from the moving-block implementation. It
states that overlapping bootstrap selections are not independent market
observations and identifies `W_min = ESS_min` as an explicit, conservative
OWNER-chosen coverage policy (`OWNER-CHOICE`, OQ-2c). The numeric criterion and
recommendation remain predeclared without presenting the 1:1 coupling as a
statistical identity.

## Residuals

No ratification blocker remains from Review 3. The document explicitly declares
the known citation drift caused by `7f56e1c825`: loader validation anchors are
six lines later and builder post-import anchors are one line later. Direct
inspection confirms the referenced behavior is unchanged (loader inert-gate
checks now at 123-126, P1 at 127-128, DSR at 129-130; builder floors at 59-62).
R5 assigns the mechanical citation refresh to the already-required seal-time
OQ-8 re-verification. That is an acceptable residual because no threshold,
population, gate state, or digest is ambiguous.

Minimal diff not applied: **none**. The exact R5 bytes are ratifiable.

## Single-pass orchestration verification

Reverified from the canonical checkout on 2026-09-05 before committing this
previously uncommitted draft. The document matches the exact requested raw and
LF hashes and the `d9fa021091` tree after line-ending normalization. All 17
static file digests in the seal match. The 96-start fixture reproduced 37 full
horizons and 59 truncated horizons; separate short fixtures returned PASS,
DAILY_LOSS_BREACH, and TIMEOUT as described above. No real evaluation outcomes
were opened.

Full paths, raw/LF hashes, checkout commit, and verification timestamp are in
`2026-09-05_review4_ftmo_positive_evidence_test_verification.json` beside this
review. The scheduler instruction requires evidence commits on
`agents/board-advisor`; that explicit instruction governs this artifact's
branch despite the older task payload naming `agents/codex`. Router state is
left at REVIEW for the independent close-out.
