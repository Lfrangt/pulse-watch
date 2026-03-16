#!/bin/bash
# App Store 截图自动生成脚本
# 在两款设备上运行 UI Tests 并收集截图

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCREENSHOTS_DIR="$PROJECT_DIR/screenshots"
DERIVED_DATA="$PROJECT_DIR/build/DerivedData/Screenshots"
SCHEME="PulseWatch"
TEST_TARGET="PulseWatchUITests"

# 设备列表: 6.7" (iPhone 16 Pro Max) + 6.7" (iPhone 16 Plus)
# Note: App Store accepts 6.7" screenshots for both 6.7" and 6.5" display sizes
DEVICES=(
    "iPhone 16 Pro Max"
    "iPhone 16 Plus"
)

echo "🏗️  PulseWatch Screenshot Generator"
echo "===================================="

# 清理旧截图（保留 README.md）
find "$SCREENSHOTS_DIR" -name "*.png" -delete 2>/dev/null || true
rm -rf "$SCREENSHOTS_DIR"/iPhone_* 2>/dev/null || true

for DEVICE in "${DEVICES[@]}"; do
    SAFE_NAME=$(echo "$DEVICE" | tr ' ' '_')
    DEVICE_DIR="$SCREENSHOTS_DIR/$SAFE_NAME"
    mkdir -p "$DEVICE_DIR"

    echo ""
    echo "📱 Running on: $DEVICE"
    echo "---"

    # 清理旧的 result bundle
    rm -rf "$DERIVED_DATA/${SAFE_NAME}_result.xcresult" 2>/dev/null || true

    # 运行 UI Tests
    xcodebuild test \
        -project "$PROJECT_DIR/PulseWatch.xcodeproj" \
        -scheme "$SCHEME" \
        -destination "platform=iOS Simulator,name=$DEVICE,OS=18.5" \
        -derivedDataPath "$DERIVED_DATA/$SAFE_NAME" \
        -only-testing:"$TEST_TARGET/ScreenshotGenerator" \
        -resultBundlePath "$DERIVED_DATA/${SAFE_NAME}_result" \
        CODE_SIGNING_ALLOWED=NO \
        2>&1 | tail -20

    echo "📦 Extracting screenshots..."

    # 从 xcresult bundle 提取截图附件
    RESULT_BUNDLE="$DERIVED_DATA/${SAFE_NAME}_result.xcresult"
    if [ -d "$RESULT_BUNDLE" ]; then
        # 使用 xcresulttool 提取附件
        xcrun xcresulttool get --path "$RESULT_BUNDLE" --format json 2>/dev/null | \
            python3 -c "
import json, sys, subprocess, os

data = json.load(sys.stdin)
device_dir = '$DEVICE_DIR'

def find_attachments(obj, path=''):
    if isinstance(obj, dict):
        # Look for test attachments with payloadRef
        if 'payloadRef' in obj and 'name' in obj:
            name = obj['name'].get('_value', '') if isinstance(obj['name'], dict) else str(obj.get('name', ''))
            ref_id = obj['payloadRef'].get('id', {}).get('_value', '') if isinstance(obj['payloadRef'], dict) else ''
            if ref_id and name:
                out_path = os.path.join(device_dir, f'{name}.png')
                try:
                    result = subprocess.run(
                        ['xcrun', 'xcresulttool', 'get', '--path', '$RESULT_BUNDLE', '--id', ref_id],
                        capture_output=True
                    )
                    if result.returncode == 0 and len(result.stdout) > 100:
                        with open(out_path, 'wb') as f:
                            f.write(result.stdout)
                        print(f'  ✅ {name}.png')
                except Exception as e:
                    print(f'  ❌ {name}: {e}')
        for k, v in obj.items():
            find_attachments(v, f'{path}.{k}')
    elif isinstance(obj, list):
        for i, item in enumerate(obj):
            find_attachments(item, f'{path}[{i}]')

find_attachments(data)
" 2>/dev/null || true

        # Fallback: 直接搜索 Attachments 目录
        ATTACH_DIR=$(find "$DERIVED_DATA/$SAFE_NAME" -type d -name "Attachments" 2>/dev/null | head -1)
        if [ -n "$ATTACH_DIR" ] && [ -d "$ATTACH_DIR" ]; then
            echo "  📂 Found Attachments directory, copying..."
            cp "$ATTACH_DIR"/*.png "$DEVICE_DIR/" 2>/dev/null || true
        fi
    fi

    COUNT=$(find "$DEVICE_DIR" -name "*.png" 2>/dev/null | wc -l | tr -d ' ')
    echo "  📸 $COUNT screenshots saved to $DEVICE_DIR/"
done

echo ""
echo "===================================="
echo "✅ Done! Screenshots in: $SCREENSHOTS_DIR/"
echo ""
ls -la "$SCREENSHOTS_DIR"/*/
