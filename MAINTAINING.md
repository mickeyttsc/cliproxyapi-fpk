# cliproxyapi-fpk · 维护文档

> 面向维护者（构建 / 发布 / 门禁）。用户向说明见 [README.md](README.md)。

## 版本号规则

`<上游版本>-<封装迭代号>`，如 `8.0.29-2`。上游主版本变化时迭代号归 1；仅封装 / 面板变化时迭代号 +1。

## 双上游与校验锚点

- 主程序：[router-for-me/CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) → `config/upstream/cliproxyapi.env`（版本 + sha256，由 auto-update 自动更新）
- 管理面板：Cli-Proxy-API-Management-Center → `config/upstream/cpamc.env`
- `auto-update.yml` 定时巡检双上游；有新版本自动 bump 并触发 `build.yml`，全链路无人工断点。

## 本地构建与验证

```bash
bash scripts/build-fpk.sh dist
bash scripts/verify-fpk-gates.sh dist/cliproxyapi-<版本>.fpk
python3 scripts/validate-gh-workflows.py .github/workflows   # 改 workflow 后先跑
```

## 发布

- 稳定版：tag `v<版本>`（如 `v8.0.29-2`），附件 `cliproxyapi-<版本>.fpk`
- 滚动版：tag `latest`（prerelease），附件 `cliproxyapi.fpk`

## 开发者 / 打包者

- 开发者（上游）：router-for-me（管理面板见其上游仓库）
- 打包者：Mickey（[mickeyttsc/cliproxyapi-fpk](https://github.com/mickeyttsc/cliproxyapi-fpk)）
