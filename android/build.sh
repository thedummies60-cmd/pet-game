#!/usr/bin/env bash
# Builds one Android APK per Pet Arena version, each with its own launcher logo.
#
# Needs (Ubuntu): sudo apt-get install aapt apksigner zipalign \
#                   android-sdk-platform-23 dalvik-exchange imagemagick openjdk-17-jdk
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HERE="$ROOT/android"
OUT="$ROOT/apk"
BUILD="$HERE/build"
ANDROID_JAR="${ANDROID_JAR:-/usr/lib/android-sdk/platforms/android-23/android.jar}"
VERSION_CODE="${VERSION_CODE:-1}"
VERSION_NAME="${VERSION_NAME:-1.0}"

# id | package | app name | game html | logo png
VARIANTS=(
  "PetArena|com.petarena.game|Pet Arena|Pet_Arena98.html|Schattige Pet Arena-hondenmascotte.png"
  "PetArena-Halloween|com.petarena.halloween|Pet Arena Halloween|Pet_Arena_Hallowee4_.html|Halloweense Pet Arena-logo.png"
  "PetArena-Thanksgiving|com.petarena.thanksgiving|Pet Arena Thanksgiving|Pet_Arena_Thanksgiving__1_.html|Herfstige Kalkoen Pet Arena-logo.png"
  "PetArena-Kerst|com.petarena.kerst|Pet Arena Kerst|Pet_Arena_Kggrst_1__1_.html|Sneeuwman in de Pet Arena.png"
)

rm -rf "$BUILD"
mkdir -p "$BUILD/classes" "$OUT"

# The Java code is the same for every variant, so compile and dex it once.
javac -source 8 -target 8 -bootclasspath "$ANDROID_JAR" -classpath "$ANDROID_JAR" \
  -Xlint:-options -Xlint:-deprecation -d "$BUILD/classes" \
  "$HERE"/src/com/petarena/*.java
(cd "$BUILD/classes" && jar cf "$BUILD/classes.jar" .)
dalvik-exchange --dex --min-sdk-version=21 --output="$BUILD/classes.dex" "$BUILD/classes.jar"

make_icons() { # logo res_dir
  local logo="$1" res="$2"
  # Legacy launcher icon (Android 5-7): the logo with rounded corners.
  for d in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
    local dir="${d%%:*}" px="${d##*:}" r
    r=$((px / 6))
    mkdir -p "$res/mipmap-$dir"
    convert "$logo" -resize "${px}x${px}" \
      \( +clone -alpha extract -fill black -colorize 100 -fill white \
         -draw "roundrectangle 0,0,$((px-1)),$((px-1)),$r,$r" \) \
      -alpha off -compose CopyOpacity -composite "$res/mipmap-$dir/ic_launcher.png"
  done
  # Adaptive icon (Android 8+): blurred logo as background, full logo in the
  # safe zone on top so the launcher mask never cuts off "PET ARENA".
  mkdir -p "$res/drawable-nodpi" "$res/mipmap-anydpi-v26"
  convert "$logo" -resize 432x432 -blur 0x18 -modulate 85 "$res/drawable-nodpi/ic_launcher_background.png"
  convert "$logo" -resize 252x252 \
    \( +clone -alpha extract -fill black -colorize 100 -fill white \
       -draw "roundrectangle 0,0,251,251,40,40" \) \
    -alpha off -compose CopyOpacity -composite "$res/fg.png"
  convert -size 432x432 xc:none "$res/fg.png" -gravity center -compose over -composite \
    "PNG32:$res/drawable-nodpi/ic_launcher_foreground.png"
  rm "$res/fg.png"
  cat > "$res/mipmap-anydpi-v26/ic_launcher.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
</adaptive-icon>
EOF
}

for v in "${VARIANTS[@]}"; do
  IFS='|' read -r id pkg label html logo <<<"$v"
  echo "==> $id ($pkg)"
  vb="$BUILD/$id"
  mkdir -p "$vb/res" "$vb/assets"

  sed -e "s|@PKG@|$pkg|" -e "s|@LABEL@|$label|" \
      -e "s|@VCODE@|$VERSION_CODE|" -e "s|@VNAME@|$VERSION_NAME|" \
      "$HERE/AndroidManifest.xml.in" > "$vb/AndroidManifest.xml"
  cp "$ROOT/$html" "$vb/assets/index.html"
  make_icons "$ROOT/$logo" "$vb/res"

  aapt package -f -M "$vb/AndroidManifest.xml" -S "$vb/res" -A "$vb/assets" \
    -I "$ANDROID_JAR" -F "$vb/unsigned.apk"
  cp "$BUILD/classes.dex" "$vb/classes.dex"
  (cd "$vb" && aapt add unsigned.apk classes.dex >/dev/null)

  zipalign -f -p 4 "$vb/unsigned.apk" "$vb/aligned.apk"
  apksigner sign --ks "$HERE/petarena.keystore" --ks-pass pass:petarena \
    --key-pass pass:petarena --ks-key-alias petarena \
    --out "$OUT/$id.apk" "$vb/aligned.apk"
  apksigner verify "$OUT/$id.apk"
done

rm -f "$OUT"/*.idsig
echo "APKs in $OUT:"
ls -lh "$OUT"
