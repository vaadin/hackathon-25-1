#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Setup script for SwingBridge Audiveris + Chess demo
#
# Downloads and builds all dependencies:
#   - Java Chess Game  (fat JAR)
#   - Audiveris        (56 JARs)
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/.build"
APPLIBS_DIR="$SCRIPT_DIR/applibs"

CHESS_REPO="https://github.com/manolo/Java-Chess-Game.git"
CHESS_BRANCH="fix/chess-rules"
AUDIVERIS_REPO="https://github.com/Audiveris/audiveris.git"
AUDIVERIS_BRANCH="development"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { printf "${GREEN}[INFO]${NC}  %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$*"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$*"; exit 1; }

# --------------------------------------------------------------------------
# 1. Check prerequisites
# --------------------------------------------------------------------------
info "Checking prerequisites..."

if ! command -v java &>/dev/null; then
    error "Java not found. Install Java 25 (e.g. Eclipse Temurin 25+36)."
fi

JAVA_VERSION=$(java -version 2>&1 | sed -n 's/.*version "\([0-9][0-9]*\).*/\1/p' | head -1)
if ! [ "$JAVA_VERSION" -ge 25 ] 2>/dev/null; then
    error "Java 25 required, found Java ${JAVA_VERSION:-unknown}. Install Eclipse Temurin 25+36."
fi
info "Java $JAVA_VERSION detected."

if ! command -v git &>/dev/null; then
    error "Git not found."
fi

if ! command -v mvn &>/dev/null && [ ! -x "$SCRIPT_DIR/mvnw" ]; then
    error "Maven not found and no Maven Wrapper available."
fi

mkdir -p "$BUILD_DIR" "$APPLIBS_DIR"

# --------------------------------------------------------------------------
# 2. Build Chess Game
# --------------------------------------------------------------------------
CHESS_DIR="$BUILD_DIR/Java-Chess-Game"

if [ -f "$APPLIBS_DIR/ChessGame.jar" ]; then
    info "ChessGame.jar already exists, skipping."
else
    info "Cloning Java Chess Game..."
    if [ ! -d "$CHESS_DIR" ]; then
        git clone --depth 1 -b "$CHESS_BRANCH" "$CHESS_REPO" "$CHESS_DIR"
    fi

    info "Building Chess Game..."
    (cd "$CHESS_DIR" && mvn package -DskipTests -q)

    cp "$CHESS_DIR/target/ChessGame.jar" "$APPLIBS_DIR/"
    info "ChessGame.jar copied to applibs/."
fi

# --------------------------------------------------------------------------
# 3. Build Audiveris
# --------------------------------------------------------------------------
AUDIVERIS_DIR="$BUILD_DIR/audiveris"

if [ -f "$APPLIBS_DIR/audiveris.jar" ]; then
    info "audiveris.jar already exists, skipping."
else
    info "Cloning Audiveris..."
    if [ ! -d "$AUDIVERIS_DIR" ]; then
        git clone --depth 1 -b "$AUDIVERIS_BRANCH" "$AUDIVERIS_REPO" "$AUDIVERIS_DIR"
    fi

    info "Building Audiveris..."
    (cd "$AUDIVERIS_DIR" && ./gradlew installDist -q)

    cp "$AUDIVERIS_DIR/app/build/install/app/lib/"*.jar "$APPLIBS_DIR/"
    info "Audiveris JARs ($(ls "$AUDIVERIS_DIR/app/build/install/app/lib/"*.jar | wc -l | tr -d ' ') files) copied to applibs/."
fi

# --------------------------------------------------------------------------
# Done
# --------------------------------------------------------------------------
echo ""
info "Setup complete!"
echo ""
echo "  Run the application:"
echo "    ./mvnw spring-boot:run"
echo ""
echo "  Then open:"
echo "    http://localhost:8888        Audiveris (music score recognition)"
echo "    http://localhost:8888/chess   Chess Master"
echo ""
