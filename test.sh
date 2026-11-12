#!/usr/bin/env bash
# Runs the package's unit tests under a hard time limit. Arguments pass through to `swift test`.
#
# Swift Testing's `.timeLimit` reports a slow test but cannot resume a lost continuation, so a test
# whose resume path breaks hangs forever. This kills such a run and reports it as a failure.
#
#   ./test.sh
#   TEST_TIME_LIMIT_SECONDS=90 ./test.sh --filter TestClockTests

set -uo pipefail
cd "$(dirname "$0")"

time_limit_seconds="${TEST_TIME_LIMIT_SECONDS:-300}"
timeout_marker="$(mktemp)"
rm -f "$timeout_marker"

# `swift test` starts its test helper in a separate process group, so a group kill misses it.
# Walk the process tree instead.
kill_tree() {
    local child
    for child in $(pgrep -P "$1"); do
        kill_tree "$child"
    done
    kill -KILL "$1" 2>/dev/null
}

swift test "$@" &
test_pid=$!

(
    sleep "$time_limit_seconds"
    touch "$timeout_marker"
    kill_tree "$test_pid"
) &
watchdog_pid=$!

# Ctrl-C or a kill of this script would otherwise leave the tests and the watchdog running.
trap 'kill_tree "$watchdog_pid"; kill_tree "$test_pid"; rm -f "$timeout_marker"; exit 130' INT TERM

wait "$test_pid"
test_status=$?

kill_tree "$watchdog_pid"
wait "$watchdog_pid" 2>/dev/null

if [[ -e "$timeout_marker" ]]; then
    rm -f "$timeout_marker"
    echo "error: tests still running after ${time_limit_seconds}s; a test is likely hung on a continuation that never resumes" >&2
    exit 124
fi

exit "$test_status"
