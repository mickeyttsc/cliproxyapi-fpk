#!/usr/bin/env bash
# auto-update-tick.sh — 单次上游巡检（一次「tick」）
# 只做【检测 + bump + 提交 + 触发构建】，不负责发布（Release 归属 build.yml 独占）。
# 可独立手动运行（不依赖 CI，便于本机验证）。退出码始终 0（失败不中断长驻循环）。
set -uo pipefail

CPAPI_ENV=config/upstream/cliproxyapi.env
CPAMC_ENV=config/upstream/cpamc.env

log() { echo "[$(date -u '+%H:%M:%S')] $*"; }

# ── 1. 探测上游 ──
CPAPI_LATEST="$(python3 scripts/detect-upstream.py cpapi 2>/dev/null)"
if [ -z "$CPAPI_LATEST" ]; then
    log "WARN 未能解析可打包的 CLIProxyAPI 版本，本轮跳过"
    exit 0
fi
CPAMC_LATEST="$(python3 scripts/detect-upstream.py cpamc 2>/dev/null)"
if [ -z "$CPAMC_LATEST" ]; then
    log "WARN 未能解析可打包的管理面板版本，本轮跳过"
    exit 0
fi

CPAPI_SHA="$(python3 scripts/detect-upstream.py cpapi-sha "$CPAPI_LATEST" 2>/dev/null)"
printf '%s' "$CPAPI_SHA" | grep -qE '^[0-9a-f]{64}$' || { log "WARN CLIProxyAPI sha256 获取失败/格式非法，本轮跳过"; exit 0; }
CPAMC_SHA="$(python3 scripts/detect-upstream.py cpamc-sha "$CPAMC_LATEST" 2>/dev/null)"
printf '%s' "$CPAMC_SHA" | grep -qE '^[0-9a-f]{64}$' || { log "WARN 管理面板 sha256 获取失败/格式非法，本轮跳过"; exit 0; }

# ── 2. 与当前记录比对 ──
CUR_CPAPI="$(grep '^CLIPROXYAPI_VERSION=' "$CPAPI_ENV" | cut -d= -f2)"
CUR_CPAMC="$(grep '^CPAMC_VERSION=' "$CPAMC_ENV" | cut -d= -f2)"
CUR_VER="$(grep '^version' manifest | cut -d= -f2 | tr -d ' ')"
CUR_BASE="${CUR_VER%-*}"
CUR_BUILD="${CUR_VER##*-}"
case "${CUR_BUILD}" in ''|*[!0-9]*) CUR_BUILD=0 ;; esac

CHANGED=0
[ "$CPAPI_LATEST" != "$CUR_CPAPI" ] && CHANGED=1
[ "$CPAMC_LATEST" != "$CUR_CPAMC" ] && CHANGED=1
# sha 固定值失配（上游重发了同版本资产）也算变化
grep -qF "CLIPROXYAPI_SHA256=$CPAPI_SHA" "$CPAPI_ENV" || CHANGED=1
grep -qF "CPAMC_SHA256=$CPAMC_SHA" "$CPAMC_ENV" || CHANGED=1

if [ "$CHANGED" != "1" ]; then
    # 幂等 ≠ 什么都不做：可能还有上一轮【未推送成功】的提交（push 失败后不再重试的坑）
    if [ -n "${GITHUB_REPOSITORY:-}" ] && git rev-parse --verify origin/main >/dev/null 2>&1; then
        AHEAD="$(git rev-list --count origin/main..HEAD 2>/dev/null || echo 0)"
        if [ "${AHEAD:-0}" -gt 0 ]; then
            log "up-to-date 但本地领先远端 ${AHEAD} 个提交 → 补推"
            git pull --rebase --autostash -q origin main 2>/dev/null || true
            if git push -q origin main 2>/dev/null; then
                log "补推成功，触发构建"
                curl -sS -o /dev/null -w '' --max-time 60 -X POST \
                    -H "Authorization: token ${GITHUB_TOKEN}" \
                    -H "Accept: application/vnd.github+json" \
                    "https://api.github.com/repos/${GITHUB_REPOSITORY}/actions/workflows/build.yml/dispatches" \
                    -d '{"ref":"main"}' 2>/dev/null || true
            else
                log "补推仍失败（下一轮重试）"
            fi
            exit 0
        fi
    fi
    log "up-to-date: cpapi=${CUR_CPAPI} cpamc=${CUR_CPAMC} fpk=${CUR_VER}"
    exit 0
fi

log "发现更新: cpapi ${CUR_CPAPI} -> ${CPAPI_LATEST} / cpamc ${CUR_CPAMC} -> ${CPAMC_LATEST}"

# ── 3. 写回版本锚点与 sha256 固定值 ──
sed -i "s/^CLIPROXYAPI_VERSION=.*/CLIPROXYAPI_VERSION=${CPAPI_LATEST}/" "$CPAPI_ENV"
sed -i "s/^CLIPROXYAPI_SHA256=.*/CLIPROXYAPI_SHA256=${CPAPI_SHA}/" "$CPAPI_ENV"
sed -i "s/^CPAMC_VERSION=.*/CPAMC_VERSION=${CPAMC_LATEST}/" "$CPAMC_ENV"
sed -i "s/^CPAMC_SHA256=.*/CPAMC_SHA256=${CPAMC_SHA}/" "$CPAMC_ENV"

# 版本号规则：主程序版本变化 → 重置为 -1；仅面板/封装变化 → 迭代号 +1
if [ "$CPAPI_LATEST" != "$CUR_BASE" ]; then
    NEW_VER="${CPAPI_LATEST}-1"
else
    NEW_VER="${CUR_BASE}-$((CUR_BUILD + 1))"
fi
sed -i "s/^version[[:space:]]*=.*/version               = ${NEW_VER}/" manifest
log "新 FPK 版本: ${NEW_VER}"

# ── 4. 提交并推送 ──
git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"
git add "$CPAPI_ENV" "$CPAMC_ENV" manifest
if ! git diff --cached --quiet; then
    git commit -q -m "chore: auto-bump upstream -> CLIProxyAPI ${CPAPI_LATEST} / panel ${CPAMC_LATEST} (FPK ${NEW_VER})"
    git pull --rebase --autostash -q origin main 2>/dev/null || true
    if git push -q origin main 2>/dev/null; then
        log "已推送 bump 提交"
    else
        log "ERROR 推送失败（下一轮重试）"
        exit 0
    fi
else
    log "无实际改动可提交（可能已被其它 run 处理）"
fi

# ── 5. 立刻触发构建（长驻 job 不结束，不能等 workflow_run 接力）──
if [ -n "${GITHUB_TOKEN:-}" ] && [ -n "${GITHUB_REPOSITORY:-}" ]; then
    CODE="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 60 -X POST \
        -H "Authorization: token ${GITHUB_TOKEN}" \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/${GITHUB_REPOSITORY}/actions/workflows/build.yml/dispatches" \
        -d '{"ref":"main"}' 2>/dev/null || echo 000)"
    if [ "${CODE}" = "204" ]; then
        log "已触发 build.yml（HTTP 204）"
    else
        log "WARN 触发 build.yml 失败 HTTP ${CODE}（bump 已入库，可手动/下次重试）"
    fi
else
    log "本地模式：跳过触发 build.yml（无 GITHUB_TOKEN/GITHUB_REPOSITORY）"
fi

exit 0
