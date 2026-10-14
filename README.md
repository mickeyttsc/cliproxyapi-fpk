# cliproxyapi-fpk

飞牛 fnOS 上的 **CLIProxyAPI** 安装包（FPK）。自动跟随上游
[router-for-me/CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) 构建。

把 Gemini CLI / Antigravity / Codex / Claude Code 等 CLI 账号的订阅额度，
包装成 OpenAI / Gemini / Claude 兼容的 API 接口，自带 Web 管理面板。

## 包信息

| 项 | 值 |
|---|---|
| 包名（appname） | `cliproxyapi`（技术标识，勿改） |
| 显示名 | CLIProxyAPI |
| 服务端口 | `8317`（面板：`http://<NAS-IP>:8317/management.html`） |
| 上游主程序 | [router-for-me/CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI)（MIT） |
| 管理面板 | Cli-Proxy-API-Management-Center（内置单文件版，支持面板自更新） |
| 产物文件名 | `cliproxyapi-<版本>.fpk`（如 `cliproxyapi-8.0.29-2.fpk`） |

## 本包改动（相对上游原版）

- **fnOS FPK 封装**：安装 / 升级 / 卸载 / 配置全生命周期（应用中心一键装）。
- **管理面板内置**：预置官方管理面板，首次打开即可用，运行期支持面板自更新。
- **数据持久**：配置、账号凭据与面板存放于应用数据目录，升级 / 重装不丢。
- **自动跟随双上游**：主程序 + 管理面板定时巡检，有新版本自动 bump + 构建发版。
- **供应链校验**：上游产物 sha256 固定进 `config/upstream/*.env`，构建期逐字比对。
- **敏感信息门禁**：仓库扫描脚本 + CI 门禁，防止凭据进库。

## 下载与安装

- 滚动最新版：<https://github.com/mickeyttsc/cliproxyapi-fpk/releases/download/latest/cliproxyapi.fpk>
- 固定版本：见 [Releases](https://github.com/mickeyttsc/cliproxyapi-fpk/releases) 页附件（`cliproxyapi-<版本>.fpk`）
- 安装：飞牛应用中心 → 手动安装 → 选择 fpk；装后打开 `http://<NAS-IP>:8317/management.html` 添加账号。

## 维护

构建链路、版本号规则与门禁：[MAINTAINING.md](MAINTAINING.md)

## 许可证

上游主程序为 **MIT**（管理面板许可见其上游仓库）。本仓库仅作 fnOS 打包分发。
