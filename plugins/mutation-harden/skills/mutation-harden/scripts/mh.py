#!/usr/bin/env python3
"""Deterministic steps of the mutation-harden skill (PIT on Gradle + Kotlin + JUnit 5).

Subcommands (all print JSON to stdout; Gradle output goes to stderr):

  fingerprint --repo DIR
      Hash of every tracked or untracked file under a src/main/ directory.
      exit 0.

  scope --repo DIR --base REF
      Main Kotlin files changed between REF and the working tree, grouped by module.
      exit 0 = changes found, 3 = no main Kotlin change, 2 = bad input.

  run --repo DIR --module DIR --classes GLOB[,GLOB] [--tests GLOB[,GLOB]]
      [--exclude-tests GLOB[,GLOB]] [--methods NAME[,NAME]]
      Runs PIT through assets/pitest.init.gradle.kts and writes mh-run.json next to the report.
      --tests defaults to "*" (every test class of the module).
      exit = Gradle exit code, 2 = bad input.

  gaps --repo DIR --module DIR [--report FILE] [--scope FILE] [--limit N]
      Survived and no-coverage mutants, Kotlin noise removed, ranked.
      exit 0 = no gaps, 1 = gaps found, 2 = bad input.

  verify --repo DIR --module DIR --gaps FILE --fingerprint HASH
      --test-class FQCN --test-method NAME --mutant ID [--mutant ID ...]
      Gates: main code unchanged, new test passes twice, new test kills each mutant.
      exit 0 = every gate passes, 1 = a gate failed, 2 = bad input.
"""

import argparse
import functools
import hashlib
import json
import os
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

SKILL_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INIT_SCRIPT = os.path.join(SKILL_DIR, "assets", "pitest.init.gradle.kts")
REPORT_REL = os.path.join("build", "reports", "pitest")
MAIN_KOTLIN = "src/main/kotlin/"
GAP_STATUSES = ("SURVIVED", "NO_COVERAGE")
INTRINSICS = "kotlin/jvm/internal/Intrinsics::checkNotNull"
# Lower rank = more likely to be a real behavior gap.
MUTATOR_RANK = {
    "ConditionalsBoundaryMutator": 0,
    "NegateConditionalsMutator": 1,
    "RemoveConditionalMutator": 1,
    "BooleanTrueReturnValsMutator": 2,
    "BooleanFalseReturnValsMutator": 2,
    "PrimitiveReturnsMutator": 2,
    "EmptyObjectReturnValsMutator": 2,
    "NullReturnValsMutator": 2,
    "VoidMethodCallMutator": 3,
    "MathMutator": 4,
    "IncrementsMutator": 4,
    "InvertNegsMutator": 4,
}
LOG_CALL = re.compile(r"\b(log|logger|LOG|LOGGER)\.(trace|debug|info|warn|error)\(|\blog[A-Z]\w*\(")
PACKAGE = re.compile(r"^\s*package\s+([\w.]+)", re.M)
TOP_LEVEL_TYPE = re.compile(
    r"^(?:(?:public|internal|private|data|sealed|abstract|open|enum|annotation|value|inline|fun)\s+)*"
    r"(?:class|object|interface)\s+(\w+)",
    re.M,
)
HUNK = re.compile(r"^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@")
PROPERTY_DECL = re.compile(r"\b(?:val|var)\s+`?(\w+)`?\s*[:=]")
# A `by lazy` initializer compiles to a class <Outer>$<property>$<n> (Kotlin 1.x)
# or to a method <property>_delegate$lambda$<n> (Kotlin 2.x, invokedynamic lambdas).
LAZY_CLASS = re.compile(r"\$(\w+)\$\d+(?:\$|$)")
LAZY_METHOD = re.compile(r"^(\w+?)_delegate\$lambda")
TEST_METHOD = re.compile(r"\[class:([^\]]+)\]/\[method:([^\]]*?)\(\)\]")


class BadInput(Exception):
    pass


