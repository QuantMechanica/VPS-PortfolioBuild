# SP-D9 dependency/retention dry-run — gate

Date: 2026-08-22  
Router task: `2f36c28c-6430-4a55-8af7-8d213f372cc6`  
Depends on: SP-D1 and ROT-9  
Verdict: **DEFER — no complete corpus manifest or OWNER retention policy exists**

SP-D9 must prove, before any move or deletion, that every proposed action preserves absolute path references, ledger linkage, inventory identity, and reproducibility. That proof needs two inputs which are not available:

1. SP-D1 did not produce the required content-addressed 130/130 corpus manifest because the per-user `G:` archive is inaccessible to this headless task.
2. No separately routed, approved, or signed ROT-9 manifest-first retention decision is present in deterministic router records or canonical evidence.

The 2026-08-21 filesystem inventory is useful baseline evidence and is read-only, but it is not an SP-D9 action manifest. It hit explicit 200,000-entry caps on `C:/QM` and `D:/QM/reports`, reports 14,783 nodes as `candidate_for_cleanup_review`, and intentionally provides no delete action. Turning those broad review candidates into proposed moves without SP-D1/ROT-9 would invent scope and could sever paths the task requires us to preserve.

## Dry-run contract once dependencies are open

Each proposed action row must be content-addressed and include:

- exact absolute source path and proposed destination or retention disposition;
- current file SHA-256, byte size, media type, and SP-D1 `source_id`;
- every referencing ledger/inventory/card/report row and its own identity;
- a lexical and resolved-path before/after projection;
- a reproduction check proving all referenced inputs still resolve to identical bytes;
- collision, duplicate-content, and cross-volume semantics;
- explicit `would_move`, `would_archive`, or `would_delete_after_owner_approval` state;
- ROT-9 decision hash and `apply_authorized=false` for the dry run.

Acceptance requires zero unresolved absolute-path, ledger, inventory, or reproduction references. Any unresolved reference keeps that row out of a future apply set.

No dry-run action rows were fabricated, and no file was moved, archived, deleted, renamed, or re-linked. Existing inventory and backup retention were untouched.
