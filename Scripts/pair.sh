#!/bin/bash
# Pulse Watch — OpenClaw 配对二维码生成器
# 用法: ./Scripts/pair.sh [--agent AGENT_ID]
#
# 读取本机 OpenClaw gateway 配置，生成 QR Code，app 扫码即连

set -e

AGENT_ID="openclaw:main"
PORT=18789

while [[ $# -gt 0 ]]; do
    case $1 in
        --agent) AGENT_ID="$2"; shift 2 ;;
        --port) PORT="$2"; shift 2 ;;
        -h|--help)
            echo "用法: $0 [--agent AGENT_ID] [--port PORT]"
            echo "  --agent  Agent ID (默认: openclaw:main)"
            echo "  --port   Gateway 端口 (默认: 18789)"
            exit 0 ;;
        *) echo "未知参数: $1"; exit 1 ;;
    esac
done

# 检查 OpenClaw
if ! command -v openclaw &>/dev/null; then
    echo "❌ 未找到 openclaw CLI"
    exit 1
fi

# 获取 gateway token
TOKEN=$(openclaw config get gateway.auth.token 2>/dev/null | head -1)
if [ -z "$TOKEN" ] || [ "$TOKEN" = "__OPENCLAW_REDACTED__" ]; then
    # 直接从配置文件读
    TOKEN=$(python3 -c "
import json, os
with open(os.path.expanduser('~/.openclaw/openclaw.json')) as f:
    c = json.load(f)
print(c.get('gateway',{}).get('auth',{}).get('token',''))
" 2>/dev/null)
fi

if [ -z "$TOKEN" ]; then
    echo "❌ 无法获取 Gateway token"
    echo "   请先运行: openclaw configure"
    exit 1
fi

# 获取局域网 IP
LOCAL_IP=$(python3 -c "
import socket
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
try:
    s.connect(('8.8.8.8', 80))
    print(s.getsockname()[0])
except: print('')
finally: s.close()
")

if [ -z "$LOCAL_IP" ]; then
    echo "❌ 无法获取局域网 IP，请确保已连接 WiFi"
    exit 1
fi

GATEWAY_URL="http://${LOCAL_IP}:${PORT}"

# 验证 gateway 是否在线
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${GATEWAY_URL}/health" 2>/dev/null || echo "000")
if [ "$HTTP_STATUS" != "200" ]; then
    echo "⚠️  Gateway 在 ${GATEWAY_URL} 不可达 (HTTP ${HTTP_STATUS})"
    echo "   确认 openclaw gateway 正在运行"
fi

# 构建 payload
PAYLOAD=$(python3 -c "
import json
print(json.dumps({
    'url': '${GATEWAY_URL}',
    'token': '${TOKEN}',
    'agent': '${AGENT_ID}'
}, ensure_ascii=False))
")

echo ""
echo "🔗 Pulse Watch 配对"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Gateway:  ${GATEWAY_URL}"
echo "  Agent:    ${AGENT_ID}"
echo "  Token:    ${TOKEN:0:8}..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📱 用 Pulse Watch app 扫描下方二维码："
echo ""

# 生成终端 QR Code
python3 -c "
import sys, os
# 兼容 --user 安装路径
user_site = os.path.expanduser('~/Library/Python/3.14/lib/python/site-packages')
if os.path.isdir(user_site): sys.path.insert(0, user_site)
import qrcode
qr = qrcode.QRCode(version=1, error_correction=qrcode.constants.ERROR_CORRECT_L, box_size=1, border=2)
qr.add_data('''${PAYLOAD}''')
qr.make(fit=True)
qr.print_ascii(invert=True)
"

echo ""
echo "⚠️  确保手机和电脑在同一 WiFi 网络"
echo "💡 扫码后 app 自动连接，token 安全存储在 Keychain"
echo ""
