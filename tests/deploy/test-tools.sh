#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tests/deploy/testlib.sh
source "$ROOT/tests/deploy/testlib.sh"
# shellcheck source=scripts/lib/common.sh
source "$ROOT/scripts/lib/common.sh"
# shellcheck source=scripts/lib/tools.sh
source "$ROOT/scripts/lib/tools.sh"

# Verify tools are registered
assert_eq "10 tools registered" "10" "${#TOOLS_REGISTERED[@]}"

# Verify tool exists check
[[ -v TOOL_DESC["rg"] ]]
pass "rg is a registered tool"
[[ -v TOOL_DESC["zsh"] ]]
pass "zsh is a registered tool"
[[ ! -v TOOL_DESC["nonexistent"] ]]
pass "nonexistent tool is not registered"

# Verify tool sets
assert_eq "minimal set has 3 tools" "3" "$(tools_set_members minimal | wc -w)"
assert_eq "desktop-full set has 10 tools" "10" "$(tools_set_members desktop-full | wc -w)"

# Verify tool_is_installed for zsh (should be true on this host)
tool_is_installed zsh
pass "zsh is installed on this host"

# Verify tool_package_name mapping
assert_eq "rg fedora package is ripgrep" "ripgrep" "$(tool_package_name rg fedora)"
assert_eq "rg ubuntu package is ripgrep" "ripgrep" "$(tool_package_name rg ubuntu)"
assert_eq "fd fedora package is fd-find" "fd-find" "$(tool_package_name fd fedora)"

# Verify yazi has empty ubuntu package (manual hint)
assert_eq "yazi ubuntu package is empty" "" "$(tool_package_name yazi ubuntu)"
assert_eq "yazi fedora package is yazi" "yazi" "$(tool_package_name yazi fedora)"

# Verify manual hint
assert_eq "yazi manual hint is set" "cargo install --locked yazi-fm yazi-cli" "${TOOL_MANUAL_HINT[yazi]}"
assert_eq "rg manual hint is empty" "" "${TOOL_MANUAL_HINT[rg]}"

# Verify tools_check_all produces output
tools_output="$(tools_check_all)"
assert_text_contains "tools_check_all has header" "Tool" "$tools_output"
assert_text_contains "tools_check_all lists rg" "rg" "$tools_output"
assert_text_contains "tools_check_all lists zsh" "zsh" "$tools_output"
ubuntu_tools_output="$(tools_check_all ubuntu)"
assert_text_contains "tool table labels active OS package" "Package (ubuntu)" "$ubuntu_tools_output"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
printf '#!/usr/bin/env bash\n' > "$TMPDIR/fdfind"
chmod +x "$TMPDIR/fdfind"
PATH="$TMPDIR:$PATH"
TOOL_DETECT[alias-probe]="command-any:missing-fd,fdfind"
tool_is_installed alias-probe
pass "command-any detection accepts Ubuntu fdfind alias"

# Verify tools_missing_from — skips unknown tools, reports missing known ones
missing="$(tools_missing_from "zsh tmux lazygit")"
assert_text_not_contains "tools_missing_from does not report zsh" "zsh" "$missing"
# zsh and tmux are installed, lazygit may or may not be — just check no crash
pass "tools_missing_from handles mixed known tools without error"

# Verify tools_list_sets
sets="$(tools_list_sets)"
assert_text_contains "sets lists minimal" "minimal" "$sets"
assert_text_contains "sets lists desktop-full" "desktop-full" "$sets"

finish_tests
