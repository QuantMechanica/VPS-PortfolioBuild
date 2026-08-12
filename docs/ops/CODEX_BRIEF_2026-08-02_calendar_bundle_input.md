# CODEX BRIEF 2026-08-02 — calendar-bundle as an effective EA input + requal scope

**Author:** Claude. **Implementer:** Codex (Sol, effort max). **Reviewer:** Claude
(adversarial, ≥90 % before the recompile ships). **Authority:** OWNER 2026-08-02
(verbatim: „Mach die Frameworkänderung und kompiliere EAs ab Gate Q08 neu, damit
sie Q09 passieren können. Bzw ab dem News-Gate müssen sie neu verifiziert
werden, oder? Löse das und berate dich wieder mit Codex!").

**Predecessor (APPROVED):** `docs/ops/evidence/2026-08-02_q09_news_executor.md` —
its defer stands: the Q09 planner writes `qm_news_calendar_bundle_id`,
`qm_news_calendar_expected_sha256`, `qm_news_calendar_common_relative_path`
into every cell setfile, and **no `.mq5`/`.mqh` consumes them** (verified
repo-wide, zero hits). The executor fails the first cell until the bundle is an
effective tester input.

**Hard constraints:** the LIVE news path is untouchable — live verdicts come
from the native MT5 calendar (FW-LIVE 2026-06-28, OWNER) and this change must
not alter a single live-path branch; `qm_news_stale_max_hours` stays ≤336 and
no fail-closed check is weakened; builds are SERIAL (magic-resolver race);
no T_Live contact; no deploy; factory keeps running; explicit-pathspec commits.
No enqueues (Claude runs the chains after review).

## Part 1 — the framework change

In `QM_NewsFilter.mqh` (and `QM_Common.mqh` wiring as needed), make the three
bundle fields declared EA inputs that the TESTER path consumes:

- when all three are set: the tester CSV loader must resolve the
  content-addressed bundle at the sealed FILE_COMMON relative path, verify its
  SHA-256 against `qm_news_calendar_expected_sha256` **before parsing**, and
  fail closed (`SETUP_DATA_MISSING` / refuse init) on absence or mismatch —
  never fall back silently to the legacy directory;
- when unset (legacy setfiles): behavior byte-for-byte identical to today —
  fixed `D:\QM\data\news_calendar` directory with the established filename and
  FILE_COMMON basename fallback;
- the effective inputs must appear in the MT5 report's Inputs region (they are
  plain `input string`s), because the Q09 executor authenticates them there;
- log one structured event on bundle load (bundle id, sha, rows) so evidence
  binds the actual bytes used.

Add focused MQL-side proof where the framework test idiom allows, and the
Python-side guardrail test: the Q09 executor fixture EA report must show the
three fields consumed.

## Part 2 — recompile set

Serial standard-lane builds (`compile_ea.py --force`) for the admission
candidates only: **11422, 13013, 13036, 20048, 10440**. Zero errors/warnings
required; record EX5 hashes. Do NOT recompile the live book's EAs in this
ticket — they are admitted and deployed; touching them re-opens MNT-043 for no
Q09 need.

## Part 3 — the requalification-scope question (OWNER's „ab Q08?")

Adjudicate adversarially, do not assume my position is right.

**Claude's author position:** restart the candidate chains **from Q02** on the
post-change binary. Grounds: (a) the vintage doctrine ratified this week —
new EX5 hashes cannot inherit historical evidence; (b) the chains have barely
started (one Q02 PASS + one Q04 PASS_LOWFREQ exist, ~1–2 terminal-hours), so a
restart is cheap and unimpeachable; (c) a narrower scope would need a
behavior-identity proof whose cost likely exceeds the early gates it saves.

**The alternative OWNER floats (requal only from Q08 / the news gate):** it is
honest ONLY with a behavior-identity proof: with the new inputs UNSET, the
post-change EX5 must produce **identical trade lists** to the pre-change EX5 on
reference windows (per candidate, at least one full Q02-class window,
deal-by-deal comparison, hash-bound reports). If that proof holds, the change
is demonstrably inert without the inputs, and inheriting Q02–Q07 becomes an
OWNER-decidable exception in the MNT-043 admission-priority style. Estimate
both paths' machine time honestly and recommend one. If the identity proof is
cheaper AND rigorous, say so; if it is fragile (e.g. any include touched that
feeds sizing/ordering), say that instead.

## Deliverable

`docs/ops/evidence/2026-08-02_calendar_bundle_input.md`: the diff rationale
with live-path untouchability argued line-by-line, verbatim compile + test
output, EX5 hash table (old→new per candidate), the requal-scope adjudication
with both cost estimates and a single recommendation, and the exact ordered
command list per candidate chain for Claude. Router task → REVIEW.
