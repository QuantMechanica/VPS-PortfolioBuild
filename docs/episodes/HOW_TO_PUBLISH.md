# How to Publish an Episode Pack

**Audience:** assigned documentation worker and OWNER
**Last updated:** 2026-05-09 (QUA-1068)

---

## Where packs live

Episode packs live under `episodes/EP{nn}-{card-slug}/` at repo root.

```
episodes/
  EP01/
    show_notes_draft.md
  EP05-QM5_1003-davey-eu-night/     ← example first card pack
    summary.json                    ← pipeline artifact (not committed; gitignored if sensitive)
    mc_distribution.csv             ← MC artifact
    assets/
      equity_curve.png
      p3_heatmap.png
      mc_distributions.png
    show_notes.md                   ← filled copy of docs/episodes/_template.md
    thumbnail.png                   ← OWNER creates / approves
    script_outline.md               ← optional
```

The template and generator live under `docs/episodes/` (not in episode packs themselves):

```
docs/episodes/
  _template.md                      ← copy this for each new episode pack
  _template_assets/
    gen_plots.py                    ← run from inside the pack directory
    README.md
  HOW_TO_PUBLISH.md                 ← this file
```

---

## Step-by-step: first PASS card to published pack

### 1. Copy the template

```bash
# from repo root — replace EP05 and card slug with actual values
mkdir -p episodes/EP05-QM5_1003-davey-eu-night/assets
cp docs/episodes/_template.md episodes/EP05-QM5_1003-davey-eu-night/show_notes.md
```

### 2. Drop pipeline artifacts into the pack dir

Copy or symlink from the pipeline runner output:

- `summary.json`
- `mc_distribution.csv`

### 3. Generate the charts

```bash
cd episodes/EP05-QM5_1003-davey-eu-night/
python ../../docs/episodes/_template_assets/gen_plots.py
# check assets/ for equity_curve.png, p3_heatmap.png, mc_distributions.png
```

### 4. Fill the template

Open `show_notes.md` and replace every `{{PLACEHOLDER}}`. No placeholders may remain
before the review step. See checklist in Section 9 of the template.

Key constraints from the brand guide and BASIS:

- **First person singular only.** "I" not "we". No guru tone. No hype.
- **Every metric must cite its source.** No fantasy numbers (lessons-learned rule L-K-07).
- **Buy-me-a-coffee CTA must be visually and verbally separated** from any portfolio or
  performance claims. The CTA is project support, not an investment ask.
- **No profit promises, no guaranteed returns, no "proven" claims.** These are forbidden
  per `branding/brand_tokens.json § voice.forbidden`.

### 5. Submit draft to OWNER for review

Create a comment on the relevant QUA issue with:

```
Draft at: episodes/EP{nn}-{slug}/show_notes.md
Commit: <SHA>
Charts: assets/ (equity_curve, p3_heatmap, mc_distributions)
Requesting OWNER sign-off before publish.
```

No publish action until both sign-offs are obtained. If the issue is a Documentation-KM
child, escalate to parent for OWNER visibility.

### 6. Brand application checkpoint (OWNER-gated)

Before any publish:

- Thumbnail reviewed by OWNER (correct palette, no hype imagery, no neon, no red accent).
- Show-notes tone confirmed by OWNER (first person, data-driven, specific learnings cited).
- Buy-me-a-coffee URL confirmed by OWNER (URL is not committed to repo).
- CTA copy separated from performance discussion.

### 7. Publish (OWNER sign-off required)

Publish channels (per `docs/notion-mirror/episode_guide.md`):

| Channel | Who publishes | Notes |
|---------|---------------|-------|
| YouTube | OWNER | Video + description + CTA |
| Blog / show-notes page | OWNER | Based on this pack's show_notes.md |
| Newsletter issue | Documentation-KM drafts, OWNER sends | Separate artifact |
| Buy-me-a-coffee | OWNER | CTA link in all above |

Documentation-KM does not publish directly to any public channel.

### 8. Post-publish

- Archive the pack directory as-is (no deletion, no rename).
- Update `episodes/README.md` with the episode entry.
- Comment on the QUA issue with: published URL, publish date, episode number.
- Mark the Documentation-KM issue done.

---

## Timing expectation

Per QUA-1062 / QUA-1068: when the first card reaches P4 PASS, the episode pack should
ship within 24 hours. The template and generator exist so that step 4 (fill the template)
is the only manual bottleneck.

---

## Review flow summary

```
Documentation-KM fills template
        ↓
OWNER reviews metrics and claims
        ↓
OWNER reviews voice + brand + CTA separation
        ↓        (OWNER-gated checkpoint)
OWNER approves thumbnail
        ↓
OWNER publishes
```

No step may be skipped.

---

## Related files

- `docs/episodes/_template.md` — episode pack template
- `docs/episodes/_template_assets/gen_plots.py` — plot generator
- `docs/notion-mirror/episode_guide.md` — episode roadmap and production discipline
- `branding/brand_tokens.json` — brand colours and voice rules
- `lessons-learned/learnings_archive.md` — cite relevant learnings in "What I Learned"
- `docs/ops/PIPELINE_PHASE_SPEC.md` — canonical phase definitions referenced in template
