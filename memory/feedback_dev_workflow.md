---
name: feedback-dev-workflow
description: Always push changes to dev branch first, then merge to main when ready
metadata:
  type: feedback
---

Always push to dev first. Only merge to main (and tag releases) when the user explicitly approves.

**Why:** User's preferred branching workflow — dev is for work-in-progress, main is for releases.

**How to apply:** Commit and push to dev after every change. Never push directly to main or create release tags without the user saying so.
