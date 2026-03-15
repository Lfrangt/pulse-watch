#!/bin/bash
# Pulse Watch — OpenClaw 配对二维码生成器
# 用法: ./Scripts/pair.sh [--agent AGENT_ID]
#
# 在终端生成 QR Code，用 Pulse Watch app 扫码即可连接

set -e

AGENT_ID="openclaw:main"
PORT=18789

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --agent) AGENT_ID="$2"; shift 2 ;;
        --port) PORT="$2"; shift 2 ;;
        -h|--help)
            echo "用法: $0 [--agent AGENT_ID] [--port PORT]"
            echo ""
            echo "生成 Pulse Watch 配对二维码"
            echo "  --agent  Agent ID (默认: openclaw:main)"
            echo "  --port   Gateway 端口 (默认: 18789)"
            exit 0 ;;
        *) echo "未知参数: $1"; exit 1 ;;
    esac
done

# 获取本机局域网 IP
LOCAL_IP=$(python3 -c "
import socket
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
try:
    s.connect(('8.8.8.8', 80))
    print(s.getsockname()[0])
except:
    print('')
finally:
    s.close()
")

if [ -z "$LOCAL_IP" ]; then
    echo "❌ 无法获取局域网 IP，请确保已连接 WiFi"
    exit 1
fi

GATEWAY_URL="http://${LOCAL_IP}:${PORT}"

# 生成随机 token（32 字节 hex）
TOKEN=$(python3 -c "import secrets; print(secrets.token_hex(32))")

# 构建 QR payload
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
import sys
sys.path.insert(0, '$HOME/Library/Python/3.14/lib/python/site-packages')
import qrcode
qr = qrcode.QRCode(
    version=1,
    error_correction=qrcode.constants.ERROR_CORRECT_L,
    box_size=1,
    border=2,
)
qr.add_data('${PAYLOAD}')
qr.make(fit=True)
qr.print_ascii(invert=True)
"

echo ""
echo "⚠️  确保手机和电脑在同一 WiFi 网络"
echo "💡 配对后 token 将安全存储在 iPhone Keychain"
echo ""
