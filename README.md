# SwingBridge Demo: Audiveris + Chess

Two Swing desktop applications running in the browser via [Vaadin SwingBridge](https://vaadin.com/docs/latest/tools/modernization-toolkit/swing-bridge), with zero changes to their original source code (only a minor patch to Audiveris for macOS file dialog compatibility).

| Route | Application | Description |
|-------|-------------|-------------|
| `/` | **Audiveris** | Open source music score recognition (OMR). Upload a sheet music image or PDF and Audiveris transcribes it to MusicXML. |
| `/chess` | **Chess Master** | Two player and AI chess game with configurable difficulty. |

## Prerequisites

- **Java 25** (e.g. [Eclipse Temurin 25+36](https://adoptium.net/))
- **Git**
- **Maven 3.9+** (or use the included Maven Wrapper)

A Vaadin commercial subscription or trial license is required. On first run you will be prompted to log in to [vaadin.com](https://vaadin.com) to activate a trial automatically.

## Quick Start

```bash
./setup.sh
./mvnw spring-boot:run
```

Open `http://localhost:8888` for Audiveris or `http://localhost:8888/chess` for Chess.

## What does setup.sh do?

1. Verifies Java 25 is installed
2. Clones and builds [Java Chess Game](https://github.com/halwins/Java-Chess-Game) (fat JAR via Maven Shade)
3. Clones and builds [Audiveris](https://github.com/Audiveris/audiveris) (56 JARs via Gradle installDist)
4. Patches Audiveris to use `JFileChooser` instead of `FileDialog` on macOS (SwingBridge does not intercept AWT `FileDialog`)
5. Patches SwingBridge to allow file uploads when apps use custom `FileFilter` subclasses (requires access to the [SwingBridge source repo](https://github.com/vaadin/vaadin-swing-bridge))
6. Copies all JARs to `applibs/`

## Manual Setup

If you prefer to run the steps manually:

```bash
# 1. Build Chess Game
git clone https://github.com/halwins/Java-Chess-Game.git
cd Java-Chess-Game && mvn package -DskipTests
cp target/ChessGame.jar ../applibs/
cd ..

# 2. Build Audiveris
git clone -b development https://github.com/Audiveris/audiveris.git
cd audiveris

# 2a. Patch for macOS file dialogs (replace FileDialog with JFileChooser)
sed -i '' 's/if (WellKnowns.MAC_OS_X) {/if (WellKnowns.MAC_OS_X \&\& !Boolean.getBoolean("audiveris.useJFileChooser")) {/g' \
  app/src/main/java/org/audiveris/omr/ui/util/UIUtil.java

./gradlew installDist
cp app/build/install/app/lib/*.jar ../applibs/
cd ..

# 3. Run
./mvnw spring-boot:run
```

## Project Structure

```
├── setup.sh                          # Automated setup (clone, patch, build)
├── pom.xml                           # Spring Boot 4, Vaadin 25.1, SwingBridge 1.0
├── .mvn/jvm.config                   # JVM flags for java.desktop module access
├── applibs/                          # Application JARs (populated by setup.sh)
└── src/main/java/com/example/
    ├── Application.java              # Spring Boot entry point (@Push)
    └── views/
        ├── AudiverisView.java        # SwingBridge("Audiveris") on route /
        └── ChessGameView.java        # SwingBridge("com.ChessGame") on route /chess
```

## How SwingBridge Works

SwingBridge patches `java.desktop` at the JVM level to intercept AWT/Swing rendering. The Swing UI runs on the server and is streamed to the browser via WebSocket. User input (clicks, keyboard, scroll) travels back to the server and is replayed on the actual Swing components.

Each browser session gets its own isolated `AppContext`, so multiple users can use the apps simultaneously.

Application JARs are loaded from `applibs/` through an isolated `URLClassLoader`, keeping their dependencies separate from the server classpath.

## Known Issues

- **macOS file dialogs**: Audiveris uses `FileDialog` (AWT) on macOS for native look and feel. SwingBridge only intercepts `JFileChooser`. The setup script patches Audiveris to fall back to `JFileChooser` via a system property.
- **Custom file filters**: SwingBridge extracts accepted file extensions only from `FileNameExtensionFilter`. Apps using custom `FileFilter` subclasses need the SwingBridge patch included in the setup script.
- **Window clipping**: Some Swing apps may have their content clipped at the top or bottom edges in the browser rendering.
- **Run from CLI only**: Always use `./mvnw spring-boot:run`. IDE play buttons do not apply the required JVM flags.
