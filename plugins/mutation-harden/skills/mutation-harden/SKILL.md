---
name: mutation-harden
description: Use when the user asks to run mutation testing (PIT / pitest) on a Gradle Kotlin project with JUnit 5 tests, or to find and close test gaps that survived mutants show — phrases like "mutation test", "뮤테이션 테스트", "PIT 돌려", "pitest", "survived mutant", "살아남은 뮤턴트", "테스트 헛점 보강", "테스트 강도 검사".
---

# mutation-harden

## Overview
Trigger class: (c) repeat-task-automation. PIT changes the main code in small ways (mutants) and runs the
existing tests. A mutant that no test catches marks a behavior that no test checks. Scripts run PIT, list
those gaps, and verify each new test. You only decide what each gap means and write the tests.

The verify gate accepts a test only when a PIT run that executes that one test method reports the target
mutant as `KILLED` by it. A test that always passes cannot get through.

Spike evidence (req-shield `core` module): a full module run took 6 min 11 s, a
one-method verify run took 76 s. Timing-dependent tests killed a mutant in one run and missed it in another,
so whole-report counts are never compared.

## When to Use
- The user asks for mutation testing, PIT, or survived mutants in a Gradle project with Kotlin main code
  under `src/main/kotlin` and JUnit 5 tests.
- The user asks to find or close test gaps in changed Kotlin code, and coverage alone does not answer it.

## When NOT to Use
- Maven builds, or main code outside `src/main/kotlin` (Java-only modules). The scripts do not support them.
- Kotest specs. v1 runs JUnit 5 only.
- A Gradle wrapper older than 7.6. `verify` uses `--rerun`, which older Gradle rejects.
- Parameterized or `@TestTemplate` tests as the new test. `verify` matches the killer by the plain method
  name `[method:NAME()]` and does not see their invocations.
- Gaps from deletion-only changes. `scope` keeps added and changed lines only.
- The user asks only what mutation testing is. Answer directly.
- The user wants production code fixed. This skill never changes main code.

## Mandatory Procedure
Set `mh="${CLAUDE_SKILL_DIR}/scripts/mh.py"` and `work=$(mktemp -d)`. `R` is the repo root.
Keep every working file in `$work`, never in the repo.

1. DETERMINISTIC — record the main-code baseline:
   `$mh fingerprint --repo "$R" > "$work/fp.json"`.
2. DETERMINISTIC — find the scope. Use the base the user names; otherwise use
   `git -C "$R" merge-base HEAD origin/<default-branch>`.
   `$mh scope --repo "$R" --base <base> > "$work/scope.json"`.
   Exit 3 means no main Kotlin file changed: tell the user and stop, or run step 3 on the whole module only
   when the user asked for it (`--classes '<package>.*'`, no `--scope` in step 4).
3. DETERMINISTIC — for each module in `scope.json`, run PIT:
   `$mh run --repo "$R" --module <dir> --classes <target_classes joined by ,>`.
   Tell the user that a module run takes minutes. A non-zero exit means the build or the green-suite run
   failed: report the Gradle error and stop. When tests need a service that is not running (Docker,
   Redis), ask the user before you exclude them with `--exclude-tests`.
4. DETERMINISTIC — list the gaps:
   `$mh gaps --repo "$R" --module <dir> --scope "$work/scope.json" > "$work/gaps.json"`.
   The script drops two kinds of compiler-generated code and counts them in `filtered`: removed
   `Intrinsics.checkNotNull*` calls (`kotlin-intrinsics`) and default property getters (`kotlin-accessor`).
   Exit 0 means no gaps: report that and stop. Run `gaps` once per module. `verify` overwrites the
   module's PIT report with a one-method run, so after step 8 starts, `$work/gaps.json` is the only gap list.
5. LATENT — for each gap, in the listed order, read the source at `path:line` and the tests in
   `covering_tests`. Give it exactly one verdict:
   - `write-test`: the mutant changes behavior that a caller can observe.
   - `skipped-equivalent`: the mutant cannot change observable behavior. Write the reason. Hints set the
     default verdict:
     - `log-guard`: the line only feeds a log statement.
     - `once-per-jvm`: the code is a `by lazy` initializer or `<clinit>`. It runs once per JVM, and its
       effects (pool size, daemon flag, thread priority) are not observable through the API.
     Apply the `once-per-jvm` reason also to code without the hint when it runs only from a one-time
     initializer, for example a scheduler that a companion creates on first use. Code that the
     initializer schedules to run later (a periodic task body) is not one-time code: judge it on its own.
   - `suspected-bug`: the mutated behavior looks like what the requirement wants. Stop work on this gap
     and report it. Do not write a test that locks in the current behavior.
   - `excluded-tests`: `excluded_tests` is not empty and the gap is in code that those tests exercise.
6. LATENT — stop and ask the user before you write any test. Show a table with one row per gap: id,
   `path:line`, mutator, your verdict, and a one-line reason or test idea. Then ask with AskUserQuestion:
   write tests for every `write-test` gap, write tests only for ids the user names, or stop here.
   Ask about each `suspected-bug` gap separately: which behavior does the requirement want?
   The user can change any verdict. Continue only with the gaps the user approved. When the user stops,
   report the table and leave the repo unchanged.
7. LATENT — write one focused test per approved gap, or one test for several gaps on the same behavior:
   - Put it in the existing test class for that main class. Follow that file's style and helpers.
     When no test class exists (a `NO_COVERAGE` gap), create `<Class>Test` in the same package under
     `src/test/kotlin` and copy the style of a neighboring test class.
   - Assert the behavior the requirement needs, not the mutated expression.
   - Reuse a reflection helper that the test file already has. Do not add new reflection code.
   - Never edit files under `src/main/`.
8. DETERMINISTIC — verify each new test:
   `$mh verify --repo "$R" --module <dir> --gaps "$work/gaps.json" --fingerprint <value from fp.json>
   --test-class <FQCN> --test-method '<method name>' --mutant <id> [--mutant <id> ...]`.
   Exit 0 accepts the test. Exit 1: read `gates` in the output, fix the test, and verify again. After two
   failed attempts for a mutant, mark it `unresolved`. When `main-code-unchanged` is false, stop and report.
9. DETERMINISTIC — when the build applies ktlint, run the test source set check of the module
   (for example `./gradlew :<module>:ktlintTestSourceSetCheck`) and fix the reported style errors.
10. LATENT — report a table with one row per gap: id, `path:line`, mutator, verdict, test name or reason.
   List every `skipped-equivalent` with its reason so the user can review it. Leave the changes
   uncommitted; the user reviews and commits them.

## Relationship to other skills
- Before you change this skill, run every `tests/*/*_test.sh` script. Each must exit 0, also with
  `HOME` set to an empty temp directory. The e2e test runs real Gradle and PIT, takes minutes, and
  needs network access when `$HOME/.gradle` is empty.
- The duplicate audit flagged ouroboros skills (`evolve`, `auto`, `interview`, `run`) for the word
  "mutation". They use it for evolving a project spec, not for mutation testing, so the triggers do not
  overlap.
- `code-review` and `pr-review-toolkit:pr-test-analyzer` judge test quality by reading code. This skill
  measures it by running PIT. Use this skill when the user wants measured gaps and new tests.
