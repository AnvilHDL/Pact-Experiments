#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
BUILD="$ROOT/src/build/tilelink_generator"
TOOLS="$ROOT/src/build/tilelink_tools"
TEMPLATE="$ROOT/src/tilelink_generator"
RTL_DIR="$ROOT/src/build/tilelink_rtl"
mkdir -p "$BUILD/rtl/src" "$TOOLS" "$RTL_DIR"

JAVA_CMD="${JAVA_CMD:-${JAVA_HOME:+$JAVA_HOME/bin/}java}"
if [[ -x "$TOOLS/jdk/bin/java" && "$JAVA_CMD" == java ]]; then
  JAVA_CMD="$TOOLS/jdk/bin/java"
fi
if ! command -v "$JAVA_CMD" >/dev/null; then
  echo "A JDK 17+ is required; set JAVA_HOME or JAVA_CMD." >&2
  exit 1
fi
MILL_JAR="${MILL_JAR:-$TOOLS/mill.jar}"
if [[ ! -f "$MILL_JAR" ]]; then
  curl -fL --retry 3 \
    https://repo.maven.apache.org/maven2/com/lihaoyi/mill-dist/0.11.13/mill-dist-0.11.13.jar \
    -o "$MILL_JAR"
fi

cp "$TEMPLATE/build.sc" "$BUILD/build.sc"
cp "$TEMPLATE/rtl/src/Generate.scala" "$BUILD/rtl/src/Generate.scala"
mkdir -p "$BUILD/rtl/tilelink_src"
cp -R "$ROOT/tilelink/tilelink/src/." "$BUILD/rtl/tilelink_src/"
# The upstream arbiter must use the current grant for both valid and payload.
patch --batch --forward -d "$BUILD/rtl/tilelink_src" -p1 < "$TEMPLATE/TLArbiter.patch"
export COURSIER_CACHE="${COURSIER_CACHE:-$TOOLS/coursier}"
export COURSIER_REPOSITORIES="${COURSIER_REPOSITORIES:-https://repo.maven.apache.org/maven2}"
cd "$BUILD"
"$JAVA_CMD" -Duser.home="$TOOLS" -cp "$MILL_JAR" mill.runner.MillMain \
  --no-server rtl.run "$RTL_DIR"
