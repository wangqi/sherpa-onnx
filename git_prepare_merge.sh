#!/usr/bin/env bash
# Prepares a conflict-friendly merge workflow:
#  - Makes a safe backup branch (no release branch auto-created)
#  - (Optionally) tags the pre-sync snapshot
#  - Hard-syncs local & origin <master> to upstream/<master>
#  - Starts a merge on 'integrate/local-changes' with --no-ff --no-commit (NO auto-commit)
#  - Exports logs for AI/manual analysis (including conflict files)
#
# After the script finishes, YOU will:
#  1) Resolve merge conflicts
#  2) `git add` resolved files
#  3) `git commit` the merge
#  4) Fast-forward merge to master + push
#  5) Create a release branch (release/<VERSION>) from master + push
#
# Usage:
#   ./git_prepare_merge.sh -v 1.0.0 [-C /path/to/sherpa-onnx] [-b master] [--stash]
#                          [--upstream https://github.com/k2-fsa/sherpa-onnx.git]
#                          [--origin-remote origin] [--upstream-remote upstream]
#                          [--tag-pre-sync] [--skip-push]
#
# Flags:
#   -C DIR                Repo directory (default: current)
#   -b, --branch NAME     Default branch to sync (default: master)
#   -v, --version VER     Version label used in outputs (e.g., 1.0.0)
#   --upstream URL        Upstream repo URL (default: k2-fsa/sherpa-onnx)
#   --origin-remote NAME  Your fork remote name (default: origin)
#   --upstream-remote NAME Upstream remote name (default: upstream)
#   --stash               Stash dirty worktree automatically
#   --tag-pre-sync        Create an annotated tag 'pre-sync-<VER>' on your current HEAD
#   --skip-push           Do NOT push backup branch / force-push master (dry-run friendly)
#
# Exit codes:
#   0  success
#   1  fatal error
#   2  merge prepared (with or without conflicts) — manual steps required

set -euo pipefail

# ---------- defaults ----------
REPO_DIR=""
BRANCH="master"
VERSION="${VERSION:-}"               # can be empty
UPSTREAM_URL="https://github.com/k2-fsa/sherpa-onnx.git"
ORIGIN_REMOTE="origin"
UPSTREAM_REMOTE="upstream"
DO_STASH=0
TAG_PRE_SYNC=0
SKIP_PUSH=0

die(){ echo "ERROR: $*" >&2; exit 1; }
log(){ echo "[git-prepare-merge] $*"; }

# ---------- args ----------
while [[ $# -gt 0 ]]; do
  case "$1" in
    -C) REPO_DIR="${2:-}"; shift 2 ;;
    -b|--branch) BRANCH="${2:-}"; shift 2 ;;
    -v|--version) VERSION="${2:-}"; shift 2 ;;
    --upstream) UPSTREAM_URL="${2:-}"; shift 2 ;;
    --origin-remote) ORIGIN_REMOTE="${2:-}"; shift 2 ;;
    --upstream-remote) UPSTREAM_REMOTE="${2:-}"; shift 2 ;;
    --stash) DO_STASH=1; shift ;;
    --tag-pre-sync) TAG_PRE_SYNC=1; shift ;;
    --skip-push) SKIP_PUSH=1; shift ;;
    -h|--help)
      sed -n '1,120p' "$0"; exit 0 ;;
    *) die "Unknown arg: $1" ;;
  esac
done

[[ -n "$REPO_DIR" ]] && cd "$REPO_DIR"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "Not a git repo."

if [[ -n "$(git status --porcelain)" ]]; then
  if (( DO_STASH )); then
    log "Dirty worktree → stashing"
    git stash push -u -m "pre-prepare-merge $(date +%FT%T)"
  else
    die "Worktree is dirty. Commit/stash or use --stash."
  fi
fi

# Ensure remotes
if ! git remote get-url "$UPSTREAM_REMOTE" >/dev/null 2>&1; then
  log "Adding upstream remote '$UPSTREAM_REMOTE' → $UPSTREAM_URL"
  git remote add "$UPSTREAM_REMOTE" "$UPSTREAM_URL"
fi

log "Fetching all"
git fetch --all --tags

# Snapshot current head before any sync
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
PRE_SYNC_COMMIT="$(git rev-parse HEAD)"
TS="$(date +%Y%m%d-%H%M%S)"
BACKUP_BRANCH="backup/pre-sync-${VERSION:-manual}-$TS"

log "Creating backup branch '$BACKUP_BRANCH' at $PRE_SYNC_COMMIT"
git branch "$BACKUP_BRANCH" "$PRE_SYNC_COMMIT"

if (( TAG_PRE_SYNC )); then
  [[ -n "$VERSION" ]] || die "--tag-pre-sync requires --version"
  TAG="pre-sync-$VERSION"
  if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null 2>&1; then
    die "Tag '$TAG' already exists. Delete it or bump version."
  fi
  log "Tagging current commit as '$TAG'"
  git tag -a "$TAG" -m "Pre-sync snapshot for $VERSION"
