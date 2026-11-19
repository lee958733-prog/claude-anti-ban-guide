#!/usr/bin/env bash
# ============================================================
# harden.sh — VPS 部署后安全加固脚本
# 适用: Ubuntu 24.04 + 3x-ui(小小东方案部署完成后执行)
# 作者仓库: github.com/lee958733-prog/claude-anti-ban-guide
# 用法: sudo bash harden.sh          (在服务器上直接运行)
#       PANEL_PORT=53998 ALLOW_PORTS="22 80 443 2443 2096" sudo bash harden.sh
# 幂等: 重复执行安全,已完成的项会跳过
# ============================================================
set -euo pipefail

PANEL_PORT="${PANEL_PORT:-53998}"
ALLOW_PORTS="${ALLOW_PORTS:-22 80 443 2443 2096}"   # 22=SSH 80/443/2443=节点与证书 2096=订阅规则
XUI_DB="/etc/x-ui/x-ui.db"

step(){ echo -e "\n\033[1;36m[$1/$TOTAL] $2\033[0m"; }
ok(){ echo "  ✓ $1"; }
TOTAL=7

[ "$(id -u)" -eq 0 ] || { echo "请用 sudo 运行"; exit 1; }
step 1 "系统补丁升级(不重启内核)"
export DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a
apt-get update -qq
apt-get -y -q -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold upgrade >/dev/null
ok "补丁已升级,剩余待升级: $(apt list --upgradable 2>/dev/null | tail -n +2 | wc -l)"

step 2 "安装自动安全更新(unattended-upgrades)"
systemctl is-enabled unattended-upgrades >/dev/null 2>&1 || {
  apt-get install -y -qq unattended-upgrades >/dev/null
  systemctl enable --now unattended-upgrades >/dev/null 2>&1
}
ok "unattended-upgrades: $(systemctl is-enabled unattended-upgrades)"

step 3 "安装 fail2ban(SSH 爆破防护)"
if ! systemctl is-active fail2ban >/dev/null 2>&1; then
  apt-get install -y -qq fail2ban >/dev/null
  printf "[sshd]\nenabled = true\nbackend = systemd\nmaxretry = 5\nbantime = 1h\n" \
    > /etc/fail2ban/jail.d/sshd-local.conf
  systemctl enable --now fail2ban >/dev/null 2>&1
fi
ok "fail2ban: $(systemctl is-active fail2ban) (5次失败封1小时)"

step 4 "3x-ui 面板绑定回环(公网改走 SSH 隧道)"
if [ -f "$XUI_DB" ]; then
  LISTEN=$(python3 -c "
import sqlite3
db = sqlite3.connect('$XUI_DB')
row = db.execute(\"SELECT value FROM settings WHERE key='webListen'\").fetchone()
print(row[0] if row else '')" 2>/dev/null || echo '')
  if [ "$LISTEN" != "127.0.0.1" ]; then
    cp "$XUI_DB" "$XUI_DB.bak.$(date +%s)"
    python3 -c "
import sqlite3
db = sqlite3.connect('$XUI_DB')
db.execute(\"DELETE FROM settings WHERE key='webListen'\")
db.execute(\"INSERT INTO settings (key,value) VALUES ('webListen','127.0.0.1')\")
db.commit()"
    systemctl restart x-ui; sleep 2
  fi
  ss -tlnp | grep -q "127.0.0.1:$PANEL_PORT" && ok "面板仅监听 127.0.0.1:$PANEL_PORT" \
    || { echo "  ! 面板端口 $PANEL_PORT 未按预期监听回环,请人工检查"; }
  cat <<'EOF'
  以后访问面板走 SSH 隧道(客户端 ~/.ssh/config 追加):
      Host vps-panel
          HostName <服务器IP>
          User root
          IdentityFile ~/.ssh/<你的密钥>
          LocalForward PORT 127.0.0.1:PORT
  用法: ssh -N vps-panel 后浏览器开 https://127.0.0.1:PORT/<面板路径>
  (证书警告属正常:证书签给服务器IP而非127.0.0.1,隧道内流量已加密)
EOF
else
  echo "  ! 未找到 $XUI_DB,跳过(非 3x-ui 部署?)"
fi

step 5 "UFW 收敛对外端口"
if command -v ufw >/dev/null; then
  ufw --force reset >/dev/null
  ufw default deny incoming >/dev/null; ufw default allow outgoing >/dev/null
  for p in $ALLOW_PORTS; do ufw allow "$p/tcp" comment 'guide' >/dev/null; done
  ufw --force enable >/dev/null
  ok "仅放行: $ALLOW_PORTS (tcp)"
fi

step 6 "SSH 已是仅密钥(确认,不改动)"
PW=$(sshd -T 2>/dev/null | awk '/^passwordauthentication/{print $2}')
PERMIT=$(sshd -T 2>/dev/null | awk '/^permitrootlogin/{print $2}')
[ "$PW" = "no" ] && ok "PasswordAuthentication no" || echo "  ! 建议关闭 SSH 密码登录"
[ "$PERMIT" = "without-password" ] || [ "$PERMIT" = "prohibit-password" ] \
  && ok "PermitRootLogin 仅密钥" || echo "  ! 建议将 root 登录设为仅密钥"

step 7 "收尾自检"
echo "  服务: x-ui=$(systemctl is-active x-ui 2>/dev/null || echo 无) nginx=$(systemctl is-active nginx 2>/dev/null || echo 无)"
echo "  待办(脚本不代做): ① root 密码轮换(开通邮件旧密码作废) ② 商家后台改密码+开自动续费"
echo "  完整验收: 跑 'xxd-vps verify'(面板2项FAIL属预期——面板已回环)"

echo -e "\n\033[1;32m✅ 加固完成。教程: tutorial.md 第七章验收清单\033[0m"