def emit(obj):
    json.dump(obj, sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")


def git(repo, *args):
    res = subprocess.run(["git", "-C", repo, *args], capture_output=True, text=True)
    if res.returncode != 0:
        raise BadInput(f"git {' '.join(args)} failed: {res.stderr.strip()}")
    return res.stdout


def csv(value):
    return [v.strip() for v in value.split(",") if v.strip()] if value else []


def module_of(path):
    """Return the module directory of a main Kotlin source path, or None."""
    if path.startswith(MAIN_KOTLIN):
        return "."
    idx = path.find("/" + MAIN_KOTLIN)
    return path[:idx] if idx >= 0 else None


def gradle_task(module, task):
    return f":{task}" if module == "." else ":" + module.replace("/", ":") + f":{task}"


def require_repo(repo, module=None):
    if not os.path.isfile(os.path.join(repo, "gradlew")):
        raise BadInput(f"no gradlew in {repo}")
    if module is not None and not os.path.isdir(os.path.join(repo, module)):
        raise BadInput(f"module directory not found: {module}")


# ---------- fingerprint ----------

def fingerprint(repo):
    files = git(repo, "ls-files", "-co", "--exclude-standard").splitlines()
    digest = hashlib.sha256()
    for path in sorted(f for f in files if f.startswith("src/main/") or "/src/main/" in f):
        digest.update(path.encode() + b"\0")
        full = os.path.join(repo, path)
        if os.path.isfile(full):
            with open(full, "rb") as fh:
                digest.update(fh.read())
        digest.update(b"\0")
    return digest.hexdigest()


def cmd_fingerprint(a):
    emit({"fingerprint": fingerprint(a.repo)})
    return 0


# ---------- scope ----------

def changed_ranges(repo, base):
    git(repo, "rev-parse", "--verify", "--quiet", base + "^{commit}")
    ranges, current = {}, None
    for line in git(repo, "diff", "-U0", "--no-color", base, "--", "*.kt").splitlines():
        if line.startswith("+++ "):
            current = line[6:] if line.startswith("+++ b/") else None
        elif current and (m := HUNK.match(line)):
            start, count = int(m.group(1)), int(m.group(2) or "1")
            if count > 0:
                ranges.setdefault(current, []).append([start, start + count - 1])
    for path in git(repo, "ls-files", "--others", "--exclude-standard", "--", "*.kt").splitlines():
        with open(os.path.join(repo, path), encoding="utf-8") as fh:
            ranges[path] = [[1, max(1, len(fh.read().splitlines()))]]
    return {p: r for p, r in ranges.items() if module_of(p)}


def target_classes(source):
    match = PACKAGE.search(source)
    prefix = match.group(1) + "." if match else ""
    return [prefix + name + "*" for name in TOP_LEVEL_TYPE.findall(source)]


def cmd_scope(a):
    ranges = changed_ranges(a.repo, a.base)
    modules = {}
    for path, rng in sorted(ranges.items()):
        mod = modules.setdefault(module_of(path), {"changed": {}, "target_classes": set()})
        mod["changed"][path] = rng
        full = os.path.join(a.repo, path)
        if os.path.isfile(full):
            with open(full, encoding="utf-8") as fh:
                source = fh.read()
            stem = os.path.splitext(os.path.basename(path))[0]
            match = PACKAGE.search(source)
            mod["target_classes"].update(target_classes(source))
            mod["target_classes"].add((match.group(1) + "." if match else "") + stem + "Kt*")
    out = [{"dir": d, "changed": m["changed"], "target_classes": sorted(m["target_classes"])}
           for d, m in sorted(modules.items())]
    emit({"base": a.base, "modules": out})
    return 0 if out else 3


# ---------- run ----------

def run_pit(repo, module, classes, tests, excluded, methods):
    report_dir = os.path.join(repo, module, REPORT_REL)
    for name in ("mutations.xml", "mh-run.json"):
        if os.path.exists(os.path.join(report_dir, name)):
            os.remove(os.path.join(report_dir, name))
    cmd = [os.path.join(repo, "gradlew"), "--init-script", INIT_SCRIPT, gradle_task(module, "pitest"),
           "-PpitTargetClasses=" + ",".join(classes), "-PpitTargetTests=" + ",".join(tests)]
    if excluded:
        cmd.append("-PpitExcludedTests=" + ",".join(excluded))
    if methods:
        cmd.append("-PpitTestMethods=" + ",".join(methods))
    code = subprocess.run(cmd, cwd=repo, stdout=sys.stderr, stderr=sys.stderr).returncode
    run_info = {"classes": classes, "tests": tests, "excluded_tests": excluded, "methods": methods}
    if code == 0:
        with open(os.path.join(report_dir, "mh-run.json"), "w") as fh:
            json.dump(run_info, fh, indent=2)
    return code, os.path.join(report_dir, "mutations.xml")


def cmd_run(a):
    require_repo(a.repo, a.module)
    classes = csv(a.classes)
    if not classes:
        raise BadInput("--classes is empty")
    code, report = run_pit(a.repo, a.module, classes, csv(a.tests) or ["*"],
                           csv(a.exclude_tests), csv(a.methods))
    emit({"gradle_exit": code, "report": report if code == 0 else None})
    return code


# ---------- gaps ----------

def load_mutations(path):
    if not os.path.isfile(path):
        raise BadInput(f"PIT report not found: {path}")
    with open(path, "rb") as fh:
        root = ET.parse(fh).getroot()
    result = []
    for m in root.iter("mutation"):
        rec = {t: (m.findtext(t) or "") for t in (
            "sourceFile", "mutatedClass", "mutatedMethod", "methodDescription", "lineNumber",
            "mutator", "description", "killingTests", "coveringTests")}
        rec["status"] = m.get("status", "")
        rec["indexes"] = ",".join(i.text or "" for i in m.iter("index"))
        rec["id"] = "m-" + hashlib.sha1("|".join(rec[k] for k in (
            "mutatedClass", "mutatedMethod", "methodDescription", "lineNumber", "mutator", "indexes",
            "description")).encode()).hexdigest()[:10]
        result.append(rec)
    return result


def source_index(repo, module):
    """Map (package, file name) to the repo-relative path of each main Kotlin file."""
    index = {}
    root = os.path.join(repo, module, MAIN_KOTLIN)
    for dirpath, _, files in os.walk(root):
        for name in files:
            if name.endswith(".kt"):
                full = os.path.join(dirpath, name)
                with open(full, encoding="utf-8") as fh:
                    match = PACKAGE.search(fh.read())
                index[(match.group(1) if match else "", name)] = os.path.relpath(full, repo)
    return index


@functools.lru_cache(maxsize=None)
def source_lines(repo, path):
    if not path:
        return ()
    with open(os.path.join(repo, path), encoding="utf-8") as fh:
        return tuple(fh.read().splitlines())


def is_default_accessor(lines, line, method):
    """True when method is the getter the compiler generates for a property declared on this line."""
    text = lines[line - 1] if 0 < line <= len(lines) else ""
    if "get()" in text:
        return False
    for prop in PROPERTY_DECL.findall(text):
        getter = prop if re.match(r"is[A-Z]", prop) else "get" + prop[0].upper() + prop[1:]
        if method == getter:
            return True
    return False


def hints(lines, line, mutated_class, method):
    found = []
    nearby = [t for t in lines[max(0, line - 1):line + 2] if t.strip()][:2] if line > 0 else []
    if any(LOG_CALL.search(t) for t in nearby):
        found.append("log-guard")
    props = [m.group(1) for m in (LAZY_CLASS.search(mutated_class), LAZY_METHOD.match(method)) if m]
    source = "\n".join(lines)
    lazy_decl = any(re.search(rf"\b(?:val|var)\s+{p}\b.*\bby\s+lazy\b", source) for p in props)
    if method == "<clinit>" or lazy_decl:
        found.append("once-per-jvm")
    return found


def test_names(field):
    names = []
    for cls, method in TEST_METHOD.findall(field):
        name = f"{cls}#{method}"
        if name not in names:
            names.append(name)
    return names


def cmd_gaps(a):
    report = a.report or os.path.join(a.repo, a.module, REPORT_REL, "mutations.xml")
    mutations = load_mutations(report)
    scope = None
    if a.scope:
        with open(a.scope) as fh:
            scope = {p: r for m in json.load(fh)["modules"] for p, r in m["changed"].items()}
    run_info_path = os.path.join(os.path.dirname(report), "mh-run.json")
    excluded = []
    if os.path.isfile(run_info_path):
        with open(run_info_path) as fh:
            excluded = json.load(fh).get("excluded_tests", [])
    index = source_index(a.repo, a.module)
    filtered = {"kotlin-intrinsics": 0, "kotlin-accessor": 0, "outside-scope": 0}
    gaps = []
    for m in mutations:
        if m["status"] not in GAP_STATUSES:
            continue
        mutator = m["mutator"].rsplit(".", 1)[-1]
        if mutator == "VoidMethodCallMutator" and INTRINSICS in m["description"]:
            filtered["kotlin-intrinsics"] += 1
            continue
        package = m["mutatedClass"].rsplit(".", 1)[0] if "." in m["mutatedClass"] else ""
        path = index.get((package, m["sourceFile"]))
        line = int(m["lineNumber"] or 0)
        lines = source_lines(a.repo, path)
        if is_default_accessor(lines, line, m["mutatedMethod"]):
            filtered["kotlin-accessor"] += 1
            continue
        if scope is not None and not any(s <= line <= e for s, e in scope.get(path, [])):
            filtered["outside-scope"] += 1
            continue
        covering = test_names(m["coveringTests"])
        gaps.append({
            "id": m["id"], "status": m["status"], "path": path, "source_file": m["sourceFile"],
            "line": line, "class": m["mutatedClass"], "method": m["mutatedMethod"],
            "mutator": mutator, "description": m["description"],
            "hints": hints(lines, line, m["mutatedClass"], m["mutatedMethod"]),
            "covering_tests": covering[:10], "covering_test_count": len(covering),
        })
    gaps.sort(key=lambda g: (bool(g["hints"]), MUTATOR_RANK.get(g["mutator"], 5),
                             g["path"] or g["source_file"], g["line"]))
    emit({"report": report, "excluded_tests": excluded, "filtered": filtered,
          "gaps": gaps[:a.limit], "dropped_by_limit": max(0, len(gaps) - a.limit)})
    return 1 if gaps else 0


# ---------- verify ----------

def cmd_verify(a):
    require_repo(a.repo, a.module)
    with open(a.gaps) as fh:
        known = {g["id"]: g for g in json.load(fh)["gaps"]}
    missing = [i for i in a.mutant if i not in known]
    if missing:
        raise BadInput(f"mutant ids not in {a.gaps}: {missing}")
    result = {"gates": {}, "mutants": {}}

    def finish(ok):
        emit(result)
        return 0 if ok else 1

    unchanged = fingerprint(a.repo) == a.fingerprint
    result["gates"]["main-code-unchanged"] = unchanged
    if not unchanged:
        return finish(False)

    test_filter = f"{a.test_class}.{a.test_method}"
    for run in (1, 2):
        cmd = [os.path.join(a.repo, "gradlew"), gradle_task(a.module, "test"),
               "--tests", test_filter, "--rerun"]
        passed = subprocess.run(cmd, cwd=a.repo, stdout=sys.stderr, stderr=sys.stderr).returncode == 0
        result["gates"][f"test-passes-run-{run}"] = passed
        if not passed:
            return finish(False)

    classes = sorted({known[i]["class"].split("$", 1)[0] + "*" for i in a.mutant})
    code, report = run_pit(a.repo, a.module, classes, [a.test_class], [], [a.test_method])
    result["gates"]["pit-run"] = code == 0
    if code != 0:
        return finish(False)
    after = {m["id"]: m for m in load_mutations(report)}
    for i in a.mutant:
        m = after.get(i)
        killed = bool(m) and m["status"] == "KILLED" and \
            f"[method:{a.test_method}()]" in m["killingTests"]
        result["mutants"][i] = {"status": m["status"] if m else "NOT_FOUND", "killed_by_new_test": killed}
    ok = all(r["killed_by_new_test"] for r in result["mutants"].values())
    result["gates"]["new-test-kills-every-mutant"] = ok
    return finish(ok)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("fingerprint")
    s.add_argument("--repo", required=True)
    s.set_defaults(fn=cmd_fingerprint)

    s = sub.add_parser("scope")
    s.add_argument("--repo", required=True)
    s.add_argument("--base", required=True)
    s.set_defaults(fn=cmd_scope)

    s = sub.add_parser("run")
    for flag in ("--repo", "--module", "--classes"):
        s.add_argument(flag, required=True)
    for flag in ("--tests", "--exclude-tests", "--methods"):
        s.add_argument(flag, default="")
    s.set_defaults(fn=cmd_run)

    s = sub.add_parser("gaps")
    s.add_argument("--repo", required=True)
    s.add_argument("--module", required=True)
    s.add_argument("--report")
    s.add_argument("--scope")
    s.add_argument("--limit", type=int, default=20)
    s.set_defaults(fn=cmd_gaps)

    s = sub.add_parser("verify")
    for flag in ("--repo", "--module", "--gaps", "--fingerprint", "--test-class", "--test-method"):
        s.add_argument(flag, required=True)
    s.add_argument("--mutant", action="append", required=True)
    s.set_defaults(fn=cmd_verify)

    a = p.parse_args()
    a.repo = os.path.abspath(a.repo)
    try:
        return a.fn(a)
    except (BadInput, ET.ParseError, OSError, json.JSONDecodeError, KeyError) as e:
        print(f"error: {e}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
