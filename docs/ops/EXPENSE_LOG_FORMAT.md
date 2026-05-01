# Expense Log Format — V5

Canonical machine-readable expense ledger for the build-in-public commitment.

## Files

- **CSV (source of truth):** `expenses/expenses.csv`
- **Public markdown summary:** `expenses/PUBLIC_EXPENSE_LOG.md`
- **Private companion:** `.private/VPS_SERVER_RECORD.md` (referenced from `evidence_link` for VPS rows; never published)

The CSV is the canonical record. The markdown table mirrors it for humans; the dashboard / Notion page consume the CSV.

`public-data/*.json` is reserved for hourly JSON snapshots produced by `scripts/export_public_snapshot.ps1`. The expense log is a slow-moving manually-curated CSV, so it lives in `expenses/`, not `public-data/`. Future automation may render a derived `public-data/expenses.json` from this CSV; the CSV stays canonical.

## Schema

```
date,item,vendor,category,amount_eur,note,evidence_link,episode
```

| Column | Required | Notes |
|---|---|---|
| `date` | yes | `YYYY-MM-DD`. Use the order/invoice date, not the delivery date. |
| `item` | yes | Short description of what was bought. |
| `vendor` | yes | Provider name (Hetzner, MyOEM, Darwinex, …). |
| `category` | yes | One of: `Infrastructure`, `Software licenses`, `Data & feeds`, `Hosting & ops`, `Tools`, `Reserve`. |
| `amount_eur` | yes | Net amount in EUR with 2 decimals. Use `0` for pending / zero-cost rows. |
| `note` | yes | Plain-language context. **Do not** include order IDs, server IDs, ticket numbers, IPs, ports, login names, license keys, or invoice numbers. |
| `evidence_link` | yes | Repo-relative path or URL where supporting evidence is kept. For VPS rows, point at `.private/VPS_SERVER_RECORD.md`. Use `—` if no evidence yet (pending rows only). |
| `episode` | optional | YouTube episode tag (`EP02`) when the expense is discussed on camera. `EPxx` if not yet recorded. |

CSV quoting: any field containing a comma or double quote must be wrapped in `"..."` per RFC 4180. UTF-8 without BOM. Unix line endings (LF).

## Hard rules (CLAUDE.md alignment)

- **Never publish:** account numbers, server IDs, order IDs, ticket numbers, IPs, custom ports, KVM URLs, usernames, license keys, password fields, invoice numbers, OWNER's personal financial information.
- **Allowed in `note`:** SKU family (e.g. "AX42-U"), region in generic form (e.g. "EU"), category of add-on (e.g. "1 TB NVMe add-on"), billing cadence.
- **Evidence redaction:** if evidence is a screenshot, store it under a private path and reference it via `.private/...`; do not commit the raw image. Public evidence (vendor pricing pages, public order confirmations without identifiers) may link directly.

## Adding a row

1. Capture the receipt / order confirmation. If it contains private identifiers, add the detail to `.private/VPS_SERVER_RECORD.md` (or a new `.private/<vendor>_RECORD.md`) before touching the CSV.
2. Append a row to `expenses/expenses.csv`. Keep rows ordered by `date` ascending.
3. Mirror the row into the `## Detailed Log` table in `expenses/PUBLIC_EXPENSE_LOG.md`.
4. Update the running totals in the `## Summary` block.
5. Commit with message: `expenses: add <vendor> <item> <amount_eur> EUR (<date>)`.

For corrections (vendor refund, reclassification): add a new row with negative `amount_eur` rather than editing history; reference the original row's `date` + `item` in `note`.

## Acceptance for P0-15 (reference)

- `expenses/expenses.csv` exists with at least the Hetzner setup + first-month rows. ✅
- This format doc explains how future rows are added. ✅
- `PROJECT_BACKLOG.md` P0-15 links to `expenses/expenses.csv` and this doc.
