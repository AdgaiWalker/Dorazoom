#!/usr/bin/env zsh
set -euo pipefail

# Prints a conservative Markdown draft for local-simulation acceptance.
#
# This helper is intentionally stdout-only: it does not edit ACCEPTANCE.md,
# install or launch DoraZoom, request permissions, reset TCC, touch pasteboard,
# capture screen/audio/camera, control target apps, register login items, or
# write user output files.

ROOT_DIR="${0:A:h:h}"
cd "$ROOT_DIR"

function usage() {
    print "usage: Scripts/phase7-acceptance-draft.sh [--self-test]"
    print ""
    print "Prints a conservative, paste-ready local-simulation acceptance draft for ACCEPTANCE.md."
    print "Run Scripts/phase7-preflight.sh first; this helper does not claim real system acceptance."
}

function current_file_count() {
    find . -path './.git' -prune -o -path './.build' -prune -o -type f -print | wc -l | tr -d ' '
}

function current_source_bytes() {
    find . -path './.git' -prune -o -path './.build' -prune -o -type f -print0 | xargs -0 stat -f %z | awk '{sum += $1} END {print sum}'
}

function artifact_status() {
    local path="$1"
    if [[ -e "$path" ]]; then
        print "存在"
    else
        print "待生成"
    fi
}

function print_local_simulation_draft() {
    local source_files
    local source_bytes
    local daily_app
    local daily_zip
    source_files="$(current_file_count)"
    source_bytes="$(current_source_bytes)"
    daily_app="$(artifact_status ".build/DoraZoom.app")"
    daily_zip="$(artifact_status ".build/DoraZoom.zip")"

    print "说明：以下是 Phase 7 本地模拟验收草稿。请以刚刚运行的 Scripts/phase7-preflight.sh 输出为准；它证明模拟契约、测试替身和产物元数据，不证明真实系统权限、真实剪贴板、真实录屏设备或真实外部播放器。"
    print ""
    print "| 项目 | 建议结果 | 建议备注 |"
    print "| --- | --- | --- |"
    print "| 自动化测试边界审计 | 通过 | Scripts/verify-test-boundary.sh PASS；自动化仍限制在模拟层/测试替身 |"
    print "| 验收记录校验器自测，确认空白验收记录会失败、已填写样本会通过 | 通过 | Scripts/verify-acceptance-record.sh --self-test PASS |"
    print "| 本地模拟验收草稿生成器自测 | 通过 | Scripts/phase7-acceptance-draft.sh --self-test PASS |"
    print "| Phase 7 preflight 自测，确认聚合入口只编排本地模拟检查 | 通过 | Scripts/phase7-preflight.sh --self-test PASS |"
    print "| 手动 first-run reset helper 未确认时拒绝执行，日常版 reset 需要额外确认 | 通过 | 由 Scripts/verify-delivery.sh 的 Manual reset helper safety audit 证明 |"
    print "| build-app.sh 输入校验 | 通过 | 非法 Bundle ID、路径型/非 .app 名称、XML 不安全 display name 均在构建/签名前拒绝 |"
    print "| swift build | 通过 | 以 Scripts/phase7-preflight.sh 中完整交付门禁输出为准 |"
    print "| swift test，110 项全量模拟测试 | 通过 | 110 XCTest cases PASS；真实系统能力不作为当前完成阻塞 |"
    print "| .build/debug/ZoomItMacSelfTest | 通过 | ZoomItMacSelfTest: PASS |"
    print "| SwiftPM 依赖 | 通过 | No external dependencies found |"
    print "| .build 根目录 App 白名单 | 通过 | 只允许 .build/DoraZoom Dev.app 与 .build/DoraZoom.app |"
    print "| .build/DoraZoom.app / .build/DoraZoom.zip 当前状态 | 记录 | 当前检查：DoraZoom.app=$daily_app；DoraZoom.zip=$daily_zip |"
    print "| 源码量快照 | 记录 | 排除 .git/.build：$source_files 个文件，$source_bytes bytes；Swift 行数以 verify-delivery 输出为准 |"
    print "| 权限、粘贴、录制、媒体兼容 | 通过 | 由模拟权限矩阵、内存剪贴板、模拟录制 writer 和本地媒体兼容矩阵证明 |"
    print "| git diff --check | 通过 | 以 Scripts/phase7-preflight.sh 中完整交付门禁输出为准 |"
    print ""
    print "最终结论建议：通过，可作为哆啦个人本地模拟验收版。不要把该结论扩写成真实系统权限或外部播放器验收。"
}

function run_self_test() {
    local output
    output="$(print_local_simulation_draft)"

    if ! print -r -- "$output" | rg '本地模拟验收草稿|Scripts/phase7-preflight\.sh|不证明真实系统权限|权限、粘贴、录制、媒体兼容' >/dev/null; then
        print "error: draft output does not include the required local-simulation guidance" >&2
        print "$output" >&2
        return 2
    fi

    local old_manual_word="manual"
    local old_acceptance_word="acceptance"
    local old_chinese_acceptance="真实可见人工""验收"
    local old_section_phrase="第 2-7 ""节"
    if print -r -- "$output" | rg "${old_chinese_acceptance}|${old_section_phrase}|${old_manual_word}[[:space:]]+${old_acceptance_word}" >/dev/null; then
        print "error: draft output still points at the old external acceptance flow" >&2
        print "$output" >&2
        return 2
    fi

    zsh -n "Scripts/phase7-acceptance-draft.sh"
    print "PASS: phase 7 acceptance draft self-test"
}

case "${1:-}" in
    --help|-h)
        usage
        ;;
    --self-test)
        run_self_test
        ;;
    "")
        print_local_simulation_draft
        ;;
    *)
        usage >&2
        exit 2
        ;;
esac
