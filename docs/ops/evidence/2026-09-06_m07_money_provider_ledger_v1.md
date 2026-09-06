# M07 — Money and provider-status ledger v1 (schema + coverage) — 2026-09-06

Task `3a20271f-94ba-4aac-b18f-71db644893c1` (M07, CEO audit integration `docs/ops/CEO_AUDIT_INTEGRATION_2026-09-05.md:1` measure map row M07). Read-only intake from local documents only; no portal access; no purchase; no live-book or gate mutation. **This repo doc deliberately carries NO amounts, account numbers, invoice ids, provider account identifiers, credentials, or hostnames** — those live only in the local runtime state files below, which are never published.

## What was produced

| Artifact | Path | Published? |
|---|---|---|
| Cash-flow / invoice ledger | `D:/QM/reports/state/cash_ledger_v1.json` (schema `qm.cash-ledger/v1`) | No — local runtime state |
| Provider status | `D:/QM/reports/state/provider_status_v1.json` (schema `qm.provider-status/v1`) | No — local runtime state |
| This schema/evidence doc | `docs/ops/evidence/2026-09-06_m07_money_provider_ledger_v1.md` | Repo |

Both JSON files are new (no prior version on disk); nothing was deleted or overwritten.

## Ledger schema `qm.cash-ledger/v1`

Per-entry fields (each entry cites the local file it came from):

- `date`, `kind` (one of `payout` \| `fee` \| `subscription` \| `refund` \| `other`), `provider`
- `amount`, `currency`, `recurrence` (`monthly` \| `one_time`)
- `source_path`, `source_sha256` (or `source_note`), `confidence`

Aggregates block: `received_payouts_total`, `monthly_opex_estimate`, `coverage_from`, `coverage_to`, `coverage_note`, `entry_count`, `gaps[]`. A `kpi_projection` block mirrors the aggregates under the exact KPI-tile key names (below). Currencies are carried per entry and per aggregate; **no FX conversion is applied** (venue account currency is USD per `framework/registry/venue_cost_model.json`, infra cost is in EUR).

## Provider-status schema `qm.provider-status/v1`

Per provider: `provider`, `status`, `evidence_path`, `last_verified_utc`, `notes`. Status vocabulary: `LIVE` / `ACTIVE` / `PARKED` / `UNKNOWN`.

## Source classes actually found on disk

| Class | Rows | Local source class | Confidence |
|---|---|---|---|
| Infrastructure recurring cost | 1 | Private operational VPS record (kind `subscription`, monthly) | medium |
| Infrastructure one-time cost | 1 | Same VPS record (kind `other`, one-time setup) | medium |

`entry_count = 2`. The infrastructure amounts come from a self-authored operational record, **not a billing invoice/statement**, hence confidence `medium`. No account statement, payout export, or invoice PDF exists anywhere under `D:/QM/exports` or `D:/QM/reports` (searched); therefore every payout and every provider-fee class is a gap, not a zero.

## Coverage window

`coverage_from = coverage_to = 2026-04-22`. The ledger is *intended* to span company bootstrap (2026-04-22) → as-of (2026-09-06), but only one dated cost document with figures was found, so realised coverage is a single date. This narrowness is itself the M07 finding: the money trail is not locally reconstructable without OWNER exports.

## Gaps (OWNER export checklist)

Recorded verbatim in `cash_ledger_v1.json` `aggregates.gaps[]`; summarised here without figures:

1. **Received payouts** — no payout statement/export on disk; DXZ performance fees and FTMO rewards both UNVERIFIED locally.
2. **Darwinex Zero portal** — booked tariff, monthly-payout-option fee, current quote, provider rating, active allocations, received performance fees.
3. **FTMO portal** — evaluation stage, evaluation fee, conditional fee refund, payments. (No account/challenge purchased; the audit's illustrative fee figure is not a confirmed checkout price.)
4. **AI tooling subscriptions** (Claude, Codex/OpenAI, Antigravity) — amounts/terms not on disk.
5. **Data subscription** (Tick Data Suite) — named in bootstrap tooling list without amount/term/active-status.
6. **Per-deal trading commissions** — not file-visible in MT5 journals; only an exported account statement (not on disk) carries them (`framework/registry/venue_cost_model.json` `ground_truth_note`).
7. **VPS billing proof** — documented amounts are from an operational record, not a per-month invoice/statement.

"Not proven" is never rendered as `0` — this follows the audit's explicit rule (`G:/My Drive/QuantMechanica - Company Reference/08 Current State/Audits/2026-09-05 Factory CEO Audit/03 Anbieter und Wirtschaftlichkeit.md`, section 2).

## Provider-status rows and their evidence anchors

| Provider | Status | Evidence anchor |
|---|---|---|
| Darwinex Zero | LIVE | `public-data/funnel-stats.json` live block (`since` 2026-07-24); live-book risk-freeze ACTIVE since 2026-08-31 (`docs/ops/evidence/2026-09-05_ftmo_readiness_part2.md`) |
| FTMO | PARKED | `docs/ops/evidence/2026-09-05_ftmo_readiness_part2.md`; vault `01 Identity/Business Model.md` ("no challenge purchased") |
| VPS dedicated server | ACTIVE | Private operational VPS record (running since 2026-04-22; the factory executes on this host) |
| AI tooling subscriptions | ACTIVE | `CLAUDE.md` Quota Governance section (quota-governed, in use) |
| Data subscription (Tick Data Suite) | UNKNOWN | Named in the VPS bootstrap tooling list; no amount/term/active-status on disk |

## How the ledger feeds the M15 board KPI tiles

`tools/strategy_farm/board_projection.py` names the M07 cash-ledger as the source for two of its six net-KPI tiles (`board_projection.py:11` docstring; `board_projection.py:67-68` `KPI_SOURCES`):

- `received_payouts` → `D:/QM/reports/state/cash_ledger_v1.json`
- `monthly_opex` → `D:/QM/reports/state/cash_ledger_v1.json`
- (`darwin_status` → M07 provider status / M01 release status, `board_projection.py:69`)

At the time of writing, `board_projection.py` renders all six KPIs `UNKNOWN` and does **not yet read** the ledger file (`build_projection` sets each `company_kpis` value to `"UNKNOWN"`; `board_projection.py:388-391`). To make a future wiring a one-liner, `cash_ledger_v1.json` exposes a `kpi_projection` block keyed **exactly** to those tile names (`received_payouts`, `monthly_opex`, `darwin_status`), each `{value, currency, source}`. With only the infra floor known and no payout evidence, `received_payouts` stays `UNKNOWN` (never `0`) and `monthly_opex` is an explicit floor labelled as such — which is exactly what the board's "UNKNOWN, never zero" contract expects until OWNER exports close the gaps. Wiring the reader into `board_projection.py` is a separate, out-of-scope change (this task modified no other file).

## Boundaries honoured

Read-only; no T_Live / AutoTrading / pointer / freeze / gate mutation; no git add/commit/push; no router/farmctl mutation; no external service contacted; no invented figures; unknowns kept UNKNOWN.