fi

if (( ! SKIP_PUSH )); then
  log "Pushing backup branch to $ORIGIN_REMOTE"
  git push "$ORIGIN_REMOTE" "$BACKUP_BRANCH"
  if (( TAG_PRE_SYNC )); then
    git push "$ORIGIN_REMOTE" "$TAG"
  fi
fi

# Sync local master to upstream/master and force-push fork
log "Checking out '$BRANCH'"
git checkout "$BRANCH"

log "Resetting '$BRANCH' to '$UPSTREAM_REMOTE/$BRANCH'"
git fetch "$UPSTREAM_REMOTE"
git reset --hard "$UPSTREAM_REMOTE/$BRANCH"

if (( ! SKIP_PUSH )); then
  log "Force-pushing '$BRANCH' to '$ORIGIN_REMOTE' (discarding fork-only commits)"
  git push --force "$ORIGIN_REMOTE" "$BRANCH"
else
  log "SKIP_PUSH on → not force-pushing master"
fi

# Prepare integration branch and start an uncommitted merge
INTEGRATE_BRANCH="integrate/local-changes"
log "Creating '$INTEGRATE_BRANCH' from '$BRANCH'"
git checkout -B "$INTEGRATE_BRANCH" "$BRANCH"

log "Starting NO-COMMIT merge of '$BACKUP_BRANCH' → '$INTEGRATE_BRANCH' (history preserved)"
# --no-ff to keep a merge commit, --no-commit to avoid auto-commit, let user inspect/resolve
set +e
git merge --no-ff --no-commit "$BACKUP_BRANCH"
MERGE_RC=$?
set -e

# Collect analysis artifacts
OUTDIR="out_prepare_${VERSION:-manual}_$TS"
mkdir -p "$OUTDIR"

BASE_REF="$UPSTREAM_REMOTE/$BRANCH"
HEAD_REF="HEAD"   # integrate/local-changes (with staged/unmerged state)

log "Exporting analysis files to $OUTDIR"

# Local-only commits (your work) relative to upstream
git log --pretty=format:"%h %ad %an %s" --date=short ${BASE_REF}.."$BACKUP_BRANCH" > "$OUTDIR/local_commits_vs_upstream.log" || true
git shortlog -sne ${BASE_REF}.."$BACKUP_BRANCH" > "$OUTDIR/local_authors_vs_upstream.log" || true
git diff --stat ${BASE_REF}.."$BACKUP_BRANCH" > "$OUTDIR/local_diffstat_vs_upstream.log" || true

# Tentative combined changes vs upstream from current (possibly conflicted) tree
git --no-pager diff --stat ${BASE_REF}.. > "$OUTDIR/combined_diffstat_working_vs_upstream.log" || true

# List conflicts and merge state helpers
git diff --name-only --diff-filter=U > "$OUTDIR/conflicts_files.txt" || true
git status > "$OUTDIR/git_status.txt" || true

TODAY="$(date +%Y-%m-%d)"
cat > "$OUTDIR/codex_prompt.txt" <<'PROMPT'
You are an expert Git and C++/Python project release analyst.

Context:
- repo: sherpa-onnx (fork of k2-fsa/sherpa-onnx)
- We synced to upstream and began a NO-COMMIT merge to preserve local history.
- Your task: read the logs, identify what changed locally vs upstream, and suggest a SAFE conflict-resolution plan.

Artifacts:
1) local_commits_vs_upstream.log         # commits unique to local backup branch
2) local_authors_vs_upstream.log         # authors of local-only commits
3) local_diffstat_vs_upstream.log        # diffstat of local-only changes
4) combined_diffstat_working_vs_upstream.log # what the combined tree would change vs upstream (working copy)
5) conflicts_files.txt                   # files currently conflicted
6) git_status.txt                        # working tree status

Deliverables:
- A concise summary of local-only changes that are worth keeping.
- A file-by-file conflict resolution plan (keep ours / keep theirs / manual splice), with reasoning.
- Any required follow-ups (API changes, CI files, model paths).
- A draft of "whats_new.md" (400–800 words) with sections: New, Improvements, Fixes, Breaking, Docs/CI/Build, Upgrade notes.
- Call out risky merges explicitly and how to test them.

(You will receive the contents of those files next.)
PROMPT

log "============================================================"
log "Preparation DONE. Next steps are MANUAL (see below)."
log "Artifacts: $OUTDIR/"
log "  - Conflicts list: $OUTDIR/conflicts_files.txt"
log "  - Combined diffstat: $OUTDIR/combined_diffstat_working_vs_upstream.log"
log "  - Local-only commits: $OUTDIR/local_commits_vs_upstream.log"
log "  - Codex prompt: $OUTDIR/codex_prompt.txt"
log "============================================================"

# Return code 2 indicates: merge prepared; manual action required.
exit 2
