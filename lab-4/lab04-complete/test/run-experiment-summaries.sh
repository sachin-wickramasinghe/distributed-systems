#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

run_and_capture() {
  local script_name="$1"
  "$SCRIPT_DIR/$script_name"
}

print_heading() {
  local title="$1"
  printf '\n====================================================\n'
  printf ' %s\n' "$title"
  printf '====================================================\n\n'
}

extract_experiment_a() {
  awk '
    /^Step 3: Matrix \(write protocol x read protocol\)/ { in_matrix = 1 }
    /^Required observations$/ { in_required = 1 }
    /^Experiment A complete\.$/ { in_required = 0 }

    in_matrix {
      print
      if ($0 == "") {
        in_matrix = 0
      }
      next
    }

    in_required { print }
  '
}

extract_experiment_b() {
  awk '
    /^Benchmark table \(filled from this run\)$/ { in_table = 1 }
    /^Table saved to:/ { in_table = 0 }
    /^Required observations$/ { in_required = 1 }
    /^Experiment B complete\.$/ { in_required = 0 }

    in_table || in_required { print }
  '
}

extract_experiment_c() {
  awk '
    /^Required observations$/ { in_required = 1 }
    /^Experiment C complete\.$/ { in_required = 0 }
    in_required { print }
  '
}

extract_experiment_d() {
  awk '
    /^Protocol[[:space:]]+\|[[:space:]]+Get time$/ { in_table = 1 }
    /^Required observations$/ { in_table = 0; in_required = 1 }
    /^Experiment D complete\.$/ { in_required = 0 }

    in_table || in_required { print }
  '
}

run_summary() {
  local label="$1"
  local script_name="$2"
  local extractor="$3"
  local output

  print_heading "$label"
  output="$(run_and_capture "$script_name")"
  printf '%s\n' "$output" | "$extractor"
}

main() {
  run_summary "Experiment A Summary" "experiment-a-rpc.sh" extract_experiment_a
  run_summary "Experiment B Summary" "experiment-b-grpc.sh" extract_experiment_b
  run_summary "Experiment C Summary" "experiment-c-rest.sh" extract_experiment_c
  run_summary "Experiment D Summary" "experiment-d-benchmark.sh" extract_experiment_d
}

main "$@"