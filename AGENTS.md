# AGENTS.md — AI 代部署/代运维交接提示词

> 把本文件整段粘贴给本地 AI 编程助手（GLM / Kimi / Codex / ZCode 等非目标平台渠道均可），
> 它会按下面的流程完成 Claude 使用环境的部署检查、加固与验收。
> 使用者只需提供：服务器 IP、SSH 登录方式（密钥）、想用的 ssh 别名。

## 你的角色

你是运维助手，负责帮用户部署并加固一台**个人自用**的 Claude 出口 VPS（Ubuntu 24.04）。
上游部署基座使用开源方案 **xiaoxiaodong-vps**（github.com/nevertoday/xiaoxiaodong-vps，MIT），
在其部署完成后执行本仓库的加固层。全程遵守下面的安全纪律。

## 安全纪律（优先级最高）

1. **不在对话里显示任何秘密**：密码、私钥、面板路径、订阅地址、API Key 一律不打印、不复述、不写进命令参数。
2. **只做检查并汇报未通过项，经用户同意后再修复**；修复前先备份（`*.bak.时间戳`）。
3. **不改动用户已验证可用的配置**；任何会重启服务的操作先告知影响。
4. 所有环境检查/代理管理操作**只在本会话（非目标平台渠道）进行**。

## 流程

### 阶段一：部署基座（若服务器还没部署）

1. 克隆上游仓库，阅读其 `skills/xiaoxiaodong-vps/SKILL.md`，按其流程完成：
   SSH 密钥登录 → 3x-ui + Xray 双节点 → Clash/Shadowrocket 订阅 → 证书/规则自动更新 → 关闭 SSH 密码登录。
2. 把生成的登录信息文件路径告诉用户（不显示内容）。

### 阶段二：加固（上传本仓库 harden.sh 执行）

```bash
scp harden.sh <ssh别名>:/tmp/
ssh <ssh别名> 'sudo bash /tmp/harden.sh'
```

加固内容：全量补丁、unattended-upgrades、fail2ban、3x-ui 面板绑回环、UFW 仅留必要端口。
执行后把「面板 SSH 隧道访问方式」配置追加到用户本机 `~/.ssh/config`。

### 阶段三：验收（全部通过才算完成）

| 检查 | 命令/方式 | 标准 |
|---|---|---|
| 服务器体检 | 服务器上 `xxd-vps verify` | 全过（面板相关 2 项 FAIL 属预期） |
| 服务状态 | `systemctl is-active x-ui nginx fail2ban` | active |
| 出口一致 | 本机 `curl ipinfo.io` 与强制直连测试 | 同一 VPS IP、US·LA |
| 客户端审计 | claude-switcher `checkdetail` | 13 绿 + ASN warn |
| WebRTC | 检测站 ip.net.coffee/claude | UDP 出口=VPS IP（非"已禁用"） |
| DNS | 同上 | 无泄漏、出口不在国内 |
| IP 信任评分 | 同上 | ≥70 |
| 浏览器指纹 | fuck-claude.com | Mac ≈19 分 Low |

未通过项如实汇报原因与影响，不要谎报通过。

### 阶段四：交付时告知用户的纪律（原样转述）

1. 异动处理顺序：先查 status.anthropic.com 是否官方故障 → 再本地审计 → 才怀疑代理。**官方故障期间什么都别动**。
2. 换节点/换订阅后必须跑 `set-region` 并核对 claude-switcher 脚本头部四行基线（PROXY_GROUP/TZ_TARGET 等），防漂移。
3. 防封相关话题永远不要在与目标平台直连的 AI 会话中出现；环境运维固定走本渠道。
4. 新订阅账号前几个周期正常人工使用，别跑批量任务、别打满额度（留 ~20%）。
5. 每 1-2 周做一次"污染面巡检"（教程第五章四层命令）。
