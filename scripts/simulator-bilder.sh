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
if [ -n "$GERAET" ]; then
  set +e
  xcodebuild -project "${SRCROOT}/Aufraeumer.xcodeproj" -scheme Aufraeumer \
    -derivedDataPath /tmp/aufraeumer-dd \
    -destination "platform=iOS Simulator,name=${GERAET}" \
    -only-testing:AufraeumerUITests/ScreenshotTests/testAlleBildschirme \
    -resultBundlePath /tmp/aufraeumer-xcresult/TestResults.xcresult \
    test
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
exit 0
