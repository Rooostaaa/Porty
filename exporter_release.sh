#!/usr/bin/env bash
# Exporte Port Horizon en release pour Linux et Windows (et Android si un keystore est fourni).
#   ./exporter_release.sh            : Linux + Windows
#   ./exporter_release.sh android    : en plus l'APK Android release (SDK Android + keystore requis, voir docs/RELEASE.md)
# Godot : variable GODOT (par défaut /opt/godot/Godot_v4.7.1-stable_linux.x86_64, sinon « godot » dans le PATH).
# Modèles d'export 4.7.1 dans ~/.local/share/godot/export_templates/4.7.1.stable/.
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$PWD"
G="${GODOT:-/opt/godot/Godot_v4.7.1-stable_linux.x86_64}"
[ -x "$G" ] || G="$(command -v godot || true)"
[ -n "$G" ] || { echo "Godot introuvable : définir GODOT=/chemin/vers/Godot" >&2; exit 1; }

mkdir -p build/linux build/windows
rm -f build/linux/PortHorizon.x86_64 build/windows/PortHorizon.exe

echo "== Import des ressources"
timeout 600 "$G" --headless --path godot --import

export_one() {   # preset, chemin de sortie (relatif à la racine)
  echo "== Export « $1 » -> $2"
  timeout 900 "$G" --headless --path godot --export-release "$1" "$ROOT/$2"
  [ -f "$2" ] || { echo "Échec : $2 absent" >&2; exit 1; }
}

export_one "Linux" build/linux/PortHorizon.x86_64
export_one "Windows Desktop" build/windows/PortHorizon.exe
if [ "${1:-}" = "android" ]; then
  : "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:?keystore de release non défini (docs/RELEASE.md)}"
  mkdir -p build/android && rm -f build/android/PortHorizon.apk
  export_one "Android Release" build/android/PortHorizon.apk
fi

echo "== Builds"
ls -lh build/linux build/windows build/android 2>/dev/null || true
