#!/bin/bash
# Read-only smoke checks for the project-scaffolding spec.
# Reports "FAIL <file>: <check>" for each failure and exits non-zero if any occur.
# Makes no changes and runs no git commands.
set -u
cd "$(dirname "$0")/.." || exit 1

FAILURES=0

fail() {
    echo "FAIL $1: $2"
    FAILURES=$((FAILURES + 1))
}

# has_text <file> <fixed string> <description>  (case-insensitive)
has_text() {
    if [ ! -f "$1" ]; then
        fail "$1" "file missing (needed for: $3)"
    elif ! grep -qiF -- "$2" "$1"; then
        fail "$1" "missing $3"
    fi
}

# has_regex <file> <extended regex> <description>  (case-insensitive)
has_regex() {
    if [ ! -f "$1" ]; then
        fail "$1" "file missing (needed for: $3)"
    elif ! grep -qiE -- "$2" "$1"; then
        fail "$1" "missing $3"
    fi
}

# first_line_of <file>
first_line_of() {
    head -n 1 "$1" 2>/dev/null
}

# ---------------------------------------------------------------- R1 structure
REQUIRED_DIRS="
Sources/PhantomTraceCore
Sources/phantomtrace
Tests/PhantomTraceCoreTests
Tests/PhantomTracePropertyTests
Tests/Fixtures
docs
Scripts
.kiro/steering
.kiro/hooks
Sources/PhantomTraceCore/Mounts
Sources/PhantomTraceCore/Discovery
Sources/PhantomTraceCore/Resolution
Sources/PhantomTraceCore/System
Sources/PhantomTraceCore/Models
"
for d in $REQUIRED_DIRS; do
    [ -d "$d" ] || fail "$d" "required directory missing"
done

# .gitkeep is required in a scaffold directory that holds nothing else.
KEEP_DIRS="
Sources/PhantomTraceCore/Mounts
Sources/PhantomTraceCore/Discovery
Sources/PhantomTraceCore/Resolution
Sources/PhantomTraceCore/System
Sources/PhantomTraceCore/Models
Tests/Fixtures
docs/screenshots
"
for d in $KEEP_DIRS; do
    [ -d "$d" ] || { fail "$d" "required directory missing"; continue; }
    others=$(find "$d" -mindepth 1 -maxdepth 1 ! -name .gitkeep ! -name .DS_Store 2>/dev/null | head -n 1)
    if [ -z "$others" ]; then
        if [ ! -f "$d/.gitkeep" ]; then
            fail "$d/.gitkeep" "empty directory has no .gitkeep"
        elif [ -s "$d/.gitkeep" ]; then
            fail "$d/.gitkeep" ".gitkeep is not zero bytes"
        fi
    fi
done

if [ -f docs/screenshots/.gitkeep ] && [ -s docs/screenshots/.gitkeep ]; then
    fail docs/screenshots/.gitkeep "size is not 0 bytes"
fi

# Forbidden items (excluding build output, SwiftPM state, and .git)
forbidden=$(find . \( -path ./.build -o -path ./.swiftpm -o -path ./.git \) -prune -o \
    \( -name App -type d -o -name '*.xcodeproj' -o -name '*.xcworkspace' \
       -o -name '*.workflow' -o -name '*.action' \) -print 2>/dev/null)
if [ -n "$forbidden" ]; then
    for f in $forbidden; do
        fail "$f" "forbidden item (App, Xcode project/workspace, or Quick Action) present"
    done
fi

# ------------------------------------------------------------- R2 Package.swift
PKG=Package.swift
if [ ! -f "$PKG" ]; then
    fail "$PKG" "file missing"
