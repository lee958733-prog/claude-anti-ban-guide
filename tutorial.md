# Claude 防封完全教程 —— 从零搭建到细节验收

> 基于 2026-11 实战搭建全程整理（Mac 实测 · Windows 同样适用 · 自建 VPS 方案）

---

## 使用说明（动手前先读 30 秒）

**先通读全文，再动手。** 本教程的坑大多不是"操作难"，而是"不知道纪律"——时区被脚本改错、Cookie 误清导致登出、会话内容污染画像，全是不知道规则造成的返工。通读一遍 30 分钟，省掉几小时踩坑。

**执行路线**（章节顺序就是动手顺序）：

```
通读全文
 → 第一章 服务器（采购 + 部署 + 加固）
 → 第二章 客户端防护（TUN + 14 项审计）
 → 第三章 指纹伪装（时区 / 语言 / 浏览器）
 → ✅ 半程验收：第六章第 1-7 项（无需账号即可测）
 → 第四章 注册 Gmail / Claude + 订阅 Pro
 → ✅ 终验收：第六章第 8-9 项
 → 日常：第七章运维纪律 + 第五章污染巡检
```

两条特别提醒：
- **第四章必须等环境全部就绪再执行**——注册那一刻的环境就是账号的"出生画像"，出生地错了后面全错
- **第五章不是进阶篇**——污染纪律从你第一次打开 Claude Code 起就生效，不是"以后再看"的章节

---

## 心法：三条铁律（先读这个，再看操作）

1. **防御不建立在"记得"上，建立在物理约束上**——TUN 接管、Kill-Switch、Fail-Closed 审计，让人失误了也漏不出去
2. **一致性 > 真实性**——风控看的是信号自洽（IP↔时区↔语言↔支付），不是"你真的是谁"
3. **内容污染是最大暗坑**——工具保网络层，对话内容保画像层；防封话题永远不出现在 Claude 的任何会话里（用非 Anthropic 渠道的 AI 做运维）

---

## 第一章 服务器层：自建独享 VPS（小小东方案）

