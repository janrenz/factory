#!/usr/bin/env bash
# Factory preflight: verifies the factory's wiring in the current repo.
# Stack-agnostic, no network.  Run from anywhere inside the repo:
#   bash <factory>/scripts/check.sh
set -u
FACTORY_HOME=$(cd "$(dirname "$0")/.." && pwd)
cd "$(git rev-parse --show-toplevel)" || exit 1
fail=0
ok()   { printf '  ok    %s\n' "$1"; }
bad()  { printf '  FAIL  %s\n' "$1"; fail=1; }
warn() { printf '  warn  %s\n' "$1"; }

echo "repo files"
for f in factory/profile.md factory/backlog.md factory/jobs; do
  [ -e "$f" ] && ok "$f" || bad "$f missing (run /factory init)"
done

echo "profile"
FACTORY_HOME="$FACTORY_HOME" python3 - <<'PY' || fail=1
import json, os, sys
sys.path.insert(0, os.path.join(os.environ["FACTORY_HOME"], "scripts"))
from profile import load
errs, warns = [], []
try:
    p = load("factory/profile.md")
except Exception as e:
    print(f"  FAIL  profile unreadable: {e}"); sys.exit(1)
if p.get("flavour") not in ("local", "jira", "ticket-pr"):
    errs.append(f"flavour {p.get('flavour')!r} must be local, jira or ticket-pr")
lenses = p.get("lenses") or []
if not set(lenses) <= {"security", "ux", "ui", "code"} or "security" not in lenses or "code" not in lenses:
    errs.append("lenses must include security and code, and only security/ux/ui/code")
d = p.get("design") or {}
if d and d.get("source") not in ("figma", "figcraft", "prototype", "none"):
    errs.append(f"design.source {d.get('source')!r} must be figma, figcraft, prototype or none")
for k in ("tokens",):
    if d.get(k) and not os.path.exists(d[k]):
        errs.append(f"design.{k}: {d[k]} does not exist")
for k, path in (p.get("docs") or {}).items():
    if path and not os.path.exists(path):
        errs.append(f"docs.{k}: {path} does not exist")
if (p.get("docs") or {}).get("secure_coding") and ".." not in str(p.get("secure_coding_rules") or ""):
    errs.append("secure_coding set, but secure_coding_rules is not a range like SC-2.1..SC-12.1")
core = json.load(open(os.path.join(os.environ["FACTORY_HOME"], ".claude-plugin", "plugin.json")))["version"]
if str(p.get("factory_version")) != core:
    warns.append(f"profile factory_version {p.get('factory_version')} ≠ core {core}: read CHANGELOG.md, then bump it")
text = open("factory/profile.md", encoding="utf-8").read()
for sec in ["All agents", "spec-writer", "builder", "reviewer-security", "reviewer-code", "approver"]:
    if f"\n## {sec}" not in text:
        warns.append(f"profile has no '## {sec}' section")
for w in warns: print(f"  warn  {w}")
for e in errs: print(f"  FAIL  {e}")
if not errs: print(f"  ok    flavour {p['flavour']}, lenses {', '.join(lenses)}")
sys.exit(1 if errs else 0)
PY

echo "agents (core)"
for spec in spec-writer:opus builder:opus reviewer-security:opus reviewer-ux:sonnet \
            reviewer-ui:sonnet reviewer-code:sonnet approver:opus prototyper:sonnet; do
  name=${spec%%:*} model=${spec##*:} f="$FACTORY_HOME/agents/$name.md"
  [ -f "$f" ] || { bad "$name missing in core"; continue; }
  grep -qx "name: $name" "$f" && grep -qx "model: $model" "$f" && ok "$name ($model)" || bad "$name: frontmatter"
done
for f in .claude/agents/{spec-writer,builder,reviewer-security,reviewer-ux,reviewer-ui,reviewer-code,approver}.md; do
  [ -e "$f" ] && warn "$f exists: an old local copy; project rules belong in factory/profile.md"
done

echo "job state (factory/jobs/*/state.json)"
FACTORY_HOME="$FACTORY_HOME" python3 - <<'PY' || fail=1
import json, os, sys, glob, re
sys.path.insert(0, os.path.join(os.environ["FACTORY_HOME"], "scripts"))
from profile import load
p = load("factory/profile.md")
lenses = set(p.get("lenses") or ["security", "ux", "ui", "code"])
first_issue_id = int(p.get("issue_ids_from") or 1)
STAGES = {"spec", "build", "review", "approve", "merged", "needs-human"}
VERDICTS = {"pending", "PASS", "CHANGES"}
errs, n, numbers = [], 0, {}
for d in sorted(glob.glob("factory/jobs/*/")):
    jid = os.path.basename(d.rstrip("/"))
    f = os.path.join(d, "state.json")
    if not os.path.exists(f): errs.append(f"{jid}: state.json missing"); continue
    try: j = json.load(open(f))
    except Exception as e: errs.append(f"{jid}: state.json not valid JSON: {e}"); continue
    n += 1
    if j.get("id") != jid: errs.append(f"{jid}: id {j.get('id')!r} does not match folder")
    m = re.match(r"^(\d{3,})[a-z]?-[a-z0-9]+(-[a-z0-9]+)*$", jid)
    if not m: errs.append(f"{jid}: id must be <number>-<kebab-slug>")
    else:
        num = int(m.group(1))
        numbers.setdefault(jid[: len(m.group(1)) + (1 if jid[len(m.group(1))].isalpha() else 0)], []).append(jid)
        issue = j.get("issue")
        if issue is not None and issue != num: errs.append(f"{jid}: issue {issue} does not match id number")
        if issue is None and num >= first_issue_id: errs.append(f"{jid}: issue missing (ids come from GitHub issues)")
    if j.get("stage") not in STAGES: errs.append(f"{jid}: bad stage {j.get('stage')!r}")
    if j.get("branch") != f"factory/{jid}": errs.append(f"{jid}: branch must be factory/{jid}")
    if not set(j.get("reviews", {})) <= {"security", "ux", "ui", "code"} or not lenses <= set(j.get("reviews", {})):
        errs.append(f"{jid}: reviews must cover the profile's lenses")
    if not set(j.get("reviews", {}).values()) <= VERDICTS: errs.append(f"{jid}: bad verdict value")
for num, ids in numbers.items():
    if len(ids) > 1: errs.append(f"job number {num} used twice: {', '.join(ids)}")
for e in errs: print(f"  FAIL  {e}")
if not errs: print(f"  ok    {n} job(s), schema valid, numbers unique")
sys.exit(1 if errs else 0)
PY

echo "git"
main=$(python3 "$FACTORY_HOME/scripts/profile.py" factory/profile.md main 2>/dev/null); main=${main:-main}
git rev-parse --verify -q "$main" >/dev/null && ok "$main has commits" || bad "$main has no commits"
grep -qx '.worktrees/' .gitignore 2>/dev/null && ok ".worktrees/ ignored" || bad ".worktrees/ not in .gitignore"

[ $fail -eq 0 ] && echo "PREFLIGHT OK" || echo "PREFLIGHT FAILED"
exit $fail
