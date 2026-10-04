#!/bin/bash
# Laeuft nur auf GitHub, vor dem IPA-Bau. Schreibt PNG-Dateien nach /tmp/aufraeumer-shots.
# Der aeussere Bau darf nicht abbrechen, sonst gibt es keine IPA und keine Bilder.
# Der Status steht in status.txt. 0 bedeutet, der Simulator-Test war gruen.
if [ -n "${AUFTRAEUMER_IN_SHOTS:-}" ]; then
  exit 0
fi
if [ -z "${GITHUB_ACTIONS:-}" ]; then
  exit 0
fi
export AUFTRAEUMER_IN_SHOTS=1
mkdir -p /tmp/aufraeumer-shots /tmp/aufraeumer-xcresult
rm -f /tmp/aufraeumer-shots/*.png /tmp/aufraeumer-shots/status.txt
GERAET=$(xcrun simctl list devices available | grep -E "iPhone .*Pro Max \(" | head -1 | sed -E 's/^[[:space:]]*//; s/ \([A-F0-9-]+\).*//')
if [ -z "$GERAET" ]; then
  GERAET=$(xcrun simctl list devices available | grep -E "iPhone" | head -1 | sed -E 's/^[[:space:]]*//; s/ \([A-F0-9-]+\).*//')
fi
echo "Geraet: ${GERAET:-keins}"
STATUS=1
LOG=/tmp/aufraeumer-shots/xcodebuild.log
if [ -n "$GERAET" ]; then
  set +e
  # Saubere Umgebung. Sonst erbt der Simulator-Test das iPhoneOS-SDK des Archivs
  # und verknuepft das falsche XCTest.
  UMGEBUNG=(
    "PATH=$PATH"
    "HOME=$HOME"
    "USER=${USER:-runner}"
    "LOGNAME=${LOGNAME:-${USER:-runner}}"
    "SHELL=/bin/bash"
    "TMPDIR=${TMPDIR:-/tmp}"
    "LANG=${LANG:-en_US.UTF-8}"
    "GITHUB_ACTIONS=1"
    "AUFTRAEUMER_IN_SHOTS=1"
  )
  if [ -n "${DEVELOPER_DIR:-}" ]; then
    UMGEBUNG+=("DEVELOPER_DIR=$DEVELOPER_DIR")
  fi
  env -i "${UMGEBUNG[@]}" \
    xcodebuild -project "${SRCROOT}/Aufraeumer.xcodeproj" -scheme Aufraeumer \
      -derivedDataPath /tmp/aufraeumer-dd \
      -destination "platform=iOS Simulator,name=${GERAET}" \
      -only-testing:AufraeumerUITests/ScreenshotTests/testAlleBildschirme \
      -resultBundlePath /tmp/aufraeumer-xcresult/TestResults.xcresult \
      test >"$LOG" 2>&1
  STATUS=$?
  set -e
fi
if [ -d /tmp/aufraeumer-xcresult/TestResults.xcresult ]; then
  xcrun xcresulttool export attachments \
    --path /tmp/aufraeumer-xcresult/TestResults.xcresult \
    --output-path /tmp/aufraeumer-shots/anhaenge >/tmp/aufraeumer-shots/export.log 2>&1 || true
fi
echo "$STATUS" > /tmp/aufraeumer-shots/status.txt
echo "Screenshot-Status: $STATUS"
find /tmp/aufraeumer-shots -name "*.png" | wc -l
if [ "$STATUS" -ne 0 ] && [ -f "$LOG" ]; then
  sed 's/error:/Hinweis:/g' "$LOG" | tail -n 80
fi
exit "$STATUS"
