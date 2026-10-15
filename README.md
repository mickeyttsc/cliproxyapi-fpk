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

## 常用使用说明

### 首次登录

- 管理面板：`http://<NAS-IP>:8317/management.html`，默认管理密钥 `password`，**登录后请立即修改**。
- 客户端接口：`http://<NAS-IP>:8317/v1`（OpenAI / Gemini / Claude 兼容），密钥在面板「API 密钥管理」中查看或修改。
- 安装信息（入口 / 密钥 / OAuth 登录方式）也写在应用数据目录的 `access-info.txt` 里。

### 客户端接入示例（Codex 等使用 Responses API 的工具）

代理原生支持 `/v1/responses`，在 `~/.codex/config.toml` 中：

```toml
model = "gemini-3-flash"          # 模型以面板 /v1/models 列表为准
model_provider = "cliproxy"

[model_providers.cliproxy]
name = "CLIProxyAPI"
base_url = "http://<NAS-IP>:8317/v1"
env_key = "CLIPROXY_API_KEY"      # export 为面板里的客户端密钥
wire_api = "responses"
```

### 数据与升级

- 配置、账号凭据、面板都存放在应用数据目录（fnOS 的 `@appdata/cliproxyapi/`，实际卷号以应用管理页为准）。
- 升级 / 重装**不会覆盖**已有配置与已登录账号；端口、密钥保持不变。

### 遇到 429 报错怎么办

上游（如 Antigravity）的 429 有两种，处理方式不同：

| 类型 | 特征 | 处理 |
|---|---|---|
| **风控假 429** | 配额没用完，系统提示词含某些指纹词组合即触发（`RESOURCE_EXHAUSTED`，与真实配额无关） | 见下「敏感词混淆」 |
| **真 429** | 免费额度真的用完了（面板「配额管理」页可见） | 等额度重置或换凭据，加词无效 |

判断顺序：先看面板「配额管理」→ 额度还有剩余却报 429 → 大概率是风控假 429 → 去日志页找出请求里带的触发词 → 加进词表。

### 敏感词混淆（风控假 429 的解法）

代理在转发前会用零宽字符把词表里的词切开：模型读到的语义不变，上游风控正则失配。**面板位置**：

> 控制栏 → **配置面板** → 顶部 tab **高级与实验** → 展开 **OAuth 提供商行为 → 插件 → Antigravity** → **敏感词混淆**
> （也可在配置面板顶部搜索框输入 `sensitive` 一键定位）

- 每项一个词或短语，匹配不区分大小写，保存即生效（配置热加载，无需重启）。
- 本包默认模板已内置启用两个通用指纹词（见 `app/config/config.default.yaml`），全新安装开箱即免疫已知指纹；已安装用户升级不受影响。
- 同机制还有 Devin 通道（`oauth.providers.devin.sensitive-words`），用法相同。
- 词表是可维护的：上游换了新指纹词，在此处追加即可。若某天风控不再基于关键词，需等待上游 CLIProxyAPI 更新对抗手段。

## 维护

构建链路、版本号规则与门禁：[MAINTAINING.md](MAINTAINING.md)

## 许可证

上游主程序为 **MIT**（管理面板许可见其上游仓库）。本仓库仅作 fnOS 打包分发。
