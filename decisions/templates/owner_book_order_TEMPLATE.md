# OWNER Book-Build Order -- TEMPLATE

This template documents the exact artifact `book_build_guard` accepts as the second
mandatory authority for book-build ANALYSIS entry (the first is
`qualified_pairs >= 25`). See `docs/ops/BOOK_CEREMONY_RUNBOOK_2026-09.md` sections 1.1
and 1.2, and `tools/strategy_farm/book_build_guard.py`.

This TEMPLATE file is documentation only. It lives under `decisions/templates/` and is
NOT itself an order: `book_build_guard._find_owner_order` globs
`decisions/*_owner_book_order_*.md` non-recursively (`book_build_guard.py:124`), so
files in this `templates/` subdirectory are never scanned, and the template filename
does not match the order regex anyway.

Do not hand-edit real order files. Generate them with
`tools/strategy_farm/mint_owner_book_order.py`, which emits the exact filename and the
exact `OWNER-ORDER:` line and can round-trip the result through the guard parser.


## 1. Filename (exact)

The guard requires this filename regex (`book_build_guard.py:33-36`):

```
^(?P<date>\d{4}-\d{2}-\d{2})_owner_book_order_(?P<venue>dxz|ftmo|both)\.md$
```

So the file MUST be named, and MUST live directly in `decisions/`:

```
decisions/<YYYY-MM-DD>_owner_book_order_<dxz|ftmo|both>.md
```

Example: `decisions/2026-11-14_owner_book_order_dxz.md`.


## 2. Mandatory content line (exact)

Somewhere in the file, one line MUST read verbatim (leading/trailing whitespace is
stripped by the guard, but the interior must match exactly, `book_build_guard.py:150`):

```
OWNER-ORDER: BOOK_BUILD <venue> <date>
```

The `<venue>` and `<date>` tokens are taken FROM THE FILENAME, not from anywhere else
in the file, and must therefore match the filename (`book_build_guard.py:150`). For the
example filename above the line is exactly:

```
OWNER-ORDER: BOOK_BUILD dxz 2026-11-14
```

The line must appear as its own line. Do not prefix it with a Markdown list marker
(`- `), blockquote (`> `), or code fence content that would change the stripped text --
the guard compares the whole stripped line for equality, so `- OWNER-ORDER: ...` does
NOT match. The file is read as `utf-8-sig` (`book_build_guard.py:152`), so a UTF-8 BOM is tolerated.


## 3. Validity rules (`_find_owner_order`, `book_build_guard.py:116-170`)

- The date must not be in the future relative to `dt.date.today()`
  (else `owner_order_future_dated`).
- A syntactically well-formed but impossible date (e.g. `2026-13-45`) is
  `owner_order_invalid_date`.
- The venue must be COMPATIBLE with the requested venue
  (`_compatible_order_venues`, `book_build_guard.py:110-113`): a `dxz` request accepts a
  `dxz` or `both` order; an `ftmo` request accepts an `ftmo` or `both` order; a `both`
  request needs a `both` order.
- If the `OWNER-ORDER:` line is missing or misspelled: `owner_order_invalid`.
- If no matching file exists at all: `owner_order_missing`.

A typo in the line therefore fails CLOSED (the guard refuses the build) -- it never
silently authorizes anything.


## 4. Skeleton (do not commit as-is -- mint instead)

```
# OWNER Book-Build Order -- <VENUE> -- <YYYY-MM-DD>

- Venue: <dxz|ftmo|both>
- Effective date: <YYYY-MM-DD>
- Author: OWNER
- Generated (UTC): <ISO-8601 timestamp>
- Session: <session id or url>
- Generator: tools/strategy_farm/mint_owner_book_order.py

OWNER-ORDER: BOOK_BUILD <venue> <YYYY-MM-DD>

## What this authorizes
Entry into book-build ANALYSIS (dry-run/analytic) for the <venue> venue on the
effective date. Nothing more. See the ceremony runbook for the full step list.

## What this does NOT authorize
Live weights, T_Live writes, AutoTrading, or a risk-freeze lift. Those remain
separate OWNER acts.
```


## 5. How to produce and check a real order

Mint into a SCRATCH directory (never `decisions/` from an AI seat):

```powershell
python tools/strategy_farm/mint_owner_book_order.py `
  --venue dxz --date 2026-11-14 `
  --order-dir <scratch-dir> `
  --author OWNER --session <session>
```

Preview the exact content without writing:

```powershell
python tools/strategy_farm/mint_owner_book_order.py --venue dxz --date 2026-11-14 --dry-run
```

Validate a candidate file by round-tripping it through the guard's own parser:

```powershell
python tools/strategy_farm/mint_owner_book_order.py --validate <path-to-order.md>
```


## 6. Signing

The order is effective only when the OWNER COMMITS the generated file into `decisions/`
with an explicit pathspec (Worktree Discipline, CLAUDE.md). Minting the file authorizes
nothing on its own -- the OWNER's commit IS the signature. No AI seat writes an order
file into `decisions/`; the minter refuses that path unless the caller is the OWNER and
passes `--i-am-owner`.
