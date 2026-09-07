# Scoped calendar consumer B activation — execution evidence

- Task: `f3a94b87-c512-4514-9d0f-8e02253092b1`
- OWNER decision: `OWNER-DEC-COUNTER-PATH-CALENDAR-TAINT-20260907 = YES`, option B
- Receipt: `e1259d10-5bf7-48d4-8059-594159e98445`
- Scope: activation and fail-closed release machinery only; no calendar publish/repin, verdict change, hold release, terminal action, or live action

## Bound activation

The enabled activation config binds the E1-D3/D4 scoped, non-publishable candidate exactly:

- candidate manifest SHA-256: `5f28c2f3bba94c0c7b78dbff93aba0e2dc22bb8cfbe0b1ec484b5a24ed69366a`
- declarations SHA-256: `190a1da82a474191f339114a4e0e32c5f9cf665c9d2e244193bb761f9f23334a`
- primary CSV SHA-256: `ff13a32f836f0b081544d1743a6ca1346669b9fbd2772881b8d160625ea3d2ea`
- secondary CSV SHA-256: `505fc45a73144071b96ff4440cbb9fb3b1ba374c3adaa7285f70849a59975beb`
- resulting B binding SHA-256: `b12615d82d51516443133c0725739ae18d24646aa11b6c825d29879cf690f559`

The loader authenticates all four files and requires `publishable=false` plus `scoped_review_only=true`. Admissibility reuses the E1-C class/month semantics and is narrower by contract: pending `Q10_NEWS`, D1, HIGH-impact, USD-only exposure, authenticated sealed Q10 run plan/input manifest, and no matching declared exclusion. Missing or unknown evidence excludes the row.

`news_calendar_taint.release_scoped_item()` is the only B release path. It requires a caller-owned write transaction, the currently declared tainted pin, an active `NEWS_CALENDAR_TAINTED` hold owned by this policy, and an ADMISSIBLE assessment. It then appends the `news_calendar_scoped_consumer_b` payload marker and releases only that one hold. It does not change status, verdict, evidence, or other holds. The ordinary sweep reports `AWAIT_SCOPED_OWNER_RELEASE` for a valid marker and cannot auto-release it.

## Production dry run

Machine evidence: `docs/ops/evidence/2026-09-07_f3a94b87_scoped_calendar_b_dry_run.json` (SHA-256 `eae63312c6381cc86d9f756a925a15862c16af95b4b205e16f6d233a092f125b`).

- Pending Q10_NEWS rows evaluated: **47**
- ADMISSIBLE: **0**
- EXCLUDED: **47**
- Reason incidence (a row may have several): sealed Q10 window unavailable 38; intraday/unknown timeframe 30; non-USD exposure 19; declared exclusion overlap 9.
- Priority row `a909ee18-9f16-4706-967e-daa080b6f720` (`QM5_11196`, `XAUUSD.DWX`) was included. Its bound timeframe is H4 and its reasons are `INTRADAY_OR_UNKNOWN_TIMEFRAME` and `DECLARED_EXCLUSION_OVERLAP`.
- Active physical `NEWS_CALENDAR_TAINTED` holds on pending Q10_NEWS at observation: 2. The other not-yet-claimed rows remain covered by the claim-time taint guard. **No hold was released or created by this execution.**

Each row in the JSON contains its sealed-window identity where available, exposure-class count, exclusion count, exclusion-ID-set SHA-256/sample, reasons, and assessment SHA-256.

## Counter surfaces and future re-adjudication

Every row that is ever explicitly released through B receives the machine marker and the exact footnote **“Kalender scope-begrenzt”**. `path_to_25` / Mission Control and the Strategy Archive matrix/detail pages derive that label only from the marker. OPEN_ITEMS carries the same disclosure.

Future append-only re-adjudication is durably tracked as router ticket `235e5119-061d-406a-a58c-4d7d6cd3535a` in `BLOCKED`, triggered only by an OWNER B-prime criteria decision or a measured full-scope seal. It explicitly forbids overwriting existing verdicts.

The requested Vault pipeline mirror could not be written by this headless run because drive `G:` was not mounted in the scheduled-task session. OPEN_ITEMS and this canonical evidence record preserve the exact text for the integration reviewer to mirror; this limitation does not weaken claim-time enforcement.

## Verification

Focused suite:

```text
python -m pytest -q \
  tools/strategy_farm/tests/test_news_calendar_scoped_activation.py \
  tools/strategy_farm/tests/test_news_calendar_taint.py \
  tools/strategy_farm/tests/test_path_to_25_metrics.py \
  tools/strategy_farm/tests/test_archive_matrix_v4.py
......................................                                   [100%]
38 passed in 6.88s
```

The tests cover hash drift, D1/USD/class admissibility, declared overlap, intraday/non-USD/missing-seal exclusions, marker tamper refusal, transaction/hold ownership, explicit release, ordinary-sweep non-release, claim boundary behavior, cockpit footnote, and Strategy Archive footnote.

Disposition: **REVIEW**. Integration must retain the OWNER row-by-row release boundary. No B row is currently admissible, so there is nothing to release.
