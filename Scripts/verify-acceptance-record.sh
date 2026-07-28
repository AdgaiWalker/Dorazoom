#!/usr/bin/env zsh
set -euo pipefail

# Non-invasive Phase 7 acceptance-record verifier.
#
# This script reads an already-filled Markdown acceptance record and fails if
# required result cells are still blank. It never launches DoraZoom, never
# installs an app, never requests TCC permissions, and never touches real
# keyboard, pasteboard, screen, audio, camera, login item, target-app or output
# file state.

function usage() {
    print "usage: Scripts/verify-acceptance-record.sh [ACCEPTANCE.md]"
    print "       Scripts/verify-acceptance-record.sh --self-test"
}

function verify_markdown_record() {
    local record_path="$1"

    if [[ ! -f "$record_path" ]]; then
        print "error: acceptance record not found: $record_path" >&2
        return 2
    fi

    awk '
    function trim(value) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
        return value
    }

    function split_cells(line, cells, raw, count, idx) {
        raw = line
        sub(/^[[:space:]]*\|/, "", raw)
        sub(/\|[[:space:]]*$/, "", raw)
        count = split(raw, cells, /\|/)
        for (idx = 1; idx <= count; idx++) {
            cells[idx] = trim(cells[idx])
        }
        return count
    }

    function is_separator_row(cells, count, idx, normalized) {
        if (count == 0) {
            return 0
        }
        for (idx = 1; idx <= count; idx++) {
            normalized = cells[idx]
            gsub(/[[:space:]:-]/, "", normalized)
            if (normalized != "") {
                return 0
            }
        }
        return 1
    }

    function reset_table() {
        in_table = 0
        waiting_for_separator = 0
        required_count = 0
        delete required_indexes
        delete required_names
    }

    function register_header(cells, count, idx) {
        reset_table()
        in_table = 1
        waiting_for_separator = 1
        for (idx = 1; idx <= count; idx++) {
            if (cells[idx] == "结果" || cells[idx] == "记录" || cells[idx] == "结论") {
                required_count += 1
                required_indexes[required_count] = idx
                required_names[required_count] = cells[idx]
            }
        }
    }

    function cell_is_blank(value, normalized) {
        normalized = value
        gsub(/<br[[:space:]]*\/?>/, "", normalized)
        gsub(/&nbsp;/, "", normalized)
        normalized = trim(normalized)
        return normalized == ""
    }

    BEGIN {
        reset_table()
        in_fence = 0
        errors = 0
        final_conclusion_checked = 0
        in_final_conclusion = 0
    }

    /^[[:space:]]*```/ {
        in_fence = !in_fence
        next
    }

    in_fence {
        next
    }

    /^最终结论：/ {
        in_final_conclusion = 1
        reset_table()
        next
    }

    in_final_conclusion && /^[[:space:]]*-[[:space:]]+\[[xX]\]/ {
        final_conclusion_checked += 1
        next
    }

    /^[[:space:]]*\|/ {
        cell_count = split_cells($0, cells)

        if (!in_table) {
            register_header(cells, cell_count)
            next
        }

        if (waiting_for_separator) {
            if (is_separator_row(cells, cell_count)) {
                waiting_for_separator = 0
                next
            }
            register_header(cells, cell_count)
            next
        }

        if (is_separator_row(cells, cell_count)) {
            next
        }

        for (required = 1; required <= required_count; required++) {
            column_index = required_indexes[required]
            if (cell_is_blank(cells[column_index])) {
                first_cell = cells[1]
                if (first_cell == "") {
                    first_cell = "(unnamed row)"
                }
                printf("error:%s:%d: blank required acceptance cell '%s' for '%s'\n", FILENAME, FNR, required_names[required], first_cell) > "/dev/stderr"
                errors += 1
            }
        }
        next
    }

    {
        reset_table()
    }

    END {
        if (final_conclusion_checked == 0) {
            printf("error:%s: final conclusion checkbox is not selected\n", FILENAME) > "/dev/stderr"
            errors += 1
        } else if (final_conclusion_checked > 1) {
            printf("error:%s: final conclusion must select exactly one checkbox, found %d\n", FILENAME, final_conclusion_checked) > "/dev/stderr"
            errors += 1
        }

        if (errors > 0) {
            exit 2
        }
    }
    ' "$record_path"
}

function run_self_test() {
    local temp_dir
    temp_dir="$(mktemp -d)"
    ACCEPTANCE_RECORD_SELF_TEST_TEMP_DIR="$temp_dir"
    trap 'rm -rf "${ACCEPTANCE_RECORD_SELF_TEST_TEMP_DIR:-}"' EXIT

    local blank_record="$temp_dir/blank.md"
    local filled_record="$temp_dir/filled.md"

    {
        print "# Acceptance"
        print ""
        print "| 项目 | 结果 | 备注 |"
        print "| --- | --- | --- |"
        print "| 非侵入门禁 |  |  |"
        print ""
        print "最终结论："
        print ""
        print -r -- "- [ ] 通过"
        print -r -- "- [ ] 不通过"
    } > "$blank_record"

    {
        print "# Acceptance"
        print ""
        print "| 项目 | 结果 | 备注 |"
        print "| --- | --- | --- |"
        print "| 非侵入门禁 | 通过 | 记录命令 |"
        print ""
        print "| 项目 | 记录 |"
        print "| --- | --- |"
        print "| Mac 机型 | MacBook Pro |"
        print ""
        print "| 维度 | 结论 | 备注 |"
        print "| --- | --- | --- |"
        print "| 是否接受作为个人日常版 | 通过 | 哆啦签收 |"
        print ""
        print "最终结论："
        print ""
        print -r -- "- [x] 通过"
        print -r -- "- [ ] 不通过"
    } > "$filled_record"

    local blank_output
    local blank_status=0
    blank_output="$(verify_markdown_record "$blank_record" 2>&1)" || blank_status=$?

    if [[ "$blank_status" != "2" ]]; then
        print "error: self-test expected blank record to fail with status 2, got $blank_status" >&2
        print "$blank_output" >&2
        return 2
    fi

    if ! print -r -- "$blank_output" | rg "blank required acceptance cell '结果'|final conclusion checkbox is not selected" >/dev/null; then
        print "error: self-test blank failure did not explain the missing acceptance result" >&2
        print "$blank_output" >&2
        return 2
    fi

    verify_markdown_record "$filled_record"
    print "PASS: acceptance record verifier self-test"
}

case "${1:-}" in
    --help|-h)
        usage
        ;;
    --self-test)
        run_self_test
        ;;
    "")
        verify_markdown_record "ACCEPTANCE.md"
        ;;
    *)
        verify_markdown_record "$1"
        ;;
esac
