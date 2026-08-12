---
name: fog-gitops
description: |
  GitOps workflow and inspection gate protocol for Polecat worker agents operating in the fog homelab rig.
  Defines feature-branch isolation, local verification, handoff to Kaylee, and FluxCD release criteria.
---

# Fog GitOps Workflow & Inspection Gate

This skill governs how **Polecat worker agents** and **Kaylee (Chief Engineer)** collaborate on the `fog` homelab repository.

---

## 1. Core Rule: Branch Protection & Inspection Gate

* **FluxCD Protection**: `main` on `gitea.fog.chalko.com` automatically reconciles live infrastructure. **Polecats must never push directly to `main`**.
* **Feature Branches**: All work is performed on isolated feature branches (`feature/<bead-id>`).
* **Kaylee Gate**: Every change must be inspected, validated, and approved by Kaylee (`fog/kaylee`) before being merged into `main`.

---

## 2. Polecat Worker Lifecycle

When assigned a work bead in `fog`:

1. **Setup Worktree**:
   ```bash
   git fetch origin main
   git worktree add worktrees/$BEAD_ID -b feature/$BEAD_ID origin/main
   cd worktrees/$BEAD_ID
   ```
2. **Implement & Validate**:
   * For K8s: `kustomize build apps/...` or `kustomize build infrastructure/...`
   * For Terraform: `terraform validate`
   * For Docker: Verify Dockerfile syntax & multi-stage build structure.
3. **Commit & Push**:
   ```bash
   git add -A
   git commit -m "feat(scope): imperative summary ($BEAD_ID)"
   git push origin feature/$BEAD_ID
   ```
4. **Handoff to Kaylee**:
   ```bash
   gc bd update $BEAD_ID --assignee=fog/kaylee --notes "Pushed feature/$BEAD_ID for inspection"
   gc session nudge fog/kaylee "MERGE_READY: $BEAD_ID branch feature/$BEAD_ID"
   ```

---

## 3. Kaylee Inspection Protocol

When Kaylee receives a `MERGE_READY` handoff:

1. **Diff Audit**: `git diff main..feature/$BEAD_ID`
   * Verify no plaintext secrets or credentials.
   * Verify scope boundaries (no host/system changes outside `fog`).
2. **Static & Schema Validation**:
   * Run `kustomize build` or `terraform validate`.
   * Check container tags and ExternalSecret / Vault mappings.
3. **Merge & Release**:
   * Merge `feature/$BEAD_ID` into `main`.
   * Push `main` to `gitea.fog.chalko.com` (triggering FluxCD).
   * Close the bead: `gc bd close $BEAD_ID`.
