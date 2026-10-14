#!/usr/bin/env python3
"""探测上游「可打包版本」并输出校验值。

用法:
    python3 scripts/detect-upstream.py cpapi             # 最新 CLIProxyAPI 版本（X.Y.Z）
    python3 scripts/detect-upstream.py cpapi-sha <ver>   # 该版本 linux_amd64 资产 sha256
    python3 scripts/detect-upstream.py cpamc             # 最新管理面板版本（X.Y.Z）
    python3 scripts/detect-upstream.py cpamc-sha <ver>   # 该版本 management.html sha256

设计要点（都是踩过的坑）：
  1. 不能取 releases/latest 了事 —— 要按「非 draft/prerelease + tag 形态 ^vX.Y.Z$ +
     资产存在」过滤后取 published_at 最新，防止预发布/异常 tag 混入。
  2. sha256 优先读 release asset 的 digest 字段（新版 API 提供 sha256:<hex>），
     缺失时回退「下载资产现算」；两条都失败返回空（调用方视为硬失败，跳过本轮）。
  3. 所有 api.github.com 调用必须带 Authorization：runner 出口 IP 全平台共享，
     未鉴权走 60 次/小时 IP 配额，常被耗尽 → 403 → 静默失效。
"""
import hashlib
import json
import os
import re
import sys
import urllib.error
import urllib.request

CPAPI_REPO = "router-for-me/CLIProxyAPI"
CPAMC_REPO = "router-for-me/Cli-Proxy-API-Management-Center"
API = "https://api.github.com"


def _get(url, timeout=60):
    req = urllib.request.Request(url)
    req.add_header("Accept", "application/vnd.github+json")
    req.add_header("User-Agent", "cliproxyapi-fpk-detect")
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if token:
        req.add_header("Authorization", "token %s" % token)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read().decode("utf-8", "replace")


def _download_sha256(url, timeout=900):
    req = urllib.request.Request(url)
    req.add_header("User-Agent", "cliproxyapi-fpk-detect")
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if token and "github.com" in url:
        req.add_header("Authorization", "token %s" % token)
    h = hashlib.sha256()
    with urllib.request.urlopen(req, timeout=timeout) as r:
        while True:
            chunk = r.read(1 << 20)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()


def _latest_with_asset(repo, asset_for):
    """返回最新「带指定资产」的稳定版本号（无 v 前缀）。"""
    data = json.loads(_get("%s/repos/%s/releases?per_page=30" % (API, repo)))
    cands = []
    for r in data:
        if r.get("prerelease") or r.get("draft"):
            continue
        m = re.match(r"^v(\d+\.\d+\.\d+)$", r.get("tag_name", ""))
        if not m:
            continue
        ver = m.group(1)
        names = [a.get("name", "") for a in r.get("assets", [])]
        if asset_for(ver) in names:
            cands.append((r.get("published_at") or "", ver))
    if not cands:
        return ""
    cands.sort(reverse=True)
    return cands[0][1]


def _asset_sha(repo, ver, asset_name):
    d = json.loads(_get("%s/repos/%s/releases/tags/v%s" % (API, repo, ver)))
    for a in d.get("assets", []):
        if a.get("name") == asset_name:
            dg = (a.get("digest") or "").replace("sha256:", "")
            if re.fullmatch(r"[0-9a-f]{64}", dg):
                return dg
            # 回退：下载资产现算（digest 缺失才会走到，代价可接受）
            return _download_sha256(a["browser_download_url"])
    return ""


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    cmd = sys.argv[1]
    if cmd == "cpapi":
        v = _latest_with_asset(CPAPI_REPO, lambda ver: "CLIProxyAPI_%s_linux_amd64.tar.gz" % ver)
        if not v:
            print("未能解析出可打包的 CLIProxyAPI 版本", file=sys.stderr)
            return 1
        print(v)
    elif cmd == "cpamc":
        v = _latest_with_asset(CPAMC_REPO, lambda ver: "management.html")
        if not v:
            print("未能解析出可打包的管理面板版本", file=sys.stderr)
            return 1
        print(v)
    elif cmd == "cpapi-sha":
        if len(sys.argv) < 3:
            return 2
        s = _asset_sha(CPAPI_REPO, sys.argv[2], "CLIProxyAPI_%s_linux_amd64.tar.gz" % sys.argv[2])
        if not s:
            print("未能获取 sha256", file=sys.stderr)
            return 1
        print(s)
    elif cmd == "cpamc-sha":
        if len(sys.argv) < 3:
            return 2
        s = _asset_sha(CPAMC_REPO, sys.argv[2], "management.html")
        if not s:
            print("未能获取 sha256", file=sys.stderr)
            return 1
        print(s)
    else:
        print("未知子命令: %s" % cmd, file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
