#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Setup script for SwingBridge Audiveris + Chess demo
#
# Downloads, patches, and builds all dependencies:
#   - Java Chess Game  (fat JAR)
#   - Audiveris        (56 JARs, patched for JFileChooser on macOS)
#   - SwingBridge      (patched for custom FileFilter support)
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/.build"
APPLIBS_DIR="$SCRIPT_DIR/applibs"

CHESS_REPO="https://github.com/halwins/Java-Chess-Game.git"
AUDIVERIS_REPO="https://github.com/Audiveris/audiveris.git"
AUDIVERIS_BRANCH="development"
BRIDGE_REPO="git@github.com:vaadin/vaadin-swing-bridge.git"

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

JAVA_VERSION=$(java -version 2>&1 | head -1 | sed 's/.*"\([0-9]*\).*/\1/')
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
        git clone --depth 1 "$CHESS_REPO" "$CHESS_DIR"
    fi

    info "Building Chess Game..."
    (cd "$CHESS_DIR" && mvn package -DskipTests -q)

    cp "$CHESS_DIR/target/ChessGame.jar" "$APPLIBS_DIR/"
    info "ChessGame.jar copied to applibs/."
fi

# --------------------------------------------------------------------------
# 3. Build Audiveris (with JFileChooser patch for macOS)
# --------------------------------------------------------------------------
AUDIVERIS_DIR="$BUILD_DIR/audiveris"

if [ -f "$APPLIBS_DIR/audiveris.jar" ]; then
    info "audiveris.jar already exists, skipping."
else
    info "Cloning Audiveris..."
    if [ ! -d "$AUDIVERIS_DIR" ]; then
        git clone --depth 1 -b "$AUDIVERIS_BRANCH" "$AUDIVERIS_REPO" "$AUDIVERIS_DIR"
    fi

    # Patch: force JFileChooser instead of FileDialog on macOS.
    # FileDialog is not intercepted by SwingBridge.
    UIUTIL="$AUDIVERIS_DIR/app/src/main/java/org/audiveris/omr/ui/util/UIUtil.java"
    if grep -q 'audiveris.useJFileChooser' "$UIUTIL" 2>/dev/null; then
        info "Audiveris already patched."
    else
        info "Patching Audiveris (UIUtil.java: FileDialog -> JFileChooser)..."
        sed -i.bak 's/if (WellKnowns.MAC_OS_X) {/if (WellKnowns.MAC_OS_X \&\& !Boolean.getBoolean("audiveris.useJFileChooser")) {/g' "$UIUTIL"
        rm -f "$UIUTIL.bak"
    fi

    info "Building Audiveris..."
    (cd "$AUDIVERIS_DIR" && ./gradlew installDist -q)

    cp "$AUDIVERIS_DIR/app/build/install/app/lib/"*.jar "$APPLIBS_DIR/"
    info "Audiveris JARs ($(ls "$AUDIVERIS_DIR/app/build/install/app/lib/"*.jar | wc -l | tr -d ' ') files) copied to applibs/."
fi

# --------------------------------------------------------------------------
# 4. Patch SwingBridge (fix empty accept filter for custom FileFilter)
# --------------------------------------------------------------------------
info "Patching SwingBridge upload dialog..."

# Resolve dependencies first so the JAR is in the local Maven repo
(cd "$SCRIPT_DIR" && ./mvnw dependency:resolve -q 2>/dev/null || true)

BRIDGE_VERSION=$(grep '<swing-bridge.version>' "$SCRIPT_DIR/pom.xml" | sed 's/.*>\(.*\)<.*/\1/')
BRIDGE_JAR="$HOME/.m2/repository/com/vaadin/swing-bridge-flow/$BRIDGE_VERSION/swing-bridge-flow-$BRIDGE_VERSION.jar"

if [ ! -f "$BRIDGE_JAR" ]; then
    warn "SwingBridge JAR not found at $BRIDGE_JAR. Run './mvnw spring-boot:run' once to download dependencies, then re-run this script."
else
    # Check if already patched by looking for the fix marker
    PATCH_MARKER="$HOME/.m2/repository/com/vaadin/swing-bridge-flow/$BRIDGE_VERSION/.patched"
    if [ -f "$PATCH_MARKER" ]; then
        info "SwingBridge already patched."
    else
        BRIDGE_SRC_DIR="$BUILD_DIR/vaadin-swing-bridge"
        NEED_REBUILD=false

        if [ ! -d "$BRIDGE_SRC_DIR" ]; then
            info "Cloning SwingBridge source..."
            git clone --depth 1 "$BRIDGE_REPO" "$BRIDGE_SRC_DIR" 2>/dev/null || {
                warn "Cannot clone SwingBridge source (private repo). Upload dialog may not work with custom file filters."
                BRIDGE_SRC_DIR=""
            }
        fi

        if [ -n "$BRIDGE_SRC_DIR" ]; then
            UPLOAD_DIALOG="$BRIDGE_SRC_DIR/swing-bridge-flow/src/main/java/com/vaadin/modernization/swing/bridge/component/SwingBridgeUploadDialog.java"

            if [ -f "$UPLOAD_DIALOG" ]; then
                if grep -q 'if (!allowedExtensions.isEmpty())' "$UPLOAD_DIALOG" 2>/dev/null; then
                    info "SwingBridge source already patched."
                else
                    info "Patching SwingBridgeUploadDialog.java..."
                    sed -i.bak 's/upload.setAcceptedFileTypes(allowedExtensions.toArray(new String\[0\]));/if (!allowedExtensions.isEmpty()) {\n            upload.setAcceptedFileTypes(\n                    allowedExtensions.toArray(new String[0]));\n        }/' "$UPLOAD_DIALOG"
                    rm -f "$UPLOAD_DIALOG.bak"
                    NEED_REBUILD=true
                fi

                if [ "$NEED_REBUILD" = true ]; then
                    info "Building patched SwingBridge flow module..."
                    (cd "$BRIDGE_SRC_DIR" && mvn install -pl swing-bridge-flow -DskipTests -q 2>/dev/null) || {
                        warn "SwingBridge build failed. Trying to copy SNAPSHOT JAR..."
                    }

                    # Copy the built JAR to the correct version in local Maven repo
                    SNAPSHOT_JAR="$BRIDGE_SRC_DIR/swing-bridge-flow/target/swing-bridge-flow-1.0-SNAPSHOT.jar"
                    if [ -f "$SNAPSHOT_JAR" ]; then
                        cp "$SNAPSHOT_JAR" "$BRIDGE_JAR"
                        touch "$PATCH_MARKER"
                        info "Patched SwingBridge installed to local Maven repo."
                    else
                        warn "Could not build patched SwingBridge. Upload may not work with custom file filters."
                    fi
                else
                    touch "$PATCH_MARKER"
                fi
            fi
        fi
    fi
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
