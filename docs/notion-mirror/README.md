<!--
AUTO-GENERATED MIRROR DIRECTORY — see infra/notion-sync/manifest.yaml.

Files in this directory are produced by the nightly Notion -> Git mirror
routine. Editing surface is Notion. Any edits made directly to these files
will be overwritten on the next sync.

Authoritative source-of-truth files live under:
  - docs/ops/        (Git-canonical operational specs)
  - lessons-learned/ (Git-canonical operational lessons)
  - processes/       (Git-canonical process registry)
  - paperclip-prompts/ (Git-canonical agent prompts; never synced to Notion)

This mirror exists for the public/build-in-public snapshot and to give the
board a diffable record of Notion-side edits over time.
-->

# Notion mirror

This directory mirrors a curated subset of Notion pages into Git for public
visibility and audit history.

- **Manifest:** [`../../infra/notion-sync/manifest.yaml`](../../infra/notion-sync/manifest.yaml)
- **Verification report:** [`../ops/QUA-151_NIGHTLY_EXPORT_VERIFICATION.md`](../ops/QUA-151_NIGHTLY_EXPORT_VERIFICATION.md)
- **Schedule:** daily 23:00 UTC, Paperclip routine assigned to Documentation-KM
- **Commit message:** `docs: nightly Notion sync YYYY-MM-DD` (skip commit if no diff)

## Direction of truth

Notion is the editing surface for the pages in this directory. Local files
in `docs/ops/`, `lessons-learned/`, `processes/`, and `paperclip-prompts/`
are Git-canonical and are **never** overwritten by this sync.

## Per-file format

Each mirror file starts with an HTML comment banner naming the Notion
source page id, the title, the mirror timestamp, and a "do not edit" notice.
The body is the Notion page content as Notion-flavored Markdown.
