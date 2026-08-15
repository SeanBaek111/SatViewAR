#!/bin/bash
# 아이폰이 연결되기를 기다렸다가 서명 빌드 후 설치한다.
#
# 연결 상태만 폴링하므로 기다리는 동안 맥에 부하를 주지 않는다.
# 진행 상황은 stdout 으로 나가고, 각 단계가 한 줄씩 찍힌다.

set -uo pipefail
cd "$(dirname "$0")/.."

DEVICE_NAME="${1:-Sean’s iPhone}"

echo "waiting for device: $DEVICE_NAME"

UDID=""
while true; do
    LINE=$(xcrun devicectl list devices 2>/dev/null | grep -F "$DEVICE_NAME" | grep -v unavailable | head -1)
    if [ -n "$LINE" ]; then
        UDID=$(echo "$LINE" | awk '{ for (i = 1; i <= NF; i++) if ($i ~ /^[0-9A-F]{8}-/) { print $i; exit } }')
        if [ -n "$UDID" ]; then
            echo "device connected: $UDID"
            break
        fi
    fi
    sleep 10
done

echo "building..."
if ! xcodebuild -workspace gnssfinder.xcworkspace -scheme GnssFinder \
        -destination "id=$UDID" -allowProvisioningUpdates build > /tmp/satviewar_build.log 2>&1; then
    echo "BUILD FAILED - see /tmp/satviewar_build.log"
    grep -E "error:" /tmp/satviewar_build.log | head -5
    exit 1
fi
echo "build succeeded"

APP=$(grep -oE "/[^ ]*/SatViewAR\.app" /tmp/satviewar_build.log | head -1)
if [ -z "$APP" ]; then
    APP=$(find "$HOME/Library/Developer/Xcode/DerivedData" -name "SatViewAR.app" -path "*Debug-iphoneos*" -type d 2>/dev/null | head -1)
fi

if [ -z "$APP" ] || [ ! -d "$APP" ]; then
    echo "INSTALL FAILED - app bundle not found"
    exit 1
fi

echo "installing $APP"
if xcrun devicectl device install app --device "$UDID" "$APP" > /tmp/satviewar_install.log 2>&1; then
    echo "INSTALLED - open SatViewAR and tap Measure"
else
    echo "INSTALL FAILED - see /tmp/satviewar_install.log"
    tail -5 /tmp/satviewar_install.log
    exit 1
fi
