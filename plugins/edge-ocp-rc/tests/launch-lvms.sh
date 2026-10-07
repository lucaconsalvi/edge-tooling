#!/usr/bin/env bash
set -euo pipefail

source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
mkdir -p "$test_dir/scripts" "$test_dir/jobs"
cp "$source_dir/scripts/launch.sh" "$test_dir/scripts/launch.sh"

printf '%s\n' 'periodic-ci-openshift-release-main-nightly-4.22-e2e-baremetalds-two-node-fencing' > "$test_dir/jobs/tnf.txt"
printf '%s\n' 'periodic-ci-openshift-lvm-operator-release-5.0-nightly-e2e-baremetalds-tnf-lvms-mno-qe-integration-tests' > "$test_dir/jobs/tnf-lvms.txt"

run_success() {
    local label="$1" expected="$2"
    shift 2
    local output
    if ! output=$("$test_dir/scripts/launch.sh" tnf "$@" --dry-run --run "$label" 2>&1); then
        echo "$label failed: $output" >&2
        exit 1
    fi
    if [[ "$output" != *"$expected"* ]]; then
        echo "$label omitted expected text: $output" >&2
        exit 1
    fi
    echo "$label: OK"
}

run_failure() {
    local label="$1" expected="$2"
    shift 2
    local output
    if output=$("$test_dir/scripts/launch.sh" tnf "$@" --dry-run --run "$label" 2>&1); then
        echo "$label unexpectedly succeeded: $output" >&2
        exit 1
    fi
    if [[ "$output" != *"$expected"* ]]; then
        echo "$label omitted expected error: $output" >&2
        exit 1
    fi
    echo "$label: OK"
}

image_5_0='registry.example.test/ocp:5.0.0-rc.5-x86_64'
image_4_22='registry.example.test/ocp:4.22.0-rc.0-x86_64'
unknown_image='registry.example.test/ocp@sha256:deadbeef'

run_success pattern-5-0 'tnf-lvms-mno-qe-integration-tests' "$image_5_0" --job lvms
run_success number-5-0 'tnf-lvms-mno-qe-integration-tests' "$image_5_0" --job 2
run_success all-4-22 '1 jobs launched' "$image_4_22" --job all
run_failure number-wrong-release 'selected job #2 targets 5.0' "$image_4_22" --job 2
run_failure pattern-unknown-release 'cannot determine the payload release' "$unknown_image" --job lvms
run_failure number-unknown-release 'cannot determine the payload release' "$unknown_image" --job 2
