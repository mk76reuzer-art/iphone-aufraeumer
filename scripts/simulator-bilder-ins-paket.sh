#!/bin/bash
# Legt die Simulatorbilder in die App, damit sie in der IPA mitkommen.
# Nur PNG und status.txt, nicht das grosse Testergebnis.
if [ -z "${GITHUB_ACTIONS:-}" ]; then
  exit 0
fi
QUELLE="/tmp/aufraeumer-shots"
ZIEL="${TARGET_BUILD_DIR}/${WRAPPER_NAME}/SimulatorBilder"
mkdir -p "$ZIEL"
if [ -f "$QUELLE/status.txt" ]; then
  cp "$QUELLE/status.txt" "$ZIEL/status.txt"
fi
find "$QUELLE" -name "*.png" -type f | while read -r datei; do
  cp "$datei" "$ZIEL/$(uuidgen)-$(basename "$datei")" || true
done
echo "Simulatorbilder im Paket: $(find "$ZIEL" -name "*.png" | wc -l)"
exit 0