### 1.1 采购原则
- **服务商**：[搬瓦工 BandwagonHost（点击注册）](https://bandwagonhost.com/aff.php?aff=85933)（推广链接，不影响价格）或 DMIT，选 **洛杉矶 CN2 GIA** 线路（对国内优化、敏感期稳定）
- **配置**：2G 内存 / 每月 1-2T 流量足够（本例：Ubuntu 24.04，38G 盘）
- **独享是底线**：一台服务器只服务自己和家人。共享 = 蒸馏厂画像（大量账号从同一 IP 抽取模型数据的样子）= 必封

### 1.2 部署（用 AI 代跑）
小小东方案的核心思想：把部署提示词交给**非 Claude 的 AI**（Codex/Kimi/GLM 均可），它通过 SSH 自动完成：
- 3x-ui 面板 + Xray（VLESS Reality 443 + TLS 2443 双节点，主备自动切换）
- Clash / Shadowrocket 双订阅 + AI 域名分流规则（每日自动更新）
- Let's Encrypt 证书自动续期、配置每日自动备份（保留 7 份）
- SSH 装好即关闭密码登录，仅密钥

### 1.3 部署后立刻做的安全加固（超出默认基线的部分）
> 以下端口（面板 53998、节点 2443、订阅 2096）都是**本教程实测环境的例子**——你的实际端口以部署完成后生成的登录信息文件为准；22/80/443 是固定的。跑本仓库的 `harden.sh` 可自动完成本节全部操作。

```
□ apt 全量补丁升级 + 安装 unattended-upgrades（自动安全更新，默认没有！）
□ 3x-ui 面板改绑 127.0.0.1，公网访问改为 SSH 隧道：
    Host vps-panel
        HostName <你的VPS IP>
        User root
        IdentityFile ~/.ssh/<你的密钥>
        LocalForward <面板端口> 127.0.0.1:<面板端口>
    # 用法：ssh -N vps-panel 后浏览器开 https://127.0.0.1:<面板端口>/<面板路径>
□ UFW 只留 22/80/443 + 你的节点端口 + 订阅端口，面板端口和无关端口全关
□ 装 fail2ban（SSH 爆破防护）
□ root 密码轮换（开通邮件里的旧密码作废），新密码存 macOS 钥匙串
□ 商家后台开自动续费（到期=停机=IP回收=全套归零）
□ 商家后台登录密码单独改强密码（和 root 密码是两回事）
```

### 1.4 服务器自检
方案自带验收命令：`xxd-vps verify`（在服务器上直接跑），33 项全查。
> 若做了"面板绑回环"加固，面板相关的 2 项会显示 FAIL——这是预期偏离，不是故障，别"修复"回公网监听。

---

## 第二章 客户端防护层：让真实 IP 物理出不去

### 2.1 Clash Verge（TUN 模式是灵魂）
- **必须开 TUN（虚拟网卡）**，不能只开系统代理——系统代理管不住 WebRTC/UDP/不走代理设置的程序
- 验证标准：**强制直连的流量也被 TUN 抓走**（`curl --noproxy '*' ipinfo.io` 返回的仍是 VPS IP）
- DNS：fake-ip 模式（域名解析到 198.18.x.x 假段 = 劫持生效的标志）
- mihomo 外部控制器可关闭（unix socket 仍可用于审计）

### 2.2 claude-switcher：14 项审计 + Kill-Switch
从 [claude-switcher](https://github.com/YOURSJEYO/claude-switcher) 仓库安装。装完后每次启动 Claude 前跑 `checkdetail`（下文所有 `claude-switch.sh <子命令>` 的路径以你的实际安装位置为准），14 项审计：
```
代理内核 / TUN网卡 / 出口IP / IP一致 / 时区 / 地区 / IPv6 / DNS /
WebRTC / 保镖 / 规则置顶 / 客户端语言 / ASN属性 / 生态可达性
```
关键配置（脚本头部，换节点/换订阅后必查）：
```bash
PROXY_GROUP="<订阅里的代理组名>"   # 换订阅必改！
COUNTRY_TARGET="US"
TZ_TARGET="America/Los_Angeles"    # 必须与出口城市一致
LOCALE_TARGET="en_US"
```

**⚠️ 最大的坑：set-region 会漂移**。当 ipinfo 查询失败时它会回退到国家默认值（如 New_York），之后跑 `fix` 会把你的系统时区**改错**，制造时区-IP 冲突指纹。纪律：**换节点后跑 set-region，然后立刻核对脚本头部四行基线**。

### 2.3 WebRTC 策略：选 proxy 不选 reject
- ~~reject（默认）~~：STUN 全拒，检测站显示"已禁用"——安全但"禁用 WebRTC"本身是异常指纹
- **proxy（推荐，小小东标准）**：置顶规则把 STUN UDP (3478/5349/19302) 路由到代理组
  ```bash
  echo 'proxy' > ~/.claude-switcher/webrtc-policy && claude-switch.sh fix
  ```
- 验收：检测站 WebRTC UDP 出口 = **你的 VPS IP**（不是"已禁用"）

### 2.4 Kill-Switch 保镖（每 10 秒巡检）
代理内核或 TUN 一挂，10 秒内自动杀掉 Claude 桌面版 + CLI——杜绝"代理断了 Claude 还在裸连重试"的窗口。装好后确认待命（macOS）：`launchctl print system/local.claude-bodyguard`；Windows 版是系统服务，见 claude-switcher 仓库 `windows/` 目录。

---

## 第三章 环境伪装细节（指纹层）

### 3.1 系统四件套
```
时区     = 服务器城市（如 America/Los_Angeles）
Locale   = en_US
系统语言 = 仅 en-US（第二语言带 zh 会漏进浏览器 Accept-Language）
定位服务 = 关闭
```
改语言（macOS）：`defaults write .GlobalPreferences AppleLanguages -array "en-US"`（中文输入法不受影响）；Windows：设置 → 时间和语言 → 语言，只保留 English。

### 3.2 浏览器
- Chrome 设置 → 语言：**只留 English**（navigator.languages 不能出现 zh）
- 预期地板分：fuck-claude.com 评分 **Mac 实测 19/100 = Low**（剩余 18 分是系统全球预装的中文字体——Windows 同理，微软雅黑也是预装的，结构性无法去除，也构不成信号）
- 用独立浏览器 profile 做防封操作，日常浏览和操作分离

### 3.3 DNS
- 系统手动 DNS 设 1.1.1.1 / 8.8.8.8（中性），不要用国内 DNS
- 注意：某些国产软件的守护进程（如远程加速类）会在 10 秒内把活动网卡 DNS 改回 114——**被 TUN 劫持的情况下无害**，别浪费时间去反复改，要么忍，要么卸载该软件

### 3.4 已知检测机制（逆向报告结论）
严格的 "China user" 检查**只在非官方端点（ANTHROPIC_BASE_URL 反代）场景触发**，读 OS 时区 + 代理主机名。走官方登录 + 时区正确 = 主干全绿。**绝对不要用反代/套壳接 Claude**。

---

## 第四章 账号注册与订阅（保姆级）

### 4.1 注册 Gmail
- **时机**：整套环境（VPS + TUN + 时区/语言）**验收通过后**再注册——注册那一刻的出口 IP 决定账号的初始归属地（实测教训：在非美国出口下注册的号，归属地会跟着出口走，事后要多走一道官方变更流程）
- 资料：姓名拼音、生日 ≥18 岁且今后保持一致；手机验证能跳过就跳过，跳不过说明该出口/设备正被风控，换个时间再试
- 注册后自检：pay.google.com → 设置 → 付款资料国家应为 United States；不是就用官方表单改（policies.google.com/country-association-form），**改完一年内别再动**

### 4.2 注册 Claude 账号
- claude.ai → Continue with Google，用上面的 Gmail 登录
- 首次设置：**不同意 AI 训练数据使用**、**关闭位置共享**
- 可先在免费档正常用几天给账号热身（可选但推荐）

### 4.3 购买 Pro 会员
- **订阅前三查**：Gmail 归属地 = US ✓ 出口 IP = US ✓ 结账货币 = USD ✓——任何一项不对就先停
- 入口：claude.ai → Settings → Plans（或 Google Play 内订阅，区域跟随 Google 账号，同样以 USD 结算）
- 支付：自己的外币信用卡（参考小小东方案：Google Pay + 国内银行 Visa）；**绝不代充**——支付人与账号不一致本身就是风控信号
- 首笔 USD 账单 = 账号"美国付费用户"的第一笔画像，一致性从此闭环

### 4.4 已有账号的补救
- 归属不对：官方表单改（见 4.1），务必在**订阅之前**改好
- 支付原则：资金来源自己掌控，不经过他人之手（代充/合租/共享号都是高危信号）

### 4.5 新号节奏（前三~五个 5 小时窗口）
- 正常人工使用，英文专业性话题开几个新对话
- ❌ 不跑批量/自动化/无人值守任务、不打满额度（每周期留 ~20%）
- ✅ "重度"的定义是行为模式不是用量：人盯着的 8 小时 < 无人值守的 2 小时

### 4.6 设备登录记录
- 全部显示同一城市 = 健康（不同 GeoIP 库对机房 IP 的城市标注可能不同，国家一致才是关键）；CLI 显示 Unknown 正常
- **不要频繁登出/登入设备**——每次都是新的认证事件

### 4.7 手机端
- 最稳是"只用电脑版"；要用手机就必须常开代理（Shadowrocket 导入专用订阅），绝不在裸联网环境下打开 Claude

---

## 第五章 污染面管理（外面教程不写的部分）

### 5.1 核心认知
Claude Code **每次请求都会上传**：会话内容 + `~/.claude/CLAUDE.md` + `settings.json`。它能看到你让它看的本地文件。所以防封不只是网络层——**你在 Claude 面前聊过什么，就是你的画像**。

### 5.2 铁律执行
- ❌ 永远不在 Claude Code 会话里出现：防封/代理/clash/VPS/节点/封号/切换器……
- ✅ 这类运维全部走非 Anthropic 的 AI 渠道（GLM/Kimi/Codex 均可）

### 5.3 定期巡检（每 1-2 周一次，四层）
> 以下命令在终端（Terminal / PowerShell）里执行。**先把 `<你的VPS IP>` 替换成你自己服务器的 IP**，其余部分可原样复制粘贴。命令 2 需要先装 jq（macOS：`brew install jq`；Windows：`winget install jqlang.jq`；不想装就跳过这条，用命令 1、3 也能覆盖大头）。

```bash
# 1.会话记录（注意甄别误报：官方文档里的 "kill switch"、其他平台话题、base64 巧合）
grep -rliE 'claude-switcher|mihomo|保镖|搬瓦工|bwg-|<你的VPS IP>' ~/.claude/projects

# 2.prompt 历史（需 jq）
jq -r '.projects | to_entries[].value.history // [] | .[]' ~/.claude.json | grep -cE '防封|clash|代理'

# 3.每请求上传的两个文件
grep -cE '防封|clash|switcher|代理' ~/.claude/CLAUDE.md ~/.claude/settings.json

# 4.切换 API 中转的残留（换回官方后必查）
grep -r 'ANTHROPIC_BASE_URL\|bigmodel\|zhipu' ~/.claude/settings.json ~/.claude.json ~/.zshrc
```
命中就删会话文件；反代时代的旧配置备份（含明文 Key）直接销毁，Key 在服务商后台作废。

### 5.4 浏览器痕迹
做了检测/面板操作后，按域清理历史、搜索词、下载记录（清 Cookie 会登出触发重新登录——**不要清 Cookie**，只清无登录价值的检测站域名）。

### 5.5 环境整洁
旧订阅 yaml、迁移包、安装镜像、含敏感内容的参考文件——用完即删。桌面和下载目录定期清空。

---

## 第六章 验收清单（全部达标才算完）

| # | 项目 | 标准 |
|---|---|---|
| 1 | 14 项审计 | `claude-switch.sh checkdetail` 13 绿 + ASN warn（机房 IP 是方案固有）|
| 2 | 出口一致性 | ipinfo 显示 VPS / 与服务器所在地一致，强制直连测试同样走 VPS |
| 3 | WebRTC | 检测站 UDP 出口 = VPS IP（不是"已禁用"）|
| 4 | DNS | 无泄漏，出口不在国内 |
| 5 | 浏览器指纹 | fuck-claude.com ≈ 19 分（系统预装中文字体构成的地板分）|
| 6 | **IP 信任评分** | **ip.net.coffee/claude ≥ 70**（机房 IP 的现实区间 70-80）|
| 7 | 服务器体检 | `xxd-vps verify` 全过（面板加固导致的 2 项 FAIL 除外）|
| 8 | 登录记录 | 全设备同一地区、无 Unknown 以外的异常 |
| 9 | 污染巡检 | 四层全零命中 |

---

## 第七章 日常运维

- **异动处理顺序（刻在脑子里）**：① status.anthropic.com 看官方是否故障 → ② 本地 `checkdetail` → ③ 才轮到怀疑代理。**官方故障期间什么都别动**
- **换节点/换订阅后**：跑 `set-region` + 核对脚本基线四行
- **感觉服务器不对**：跑 `xxd-vps verify`
- 用完 Claude 就退出是好习惯，但**挂着不是风险，持续跑任务才是**
- 长期固定一个出口，绝不在多国节点间跳

## 附录：血泪坑速查表

| 坑 | 症状 | 解 |
|---|---|---|
| set-region 漂移 | 时区被 fix 改成纽约 | 改回脚本头部 TZ_TARGET，跑 fix |
| 换订阅没改基线 | WebRTC/规则置顶 fail | PROXY_GROUP 改成新组名 |
| DNS 被改回 114 | 10 秒内复发 | 国产远程软件守护，TUN 下无害，忍或卸载 |
| 在 Claude 里聊防封 | 会话文件大量命中 | 删文件 + 永不再犯（已上传的撤不回）|
| 清了 Cookie | 被登出 | 别清 Cookie！按域清历史即可 |
| 官方小故障 | 网页慢/报错 | 不动任何配置，等恢复 |
| 面板打不开 | 53998 拒绝连接 | 面板已绑回环，走 `ssh -N vps-panel` 隧道 |

---

*教程完。核心一句：工具保物理层，纪律保内容层，一致性保画像层——三层齐备，安心使用。*

> 基座方案：[xiaoxiaodong-vps](https://github.com/nevertoday/xiaoxiaodong-vps)（MIT）· 审计工具：[claude-switcher](https://github.com/YOURSJEYO/claude-switcher) · 资源汇总：@Web300fa
