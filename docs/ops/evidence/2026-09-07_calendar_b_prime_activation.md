# Calendar criterion B-prime and scoped consumer activation — REVIEW

Task `934e6104-a081-497e-b3d9-e5d96fc62bc6` implements the OWNER YES
`OWNER-DEC-CALENDAR-CRITERIA-B-PRIME-20260907`, receipt
`617abd80-f0d9-49b4-b817-e82abf0ad381`. The result is a content-addressed
adjudication contract and a read-only production dry run. No calendar was
published or repinned, no hold was released, and no T_Live, AutoTrading,
Q-gate threshold, or existing verdict was changed.

## Contract

`news_calendar_gate.py` now defines and validates the exact B-prime rule:
every measurable gate must be `MEASURED_PASS`; the only permitted declared
residual kinds are the three OWNER-named kinds; any unknown kind, duplicate,
count mismatch, in-boundary footprint assigned to the history residual,
content drift, source drift, or unclassified residual fails closed. The seal
explicitly carries `publication_authority=false` and
`hold_release_authority=false`.

`news_calendar_full_scope_seal.py` inventories the exact E1-D3/D4 sources and
embeds the content-addressed B-prime criteria seal in the full-scope report.
The production candidate inventory is:

| Permitted residual kind | Entries | Count | Unit / reason |
|---|---:|---:|---|
| Event-by-event HIGH without official release schedule | 40 classes | 1,865 | HIGH rows; every class is named and counted |
| Tick footprint beyond factory custom history | 19 instants | 19 | Every instant is strictly after `2024-12-31T23:59:59Z` |
| Non-USD without confirmed fresh official anchor | 5 currencies | 152 | AUD/CAD/EUR/GBP/JPY fresh-export rows |

Five additional non-PASS footprints lie within the factory-history boundary;
all five are non-USD and are enumerated inside the applicable non-USD residual
class. The sealed inventory therefore has zero unclassified residuals.

The report deliberately preserves the legacy full-publication outcome
`NOT_READY_FAIL_CLOSED`: gates 6.1, 6.2, 6.5, and 6.7 are not all measured
PASS, candidate ingress remains refused, and no publication plan is emitted.
B-prime is available only to the separately OWNER-approved scoped Q10
adjudication consumer.

Machine seal/report:
`docs/ops/evidence/2026-09-07_calendar_b_prime_full_scope_contract.json`
(SHA-256 `f2d359a81224cd9fdcea2f72d6a200a7b1c533447f462466410c7c38416c6cef`;
embedded criteria seal
`cfd6f63a59a615ddb90a7b5de6d4f360b9d0a8d45009e06adf55fdd9e9522d6d`).

## Consumer B-prime boundary

The activation config is rebound to the B-prime OWNER receipt and exact
criteria report. It accepts every recognized MT5 timeframe, but only when the
row is pending Q10_NEWS, its complete exposure is exactly USD, and its Q10
window is cryptographically sealed. A row containing any non-USD exposure is
still held. Declaration overlap is recorded as scoped residual evidence for a
USD-only row and cannot make a non-USD row admissible. The marker schema and
exact footnote **“Kalender scope-begrenzt”** are unchanged; release mode
remains `OWNER_ROW_BY_ROW`, and re-adjudication ticket
`235e5119-061d-406a-a58c-4d7d6cd3535a` remains bound.

## Production dry run

The read-only run covered all 31 current, non-superseded pending Q10_NEWS
rows: **12 ADMISSIBLE, 19 EXCLUDED**.

Admissible rows:

| Work item | EA | Symbol | TF |
|---|---|---|---|
| `745671a4-02e4-4df5-b5e1-e25f0e41ca0e` | QM5_11129 | SP500.DWX | D1 |
| `ee4ff9b4-41a3-4e74-b5ec-de548ed47113` | QM5_10771 | XAUUSD.DWX | H1 |
| `f625d9aa-da34-44bb-aa9f-0eda284f3f32` | QM5_11167 | XAUUSD.DWX | D1 |
| `a909ee18-9f16-4706-967e-daa080b6f720` | QM5_11196 | XAUUSD.DWX | H4 |
| `c18cf1fa-60c0-498e-82db-637fc8320f58` | QM5_12567 | XAUUSD.DWX | D1 |
| `ca96d7bf-51e0-4417-a5c6-94546e9d9946` | QM5_10513 | XAUUSD.DWX | D1 |
| `f15ac955-9dbb-4f39-9a9e-8eb142f11138` | QM5_10145 | SP500.DWX | D1 |
| `136b0e0f-7896-4e0c-b34b-47991cc49342` | QM5_10513 | XAUUSD.DWX | D1 |
| `450fb9f6-9797-496d-937e-9bddc5f292a8` | QM5_10513 | XAUUSD.DWX | D1 |
| `abea4df5-c03b-494a-a025-37747d0a1e32` | QM5_10513 | XAUUSD.DWX | D1 |
| `6d528b09-59d8-4c2f-bfb2-a1102e8ae12c` | QM5_1230 | XAUUSD.DWX | D1 |
| `b6e02932-d34d-4fea-8f3c-f977c8efe7eb` | QM5_1556 | XAUUSD.DWX | D1 |

`a909ee18` is therefore admissible as expected: H4, USD-only, sealed window,
and no exclusion reason.

Excluded rows by exact reason combination:

| Reason combination | Rows |
|---|---:|
| `NON_USD_EXPOSURE` | 4 |
| `NON_USD_EXPOSURE` + `SEALED_Q10_WINDOW_UNAVAILABLE` | 11 |
| `SEALED_Q10_WINDOW_UNAVAILABLE` | 4 |

The machine-readable dry run lists every row, its verdict, all reasons,
exposure, window proof, declaration-overlap digest, and assessment digest:
`docs/ops/evidence/2026-09-07_calendar_b_prime_scoped_dry_run.json`
(SHA-256 `17381a428634ee92b38e626ab9220c2fc075b5fa256199c4c712c87adfd32527`).

## Verification

Focused contract, matrix, tamper, candidate-ingress, repin, and gate suite:

```text
python -m pytest -q \
  tools/strategy_farm/tests/test_news_calendar_full_scope_seal.py \
  tools/strategy_farm/tests/test_news_calendar_scoped_activation.py \
  tools/strategy_farm/tests/test_news_calendar_gate.py \
  tools/strategy_farm/tests/test_news_calendar_candidate_ingress.py \
  tools/strategy_farm/tests/test_news_calendar_repin.py
```

Result: `59 passed in 5.80s`. The matrix proves H4/USD-only admissible and
H4/EUR exposure excluded; tamper tests cover the criteria content seal,
candidate hash, marker binding, and scoped Q09 window seal.
