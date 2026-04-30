---
name: Self-author wake filter patch - r-and-d
status: proposed
date: 2026-04-29
owner: CTO
scope: paperclip-prompts/r-and-d.md
propagation_path: hot_reload
---

# Self-author wake filter patch - r-and-d

## Change
Inserted the binding wake filter block into paperclip-prompts/r-and-d.md:

WAKE FILTER (binding):
When woken via comment_added event, check the source comment's author.
If author == self, exit immediately without posting any new comment.
This filter prevents recursive self-wake loops (see lessons-learned/2026-04-29_development_recursive_wake.md).

## Reason
Prevent recursive self-wake loops from self-authored comment events and codify consistent anti-loop behavior across BASIS prompts.

## Evidence
- File patched: paperclip-prompts/r-and-d.md
- Lesson reference: lessons-learned/2026-04-29_development_recursive_wake.md