# CLIProxyAPI for fnOS (飞牛 NAS)

跟随上游 [router-for-me/CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) 自动构建的
fnOS FPK 安装包。把 Gemini CLI / Antigravity / Codex / Claude Code 等 CLI 账号的订阅额度，
转换成 OpenAI / Gemini / Claude 兼容的 API 接口，自带 Web 管理面板。

## 特性

- **跟随上游**：`auto-update.yml` 长驻轮询上游 release（主程序 + 管理面板双上游），
  有新版本自动 bump 版本号并触发构建，全链路无人工断点。
- **供应链校验**：上游产物 sha256 固定进 `config/upstream/*.env`（版本控制内），
  构建期逐字比对，防上游事后替换同版本资产。
- **管理面板内置**：预置上游官方管理面板（单文件 management.html），
  首次打开即可用，且运行期支持面板自更新。
- **数据持久**：配置、账号凭据、面板均存放于应用数据目录，升级不丢失。

## 版本号规则

`<上游版本>-<封装迭代号>`，如 `8.0.28-1`。上游主版本变化时迭代号归 1，
仅封装/面板变化时迭代号 +1。

## 本地构建

```bash
bash scripts/build-fpk.sh dist
bash scripts/verify-fpk-gates.sh dist/cliproxyapi-<版本>.fpk
```

## 发布

- 稳定版：tag `v<版本>`（如 `v8.0.28-1`），附件 `cliproxyapi-<版本>.fpk`；
- 滚动版：tag `latest`（prerelease），附件 `cliproxyapi.fpk`。

## 安装

飞牛应用中心 → 手动安装 → 选择 fpk。默认端口 8317，
管理面板 `http://<NAS-IP>:8317/management.html`。

## 开发者 / 打包者

- 开发者（上游）：router-for-me
- 打包者：Mickey（本 fork，[mickeyttsc/cliproxyapi-fpk](https://github.com/mickeyttsc/cliproxyapi-fpk)）
