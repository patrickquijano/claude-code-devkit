# Evaluations: ccd-conflict-resolve

Re-run these after editing `SKILL.md` or any script under `scripts/`. Each names what it is testing and what a failure looks like, so a run that "seemed fine" can still be judged.

Build the fixture first. It carries four conflict kinds at once, which is what makes one merge enough to exercise most of the skill:

```sh
cd "$(mktemp -d)"
git init -q -b main scratch && cd scratch
git config user.email t@e.st && git config user.name Test

printf 'line one\nline two\nline three\n' > file.txt
printf 'keep\n' > gone.txt
git add . && git commit -qm base

git switch -qc theirs
printf 'line one\nTHEIR change\nline three\n' > file.txt
git rm -q gone.txt
printf 'their added\n' > added.txt
printf 'THEIRS\000\001\002binary\n' > new.bin
git add . && git commit -qm 'their change'

git switch -q main
printf 'line one\nOUR change\nline three\n' > file.txt
printf 'keep modified\n' > gone.txt
printf 'our added\n' > added.txt
printf 'OURS\000\001\002binary\n' > new.bin
git add . && git commit -qm 'our change'

git merge theirs # conflicts in all four paths
```

That yields `file.txt` both-modified, `added.txt` and `new.bin` both-added (the second binary), and `gone.txt` modify/delete.

## 1. The tool check comes first and stops everything

Run the skill with `git` off `PATH`.

**Pass**: it stops, says git is missing, and has changed nothing. `conflict-preflight.sh` exits 2 having printed no key lines at all.

**Fail**: any repository state is reported, any file is touched, or the run proceeds to identification. The point of this check is that it happens before anything else is even read.

## 2. Identification is complete and classified

**Pass**: all four paths reported with kinds `both-modified`, `both-added`, `both-added`+binary, `deleted-by-them` — before any resolution is proposed. `new.bin` is reported as `binary`, not as `both-added`.

**Fail**: any path omitted; `new.bin` classified by its `AA` code rather than by its content; a resolution proposed before the full list was shown.

## 3. Identification is stable

Run `conflict-list.sh` twice and compare.

**Pass**: byte-identical output both times, sorted by path.

**Fail**: any reordering. Git documents porcelain v2's order as undefined, so this property is the script's to provide and it is the first thing a rewrite tends to lose.

## 4. Nothing is modified before approval

Invoke the skill and stop at the proposal.

**Pass**: `git status --porcelain` and `git diff` are exactly as the conflicted merge left them. Nothing rewritten, nothing staged.

**Fail**: any file changed, anything staged, or a resolution applied because it looked obvious.

Then **decline every option**.

**Pass**: the tree is still unchanged and the merge is still in progress.

**Fail**: any fallback resolution applied. There is no default.

## 5. Options are explained, and one is recommended with a reason

**Pass**: every option carries an explanation; exactly one is recommended; the recommendation carries a justification.

**Fail**: an unexplained option, no recommendation, or a recommendation with no reason. All three break the property the skill exists for.

## 6. Ours and theirs are described, never labelled — the rebase case

Set up a rebase conflict instead:

```sh
git merge --abort
git switch theirs && git rebase main
```

**Pass**: options name the branch and whose change is discarded. Under this rebase, keeping "ours" keeps `main`'s content and discards the commit being replayed — and the option says so in those terms.

**Fail**: the options read "take ours" / "take theirs" with no further explanation. Git swaps the sides under a rebase, so the bare label tells the user the opposite of the truth. This is the highest-consequence failure in the list.

## 7. Every kind has a resolution — including both-deleted

**Pass**: `conflict-apply.sh remove gone.txt` exits 0 and resolves the modify/delete. A `DD` path likewise resolves through `remove`.

**Fail**: `ours` or `theirs` offered for a path that has no such stage, or exit 3 on every mechanism for a kind — that means the kind is reportable and unresolvable, which is the specific bug `remove` was added to fix.

## 8. A hand resolution with markers left in is refused

Edit a conflicted file, leave a `<<<<<<<` marker in, and apply with `staged`.

**Pass**: exit 4, nothing staged, and the skill reports the file still needs editing.

**Fail**: the file is staged. Concluding would then commit the markers.

## 9. Unrelated staged work blocks concluding

Resolve everything, then:

```sh
printf 'unrelated\n' > other.txt
git add other.txt
```

**Pass**: `conflict-conclude.sh` exits 4, prints `other.txt`, and concludes nothing. The skill reports it and asks — it does **not** unstage on the user's behalf.

**Fail**: the merge commit contains `other.txt`. Git commits the whole index and refuses a pathname-limited commit during a merge, so nothing downstream can undo this.

Then unstage it, leave it dirty, and conclude.

**Pass**: concluding succeeds, and `other.txt` is still present and uncommitted afterwards.

## 10. Iteration reports lack of progress

With two conflicts, resolve one.

**Pass**: the skill re-identifies and proposes for what remains rather than reporting completion.

**Fail**: it reports success with a conflict outstanding, or loops silently when a resolution changed nothing.

## 11. The skill is reachable both ways

**Pass**: `/claude-code-devkit:ccd-conflict-resolve` invokes it; and describing a conflicted tree in a fresh session, without naming it, is enough for Claude to reach for it.

**Fail on the first**: a loading problem. **Consistent failure on the second**: the description needs work — it is what triggering is judged on, and it is truncated at 1,536 characters combined with `when_to_use`.

## 12. The invariants hold

```sh
ls -d skills/*/ | wc -l                                                         # expect 6
grep -c 'disable-model-invocation' skills/ccd-conflict-resolve/SKILL.md         # expect 0 in frontmatter
grep -c 'CLAUDE_PLUGIN_ROOT' skills/ccd-conflict-resolve/SKILL.md               # expect 0
shellcheck --shell=sh --severity=style skills/ccd-conflict-resolve/scripts/*.sh # expect exit 0
sh scripts/lint.sh                                                              # expect exit 0
```

**Fail**: any non-zero. The `CLAUDE_PLUGIN_ROOT` count matters because this skill reaches its own scripts through `${CLAUDE_SKILL_DIR}`; a `PLUGIN_ROOT` path here would hard-code the skill's own directory name and break on rename.

## The question standard

Every ask in this skill goes through `AskUserQuestion` with options, per-option effect and cost, exactly one `(Recommended)` and the reason for it — or an explicit statement that no recommendation is defensible. The rule lives once, in `.claude/rules/skill-authoring.md`; this skill restates none of it.

**Regression to re-check after any edit that touches a question**: no ask site instructs asking without naming the tool, no question offers options with no recommendation and no explanation of why none is given, and no local copy of the rule has crept back in. Run:

```sh
grep -n "Every question in this skill goes through" SKILL.md
```

Zero hits is correct. A hit means the repository-wide rule now has a second copy, which is the drift `.claude/rules/repository-docs.md` calls worse than having no rule at all.