else
    lib_count=$(grep -cE '^[[:space:]]*\.target\(' "$PKG")
    exe_count=$(grep -cE '\.executableTarget\(' "$PKG")
    [ "$lib_count" -eq 1 ] || fail "$PKG" "expected exactly one library target, found $lib_count"
    [ "$exe_count" -eq 1 ] || fail "$PKG" "expected exactly one executable target, found $exe_count"
    has_text "$PKG" '.target(name: "PhantomTraceCore"' 'library target PhantomTraceCore'
    has_text "$PKG" '.executableTarget(name: "phantomtrace"' 'executable target phantomtrace'
    has_text "$PKG" 'name: "PhantomTraceCoreTests"' 'test target PhantomTraceCoreTests'
    has_text "$PKG" 'name: "PhantomTracePropertyTests"' 'test target PhantomTracePropertyTests'

    # Exactly one package dependency, and it is swift-property-based
    dep_count=$(grep -cE '\.package\(' "$PKG")
    [ "$dep_count" -eq 1 ] || fail "$PKG" "expected exactly one package dependency, found $dep_count"
    has_text "$PKG" 'swift-property-based' 'swift-property-based dependency'

    # swift-property-based must appear only inside the PhantomTracePropertyTests target
    prop_use=$(grep -c 'package: "swift-property-based"' "$PKG")
    in_prop=$(awk '
        /name: "PhantomTracePropertyTests"/ { inprop = 1 }
        inprop && /package: "swift-property-based"/ { n++ }
        END { print n + 0 }' "$PKG")
    if [ "$prop_use" -ne 1 ] || [ "$in_prop" -ne 1 ]; then
        fail "$PKG" "swift-property-based must be a dependency of PhantomTracePropertyTests only"
    fi
fi

# --------------------------------------------------------------- R3 README
README=README.md
has_text "$README" 'scaffolding stage' 'phrase "scaffolding stage"'
has_text "$README" 'macOS only' 'platform statement "macOS only"'
has_text "$README" 'macOS 27.2.1 (build 26B131) only' 'platform statement "macOS 27.2.1 (build 26B131) only"'
has_text "$README" 'MIT License' 'MIT License statement'
has_text "$README" 'Kiroween 2026' 'hackathon name'
has_text "$README" 'Resurrection' 'hackathon category'
has_text "$README" 'LICENSE' 'link to LICENSE'
has_text "$README" '.kiro/specs/phantomtrace-volume-lock-forensics' 'link to master spec'
has_text "$README" '.kiro/specs/project-scaffolding' 'link to project-scaffolding spec'
has_text "$README" 'docs/ProjectOverview.md' 'link to ProjectOverview.md'
has_text "$README" 'docs/SubmissionChecklist.md' 'link to SubmissionChecklist.md'
has_text "$README" 'docs/KiroUsage.md' 'link to KiroUsage.md'

if [ -f "$README" ]; then
    build_line=$(grep -nx 'swift build' "$README" | head -n 1 | cut -d: -f1)
    test_line=$(grep -nx 'swift test' "$README" | head -n 1 | cut -d: -f1)
    if [ -z "$build_line" ] || [ -z "$test_line" ]; then
        fail "$README" "missing 'swift build' or 'swift test' command line in a fenced block"
    elif [ "$build_line" -ge "$test_line" ]; then
        fail "$README" "'swift build' must appear before 'swift test'"
    else
        fences_before_build=$(head -n "$build_line" "$README" | grep -c '^```')
        fences_before_test=$(head -n "$test_line" "$README" | grep -c '^```')
        if [ $((fences_before_build % 2)) -ne 1 ] || [ $((fences_before_test % 2)) -ne 1 ]; then
            fail "$README" "'swift build' and 'swift test' must each be inside a fenced code block"
        fi
    fi
fi

# check_links <markdown file>: every relative link target must exist
check_links() {
    local file="$1" dir target path
    [ -f "$file" ] || { fail "$file" "file missing (link check)"; return; }
    dir=$(dirname "$file")
    # Drop fenced code blocks, then extract inline link targets.
    awk '/^```/ { skip = !skip; next } !skip' "$file" \
        | grep -oE '\]\([^)[:space:]]+\)' \
        | sed -E 's/^\]\((.*)\)$/\1/' \
        | while IFS= read -r target; do
            case "$target" in
                ''|'#'*|/*|*://*|mailto:*) continue ;;
            esac
            path="${target%%#*}"
            [ -n "$path" ] || continue
            if [ ! -e "$dir/$path" ]; then
                echo "BROKEN $file $target"
            fi
        done
}
link_report=$(
    check_links README.md
    for f in docs/*.md; do
        [ -f "$f" ] && check_links "$f"
    done
)
if [ -n "$link_report" ]; then
    while IFS= read -r line; do
        f=$(echo "$line" | awk '{print $2}')
        t=$(echo "$line" | awk '{print $3}')
        fail "$f" "broken relative link: $t"
    done <<EOF
$link_report
EOF
fi

# --------------------------------------------------------- R4 LICENSE/ignore/lint
if [ ! -f LICENSE ]; then
    fail LICENSE "file missing"
else
    has_text LICENSE 'MIT License' 'MIT License title'
    has_text LICENSE 'Permission is hereby granted, free of charge' 'standard MIT permission text'
    if ! grep -qE '^Copyright \(c\) [0-9]{4} .+' LICENSE; then
        fail LICENSE "copyright line must match 'Copyright (c) <YYYY> <holder>'"
    fi
fi

if [ ! -f .gitignore ]; then
    fail .gitignore "file missing"
else
    for entry in '.build/' '.swiftpm/' '*.xcodeproj/xcuserdata/' 'DerivedData/' '.DS_Store'; do
        grep -qxF -- "$entry" .gitignore || fail .gitignore "missing entry on its own line: $entry"
    done
    # No entry may ignore .kiro or anything beneath it
    if grep -qE '^[[:space:]]*[!]?/?(\*\*/)?\.kiro(/.*)?[[:space:]]*$' .gitignore; then
        fail .gitignore "contains an entry matching .kiro (can disqualify the hackathon submission)"
    fi
fi

if [ ! -f .swiftlint.yml ]; then
    fail .swiftlint.yml "file missing"
else
    included=$(awk '
        /^included:/ { on = 1; next }
        on && /^[[:space:]]*-[[:space:]]*/ { gsub(/^[[:space:]]*-[[:space:]]*/, ""); print; next }
        on && /^[^[:space:]]/ { on = 0 }' .swiftlint.yml | tr -d ' "' | sort | tr '\n' ' ')
    [ "$included" = "Sources Tests " ] || fail .swiftlint.yml "'included' must be exactly Sources and Tests"
fi

# --------------------------------------------------------------- R5 docs
for f in docs/architecture.md docs/demo-script.md docs/ProjectOverview.md \
         docs/SubmissionChecklist.md docs/KiroUsage.md; do
    if [ ! -s "$f" ]; then
        fail "$f" "file missing or empty"
    fi
done
[ -f docs/screenshots/.gitkeep ] || fail docs/screenshots/.gitkeep "file missing"

for f in docs/architecture.md docs/demo-script.md; do
    if [ -f "$f" ]; then
        if ! first_line_of "$f" | grep -qE '^# [^[:space:]]'; then
            fail "$f" "first line must be a non-empty level-1 heading"
        fi
    fi
done
has_regex docs/architecture.md '\]\((\.\./)+\.kiro/specs/phantomtrace-volume-lock-forensics/design\.md\)' \
    'relative link to the master spec design.md'
if [ -f docs/architecture.md ] && [ -f .kiro/specs/phantomtrace-volume-lock-forensics/design.md ]; then
    :
elif [ -f docs/architecture.md ]; then
    fail .kiro/specs/phantomtrace-volume-lock-forensics/design.md "master spec design.md missing"
fi
has_text docs/demo-script.md 'The demo length target is at most 3 minutes (180 seconds).' \
    'the 180-second demo length sentence'
has_text docs/demo-script.md 'Finder' 'demo flow mention of Finder failing to eject'

# --------------------------------------------------------------- R6 steering
STEER=.kiro/steering
for f in product tech structure safety testing hackathon; do
    p="$STEER/$f.md"
    if [ ! -s "$p" ]; then
        fail "$p" "file missing or empty"
    elif ! iconv -f UTF-8 -t UTF-8 "$p" >/dev/null 2>&1; then
        fail "$p" "not valid UTF-8"
    fi
done
has_text $STEER/product.md 'identify which processes prevent a volume from ejecting' 'mission statement'
has_text $STEER/product.md 'Resurrection' 'Resurrection theme'
has_text $STEER/product.md '27.2.1 (build 26B131)' 'platform target 27.2.1 (build 26B131)'
has_text $STEER/product.md 'macOS only' 'macOS-only statement'
has_text $STEER/tech.md 'Swift' 'Swift'
has_text $STEER/tech.md 'SwiftPM' 'SwiftPM'
has_text $STEER/tech.md 'AppKit' 'AppKit'
has_text $STEER/tech.md 'DiskArbitration' 'DiskArbitration'
has_text $STEER/tech.md '27.2.1' 'macOS 27.2.1 platform statement'
has_regex $STEER/tech.md 'zero third-party runtime dependencies' 'zero third-party runtime dependencies rule'
has_text $STEER/tech.md 'swift-property-based' 'swift-property-based as a dev tool'
has_text $STEER/tech.md 'SwiftLint' 'SwiftLint as a dev tool'
has_regex $STEER/structure.md 'imports no AppKit' 'rule that Core imports no AppKit'
for d in Sources/PhantomTraceCore Sources/phantomtrace Tests/PhantomTraceCoreTests \
         Tests/PhantomTracePropertyTests Tests/Fixtures docs Scripts .kiro/steering .kiro/hooks \
         Mounts Discovery Resolution System Models; do
    has_text $STEER/structure.md "$d" "directory convention $d"
done
has_regex $STEER/safety.md 'argument array' 'argument-array subprocess rule'
has_regex $STEER/safety.md 'without a shell|no shell|never.*shell|/bin/sh -c' 'no-shell rule'
has_text $STEER/safety.md 'SafetyPolicy' 'SafetyPolicy single approval path'
has_regex $STEER/safety.md 'protected process' 'protected-processes rule'
has_regex $STEER/safety.md 'no network|zero network' 'no-network rule'
has_text $STEER/safety.md 'telemetry' 'no-telemetry rule'
has_text $STEER/testing.md 'swift-property-based' 'swift-property-based convention'
has_regex $STEER/testing.md '500' '500-iteration minimum'
has_text $STEER/testing.md 'round-trip' 'round-trip property convention'
has_regex $STEER/testing.md 'protocol' 'mock-protocol convention'
has_text $STEER/hackathon.md 'Resurrection' 'Resurrection category'
has_text $STEER/hackathon.md 'December 4, 2026' 'submission deadline'
has_text $STEER/hackathon.md '.kiro/' 'never-gitignore .kiro rule'
has_text $STEER/hackathon.md 'MIT' 'MIT license statement'
has_text $STEER/hackathon.md 'English' 'English-only statement'
has_text $STEER/hackathon.md 'KiroUsage.md' 'KiroUsage.md currency rule'
has_regex $STEER/hackathon.md '3 minutes' 'demo video under 3 minutes'

# --------------------------------------------------------------- R7 hooks
for h in lint-on-save pre-commit-check kiro-gitignore-guard; do
    p=".kiro/hooks/$h.json"
    if [ ! -f "$p" ]; then
        fail "$p" "hook file missing"
        continue
    fi
    result=$(python3 - "$p" <<'PY'
import json, sys
try:
    with open(sys.argv[1]) as fh:
        data = json.load(fh)
except Exception as exc:
    print("invalid JSON: %s" % exc)
    sys.exit(0)
hooks = data.get("hooks") if isinstance(data, dict) else None
if not isinstance(hooks, list) or len(hooks) != 1:
    print("must define exactly one hook in 'hooks'")
    sys.exit(0)
hook = hooks[0]
if not isinstance(hook.get("trigger"), str) or not hook["trigger"]:
    print("must define exactly one trigger")
elif not isinstance(hook.get("action"), dict) or not hook["action"].get("type"):
    print("must define exactly one action")
else:
    print("ok")
PY
)
    [ "$result" = "ok" ] || fail "$p" "$result"
done
# Exactly the three required hook files are the Requirement 7.1 set; extra hooks
# (for example project-log-check.json) are allowed by later features and not flagged.

# --------------------------------------------------------------- R8 scripts
if [ ! -f Scripts/lint-and-test.sh ]; then
    fail Scripts/lint-and-test.sh "file missing"
elif [ ! -x Scripts/lint-and-test.sh ]; then
    fail Scripts/lint-and-test.sh "owner execute bit not set"
fi
has_text Scripts/README.md 'install-quick-action.sh' 'note that install-quick-action.sh is reserved'

# --------------------------------------------------------------- R9 hackathon
for d in .kiro/specs .kiro/steering .kiro/hooks; do
    [ -d "$d" ] || fail "$d" "required directory missing"
done
for f in docs/ProjectOverview.md docs/SubmissionChecklist.md docs/KiroUsage.md .kiro/steering/hackathon.md; do
    [ -s "$f" ] || fail "$f" "file missing or empty"
done
has_text README.md '27.2.1' 'macOS 27.2.1 statement'
has_text docs/ProjectOverview.md '27.2.1' 'macOS 27.2.1 statement'

# ------------------------------------------------------------------- result
if [ "$FAILURES" -gt 0 ]; then
    echo "verify-scaffold: $FAILURES check(s) failed"
    exit 1
fi
echo "verify-scaffold: all checks passed"
exit 0
