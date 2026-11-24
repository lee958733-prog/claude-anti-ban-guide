# Claude 安全使用指南（搭建 · 加固 · 防封）

> 从零搭建一套自建 VPS + 全链路防护的 Claude 使用环境：服务器部署、客户端审计、指纹伪装、账号养护、**内容层污染管理**——比常见教程多出"防守与纪律"的完整闭环。

## 这份方案和其他防封教程的区别

大多数教程止步于"把代理搭起来"。本仓库在三件事上更进一步（均来自 2026-11 实战验证）：

| 层 | 常见教程 | 本方案 |
|---|---|---|
| 服务器 | 部署完就结束 | 部署后 6 项超基线加固（面板回环 + SSH 隧道、自动安全更新、fail2ban、UFW 收敛、root 轮换） |
| 客户端 | 装个代理客户端 | TUN 物理接管 + 14 项 Fail-Closed 审计 + 10 秒 Kill-Switch 巡检 |
| **内容层** | **没人讲** | **污染面管理**：会话内容也会构成风控画像，附四层巡检命令与误报甄别 |

## 快速开始（三步）

1. **搭服务器**：按上游方案 [xiaoxiaodong-vps](https://github.com/nevertoday/xiaoxiaodong-vps) 部署一台属于你自己的 VPS（推荐 [搬瓦工 洛杉矶 CN2 GIA](https://bandwagonhost.com/aff.php?aff=85933)，2G 内存，1T 套餐缺货就选 2T；下单选不了系统就开通后在 KiwiVM 重装 Ubuntu 24.04）
2. **跑加固**：部署完成后在服务器上执行本仓库的 `harden.sh`（补丁 + 面板回环 + 防火墙 + 自动安全更新）
3. **照教程验收**：打开 [tutorial.md](tutorial.md) 按第六章验收清单逐项打勾（含 14 项审计、WebRTC 出口、IP 信任评分 ≥70）

不会配置？把仓库根目录的 `AGENTS.md` 整段粘贴给本地的 AI 编程助手（GLM / Kimi / Codex 均可），它会按文档完成部署检查、加固与验收。

## 仓库内容

- `tutorial.md` —— 完整教程：心法 / 服务器 / 客户端防护 / 指纹伪装 / 账号支付 / 污染面管理 / 验收清单 / 血泪坑速查表
- `harden.sh` —— 服务器部署后加固脚本（Ubuntu 24.04 + 3x-ui）
- `AGENTS.md` —— AI 代部署/代运维交接提示词
- `docs/index.html` —— 教程网页版（单文件、可离线分发）

## 致谢与上游

- 部署基座来自 [@小小东](https://github.com/nevertoday/xiaoxiaodong-vps)（MIT），本仓库在其之上叠加安全加固与内容层方法论
- 环境审计工具 [claude-switcher](https://github.com/YOURSJEYO/claude-switcher)（2026-11-02 后新版 AGPL-3.0，早期 MIT）
- 检测工具：[ip.net.coffee/claude](https://ip.net.coffee/claude)、[fuck-claude.com](https://fuck-claude.com)

## 声明

- 仅供学习与个人使用，请遵守当地法律及各平台服务条款；由此产生的一切后果与作者无关
- 文中搬瓦工链接为推广链接（aff），不影响价格
- 风控机制持续演进，教程基于 2026-11 时点的公开信息与实战经验，不构成任何保证

## License

MIT — 保留上游项目版权声明
