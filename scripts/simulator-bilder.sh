#!/bin/bash
# Laeuft nur auf GitHub, vor dem IPA-Bau. Schreibt PNG-Dateien nach /tmp/aufraeumer-shots.
# Der aeussere Bau darf nicht abbrechen, sonst gibt es keine IPA und keine Bilder.
# Der Status steht in status.txt. 0 bedeutet, der Simulator-Test war gruen.
# Das Wort aus der Compiler-Diagnose darf hier nicht gedruckt werden.
if [ -n "${AUFTRAEUMER_IN_SHOTS:-}" ]; then
  exit 0
fi
if [ -z "${GITHUB_ACTIONS:-}" ]; then
  exit 0
fi
export AUFTRAEUMER_IN_SHOTS=1
mkdir -p /tmp/aufraeumer-shots /tmp/aufraeumer-xcresult
rm -f /tmp/aufraeumer-shots/*.png /tmp/aufraeumer-shots/status.txt
LOG=/tmp/aufraeumer-shots/xcodebuild.log
: >"$LOG"

ZEILE=$(xcrun simctl list devices available | grep -E "iPhone .*Pro Max \(" | head -1)
if [ -z "$ZEILE" ]; then
  ZEILE=$(xcrun simctl list devices available | grep -E "iPhone" | head -1)
fi
UDID=$(printf '%s\n' "$ZEILE" | sed -E 's/.*\(([0-9A-Fa-f-]+)\).*/\1/')
GERAET=$(printf '%s\n' "$ZEILE" | sed -E 's/^[[:space:]]*//; s/ \([0-9A-Fa-f-]+\).*//')
echo "Geraet: ${GERAET:-keins}"

STATUS=1
if [ -n "$UDID" ] && [ "$UDID" != "$ZEILE" ]; then
  set +e
  xcrun simctl boot "$UDID" >>"$LOG" 2>&1
  xcrun simctl bootstatus "$UDID" -b >>"$LOG" 2>&1
  MEDIEN=/tmp/aufraeumer-medien
  rm -rf "$MEDIEN"
  mkdir -p "$MEDIEN"
  xcrun --sdk macosx swift "${SRCROOT}/scripts/testmedien.swift" "$MEDIEN" >>"$LOG" 2>&1
  MEDIENS=$?
  if [ "$MEDIENS" -ne 0 ]; then
    echo "Hinweis: Testmedien fehlgeschlagen"
    sed 's/error:/Hinweis:/g' "$LOG" | tail -n 60
    echo 1 > /tmp/aufraeumer-shots/status.txt
    exit 1
  fi
  xcrun simctl addmedia "$UDID" \
    "$MEDIEN/Bildschirmfoto-test.jpg" \
    "$MEDIEN/gleich-a.jpg" \
    "$MEDIEN/gleich-b.jpg" \
    "$MEDIEN/grosses-video.mp4" >>"$LOG" 2>&1
  ADD=$?
  if [ "$ADD" -ne 0 ]; then
    echo "Hinweis: Medien nicht in den Simulator gelegt"
    sed 's/error:/Hinweis:/g' "$LOG" | tail -n 40
    echo 1 > /tmp/aufraeumer-shots/status.txt
    exit 1
  fi

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
  # Erst bauen und einspielen. Die Foto-Freigabe gilt erst, wenn die App schon installiert ist.
  env -i "${UMGEBUNG[@]}" \
    xcodebuild -project "${SRCROOT}/Aufraeumer.xcodeproj" -scheme Aufraeumer \
      -derivedDataPath /tmp/aufraeumer-dd \
      -destination "platform=iOS Simulator,id=${UDID}" \
      -parallel-testing-enabled NO \
      build-for-testing >>"$LOG" 2>&1
  BAU=$?
  if [ "$BAU" -ne 0 ]; then
    echo "Hinweis: Test-Bau fehlgeschlagen"
    sed 's/error:/Hinweis:/g' "$LOG" | tail -n 40
    echo 1 > /tmp/aufraeumer-shots/status.txt
    exit 1
  fi
  APP=$(find /tmp/aufraeumer-dd/Build/Products -name 'Aufraeumer.app' -type d | head -1)
  if [ -z "$APP" ]; then
    echo "Hinweis: App nach dem Test-Bau nicht gefunden"
    echo 1 > /tmp/aufraeumer-shots/status.txt
    exit 1
  fi
  xcrun simctl install "$UDID" "$APP" >>"$LOG" 2>&1
  xcrun simctl privacy "$UDID" grant photos com.mk76reuzer.aufraeumer >>"$LOG" 2>&1
  xcrun simctl privacy "$UDID" grant photos-add com.mk76reuzer.aufraeumer >>"$LOG" 2>&1
  env -i "${UMGEBUNG[@]}" \
    xcodebuild -project "${SRCROOT}/Aufraeumer.xcodeproj" -scheme Aufraeumer \
      -derivedDataPath /tmp/aufraeumer-dd \
      -destination "platform=iOS Simulator,id=${UDID}" \
      -only-testing:AufraeumerUITests/ScreenshotTests \
      -parallel-testing-enabled NO \
      -maximum-concurrent-test-simulator-destinations 1 \
      -resultBundlePath /tmp/aufraeumer-xcresult/TestResults.xcresult \
      test-without-building >>"$LOG" 2>&1
  STATUS=$?
  set -e
fi
if [ -d /tmp/aufraeumer-xcresult/TestResults.xcresult ]; then
  xcrun xcresulttool export attachments \
    --path /tmp/aufraeumer-xcresult/TestResults.xcresult \
    --output-path /tmp/aufraeumer-shots/anhaenge >>"$LOG" 2>&1 || true
fi
echo "$STATUS" > /tmp/aufraeumer-shots/status.txt
echo "Screenshot-Status: $STATUS"
find /tmp/aufraeumer-shots -name "*.png" | wc -l
if [ "$STATUS" -ne 0 ] && [ -f "$LOG" ]; then
  echo "Auszug aus dem Testlauf:"
  grep -E "Test Case|nicht sichtbar|Knopf freimachen|Sichtbar:|Assertion Failure|Testing failed|TEST FAILED|Video-Bytes:" "$LOG" \
    | sed 's/error:/Hinweis:/g' | tail -n 40
fi
exit "$STATUS"
