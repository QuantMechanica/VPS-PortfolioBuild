# FB-11 — QM_Branding.mqh "divergence" analysis + proposal

Date: 2026-07-24 · Author: board-advisor audit lane · Status: ANALYSIS ONLY (no include edit applied)

## TL;DR

The premise of FB-11 — "the newer 05-07 orphan holds a divergent edit that the compiled
copy is missing" — **is false**. The two copies are **byte-for-byte identical** (same git
blob `68186a2e…`), the 05-07 commit was a *file creation* (namespace-sync copy), not a
token change, and both files are kept identical automatically by the generator. There is
**nothing to fold**. The only real cleanup is to delete the redundant orphan and stop the
generator from re-creating it. **No `#include` edit is required and no recompile wave is
triggered** (nothing includes the orphan).

## The two files

| Path | Role | `#include`d by | git last-touch | HEAD blob SHA |
|------|------|----------------|----------------|----------------|
| `framework/include/QM_Branding.mqh` | ROOT / compiled | `framework/include/QM/QM_ChartUI.mqh:4` via `..\QM_Branding.mqh` | 2026-04-27 (`210e541e2`) | `68186a2e…` |
| `framework/include/QM/QM_Branding.mqh` | orphan namespace copy | **nothing** | 2026-05-07 (`41544315f`) | `68186a2e…` |

## Evidence — content is identical (not divergent)

```
$ git ls-tree HEAD framework/include/QM_Branding.mqh framework/include/QM/QM_Branding.mqh
100644 blob 68186a2e32307a7c46536a770480b5b3bc599d2f  framework/include/QM/QM_Branding.mqh
100644 blob 68186a2e32307a7c46536a770480b5b3bc599d2f  framework/include/QM_Branding.mqh

$ git hash-object <root> <orphan>          # working tree
68186a2e32307a7c46536a770480b5b3bc599d2f
68186a2e32307a7c46536a770480b5b3bc599d2f

$ git diff --no-index <root> <orphan>       # → no output, exit 0
$ diff <HEAD:root> <HEAD:orphan>            # → "NO DIFF between committed copies"
```

**Textual diff between the two copies = 0 lines.** Both are LF, both hash to the same
blob, in HEAD and in the working tree.

## What the 05-07 "edit" actually was

`git log --follow` on the orphan shows two commits; `git show 41544315f` proves the
05-07 commit was a **`new file mode 100644`** (the whole 41-line file added, identical to
root), with message *"build(framework): sync brand tokens into QM include namespace"*.
`--follow` links it to the root's 04-27 history only because git's rename/copy detection
matches the identical content. The root copy has **never** been modified since it was
created on 2026-04-27. So: **no brand tokens were ever changed on either copy** — the
05-07 commit merely mirrored the file into the `QM/` namespace directory.

## Why the prior audit note said "DIFFERENT content"

`evidence/orphans__item4_includes.txt` records `sha=acadbb5f…` (root) vs `sha=0be8df2d…`
(orphan) and calls them "DIFFERENT content". Those are **not** the git blob SHAs
(`68186a2e…` for both) — they are file-hash (SHA-256) reads over the *working-tree* files.
The most likely cause is an **autocrlf phantom**: one checkout materialised CRLF and the
other LF on disk, yielding different file-hashes while git stores one identical LF blob.
The canonical (blob-level) truth is that the files are identical; the "divergence" is an
artifact of how the files were hashed on disk, not a real token difference.

## Why they stay identical (and can't drift)

`framework/scripts/sync_brand_tokens.ps1` is the generator (it exists and is implemented;
the `[SPEC ONLY — NOT IMPLEMENTED]` markers in `V5_FRAMEWORK_DESIGN.md` / `DL-003` are
stale). Its default `OutputPaths` writes **both** copies:

```
framework/scripts/sync_brand_tokens.ps1:60-63
    $OutputPaths = @(
        (Join-Path $repoRootPath "framework\include\QM_Branding.mqh"),
        (Join-Path $repoRootPath "framework\include\QM\QM_Branding.mqh")
    )
```

Both are regenerated from `branding/brand_tokens.json`; hand-mirroring is forbidden
(`QM_BRANDING_GUIDE.md:235`). So the orphan is a *redundant second generator target*, not a
place edits can silently land — any token change re-writes both identically.

## Brand-direction check (Dark-Mode-v2 / steel-blue #2954d4)

Both MQH copies carry the **emerald/slate** palette (`#020617` bg, `#10b981` emerald),
which **matches `branding/brand_tokens.json`** — the compiled chart tokens are current with
their source of truth. The steel-blue `#2954d4` Dark-Mode-v2 direction lives **only** in
dashboard surfaces (`tools/strategy_farm/dashboards/style.css`, `docs/ops/DESIGN_SYSTEM_V2_2026-07-20.md`)
and has **not** been propagated into `brand_tokens.json`. That dashboard-vs-MT5-chart split
is a separate, source-level brand decision (it would require editing `brand_tokens.json` and
would *intentionally* trigger a recompile wave) — **out of scope for FB-11**, flagged here only
so it is not conflated with this hygiene item.

## Recommendation

**Delete the orphan and stop the generator from re-creating it. No include edit, no recompile.**

Rationale: there is no divergence to fold; the orphan is included by nothing (`ChartUI` reaches
*up* to the root via `..\QM_Branding.mqh`), the QM5_20009 manifest also references the root path,
and deleting a file nothing includes forces **zero** recompilation. Deleting the orphan *without*
editing the generator would only have `sync_brand_tokens.ps1` recreate it on the next run, so the
generator's second output path must go too. This touches neither `QM_ChartUI.mqh` nor any `.mqh`
that participates in a compile — it is safe to apply at any time, but per audit scope it is left
for the orchestrator to apply (post-26.07 or whenever convenient).

Rejected alternative "fold orphan into root then delete": moot — the copies are already identical,
there is nothing to fold.

### Proposed patch (NOT applied)

```diff
--- a/framework/scripts/sync_brand_tokens.ps1
+++ b/framework/scripts/sync_brand_tokens.ps1
@@ -57,10 +57,9 @@ if (-not $TokenPath) {
     $TokenPath = Join-Path $repoRootPath "branding\brand_tokens.json"
 }
 if (-not $OutputPaths -or $OutputPaths.Count -eq 0) {
     $OutputPaths = @(
-        (Join-Path $repoRootPath "framework\include\QM_Branding.mqh"),
-        (Join-Path $repoRootPath "framework\include\QM\QM_Branding.mqh")
+        (Join-Path $repoRootPath "framework\include\QM_Branding.mqh")
     )
 }
```

```
# and delete the redundant orphan (included by nothing):
git rm framework/include/QM/QM_Branding.mqh
```

Net change: `-1` generator line, `-41` orphan file lines. No `QM_ChartUI.mqh` edit, no `.ex5`
rebuild implied.
