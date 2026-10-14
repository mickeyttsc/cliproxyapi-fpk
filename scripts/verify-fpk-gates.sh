#!/usr/bin/env bash
# FPK 硬门禁（CI 与本机共用同一份，避免两处漂移）
# 用法：bash scripts/verify-fpk-gates.sh <fpk 路径>
# 任何一条不过 → exit 1（构建不发版）。
set -euo pipefail

FPK="${1:?用法: verify-fpk-gates.sh <fpk>}"
fail() { echo "::error::$*"; exit 1; }

[ -f "$FPK" ] || fail "找不到 $FPK"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# ── 0. 门禁自检：证明 grep 通路是活的（防管道/写法坏掉后恒真恒假）──
printf 'SENTINEL_CANARY\n' > "$TMP/canary"
grep -q SENTINEL_CANARY "$TMP/canary" || fail "门禁自检失败：grep 通路异常"

# ── 1. 外层结构 ──
tar tzf "$FPK" > "$TMP/outer.list" || fail "外层不是有效 tar.gz"
for f in manifest manifest.checksum cmd config wizard app.tgz ICON.PNG ICON_256.PNG; do
    grep -qE "^${f}(/|$)" "$TMP/outer.list" || fail "外层缺条目: $f"
done

# ── 2. checksum 自洽（manifest.checksum 与 manifest 字段都要等于 md5(app.tgz)）──
tar xzf "$FPK" -C "$TMP" app.tgz manifest manifest.checksum
SUM_ACT="$(md5sum "$TMP/app.tgz" | awk '{print $1}')"
SUM_FILE="$(tr -d ' \r\n' < "$TMP/manifest.checksum")"
[ "$SUM_FILE" = "$SUM_ACT" ] || fail "manifest.checksum($SUM_FILE) != md5(app.tgz)($SUM_ACT)"
SUM_MF="$(grep '^checksum' "$TMP/manifest" | awk -F'=' '{print $2}' | tr -d ' ')"
[ "$SUM_MF" = "$SUM_ACT" ] || fail "manifest 的 checksum 字段($SUM_MF) != md5(app.tgz)($SUM_ACT)"

# ── 3. 内层结构 ──
tar tzf "$TMP/app.tgz" > "$TMP/inner.list"
FIRST="$(head -1 "$TMP/inner.list")"
case "$FIRST" in
    app|app/*|./*|.|'') fail "内层 app.tgz 首条 '$FIRST' 带 app/ 或 ./ 前缀（装完路径全错位）" ;;
esac
for f in bin/cli-proxy-api config/privilege config/config.default.yaml \
         config/static/management.html ui/config ui/images/icon_64.png ui/images/icon_256.png; do
    grep -qE "^${f}$" "$TMP/inner.list" || fail "内层缺必需条目: $f"
done

# 禁携带 skills/（防御性：任何回灌用户数据目录的形态都拦下）
if grep -qE '^(app/)?skills/' "$TMP/inner.list"; then fail "内层携带 skills/ 目录"; fi

# 禁构建机路径痕迹
if grep -qE 'runner|/home/[a-z]|\.agent-node-work' "$TMP/inner.list"; then fail "内层条目含构建机路径"; fi

# ── 4. 可执行位（cmd/* 与二进制）──
tar tvzf "$FPK" > "$TMP/outer.tv"
BAD="$(grep -E ' cmd/[a-z_]+$' "$TMP/outer.tv" | awk '$1 !~ /^-rwx/ {print $NF}' || true)"
[ -z "$BAD" ] || fail "cmd/* 缺可执行位: $BAD"

tar xzf "$TMP/app.tgz" -C "$TMP" bin/cli-proxy-api config/static/management.html
[ -x "$TMP/bin/cli-proxy-api" ] || fail "bin/cli-proxy-api 无执行位"

# ── 5. 内容自检：二进制版本串 + 面板大小 + 版本号格式 ──
CPAPI_VER="$(grep -E '^CLIPROXYAPI_VERSION=' config/upstream/cliproxyapi.env | cut -d= -f2 | tr -d ' ')"
BIN_OUT="$("$TMP/bin/cli-proxy-api" -h 2>&1 | head -3 || true)"
case "$BIN_OUT" in
    *"Version: ${CPAPI_VER}"*) : ;;
    *) fail "二进制自检失败：未找到 Version: ${CPAPI_VER}" ;;
esac

PANEL_SIZE="$(stat -c%s "$TMP/config/static/management.html")"
[ "$PANEL_SIZE" -gt 1000000 ] || fail "管理面板异常小: $PANEL_SIZE 字节"

MF_VER="$(grep '^version' "$TMP/manifest" | awk -F'=' '{print $2}' | tr -d ' ')"
printf '%s' "$MF_VER" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+-[0-9]+$' || fail "manifest version 格式非法: $MF_VER"

# ── 6. manifest 字段完整性 / 身份 / 无重复 ──
DUP="$(awk -F= '/^[a-z_]+[[:space:]]*=/{gsub(/[[:space:]]/,"",$1); print $1}' "$TMP/manifest" | sort | uniq -d)"
[ -z "$DUP" ] || fail "manifest 存在重复字段: $DUP"
for f in appname version display_name platform source maintainer maintainer_url \
         distributor distributor_url desktop_uidir desktop_applaunchname service_port ctl_stop; do
    grep -qE "^${f}[[:space:]]*=" "$TMP/manifest" || fail "manifest 缺必需字段: $f"
done
getf() { grep -E "^$1[[:space:]]*=" "$TMP/manifest" | head -1 | sed 's/.*=[[:space:]]*//' | tr -d '"' | tr -d ' '; }
[ "$(getf appname)" = "cliproxyapi" ] || fail "appname 必须为 cliproxyapi，实际=$(getf appname)"
[ "$(getf maintainer)" = "router-for-me" ] || fail "maintainer(开发者) 必须为上游 router-for-me，实际=$(getf maintainer)"
[ "$(getf distributor)" = "Mickey" ] || fail "distributor(打包者) 必须为 Mickey，实际=$(getf distributor)"
[ "$(getf desktop_applaunchname)" = "cliproxyapi.main" ] || fail "desktop_applaunchname 必须为 cliproxyapi.main"
[ "$(getf service_port)" = "8317" ] || fail "service_port 必须为 8317"

# ── 7. ui/config 形态（protocol 显式、port 与 service_port 一致）──
tar xzf "$TMP/app.tgz" -C "$TMP" ui/config 2>/dev/null || true
grep -q '"protocol": "http"' "$TMP/ui/config" || fail "ui/config 的 protocol 未显式声明 http"
grep -q '"port": "8317"' "$TMP/ui/config" || fail "ui/config 的 port 与 service_port(8317) 不一致"

# ── 8. cmd/main 守护（TRIM 解析 + 路径锚定 pkill）──
tar xzf "$FPK" -C "$TMP" cmd/main
grep -q '_resolve_trim_paths' "$TMP/cmd/main" || fail "cmd/main 缺 TRIM 路径解析"
grep -qE 'pkill -f "\$BIN"' "$TMP/cmd/main" || fail "cmd/main 的 pkill 未路径锚定（需 pkill -f \"\$BIN\"）"

echo "✅ 全部门禁通过: $FPK"
