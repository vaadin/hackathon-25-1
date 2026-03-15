# Vaadin SwingBridge Hackathon: Audiveris + Chess

During the Vaadin 25.1 hackathon I put [Vaadin SwingBridge](https://vaadin.com/docs/latest/tools/modernization-toolkit/swing-bridge) to the test by running two real, open source Swing desktop applications in the browser, with no changes to their original source code.

I chose two apps with very different complexity profiles:

- **[Java Chess Game](https://github.com/manolo/Java-Chess-Game/tree/fix/chess-rules)**: A simple chess game packaged as a single fat JAR. Straightforward to integrate, good baseline for testing SwingBridge with a minimal Swing app.
- **[Audiveris](https://github.com/Audiveris/audiveris)**: An advanced music score recognition (OMR) application with 56 dependency JARs, native libraries (Tesseract/Leptonica via JavaCPP), and a requirement for Java 25. A stress test for SwingBridge's classloader isolation, file dialog interception, and rendering capabilities.

| Route | Application | Description |
|-------|-------------|-------------|
| `/` | **Audiveris** | Upload a sheet music image or PDF and Audiveris transcribes it to MusicXML |
| `/chess` | **Chess Master** | Two player and AI chess game with configurable difficulty |

## Issues found

During the hackathon I identified six issues in SwingBridge and opened tickets:

1. [**Upload dialog blocks file selection with custom FileFilter**](https://github.com/vaadin/vaadin-swing-bridge/issues/140): When a Swing app uses a custom `FileFilter` subclass (not `FileNameExtensionFilter`), `setAcceptedFileTypes(new String[0])` blocks all file selection in the browser.
2. [**FileDialog (AWT) is not intercepted**](https://github.com/vaadin/vaadin-swing-bridge/issues/141): Many macOS apps use `java.awt.FileDialog` instead of `JFileChooser`. SwingBridge does not intercept `FileDialog`, so the dialog silently fails to appear.
3. [**Swing app does not adapt to container CSS size**](https://github.com/vaadin/vaadin-swing-bridge/issues/142): No `ResizeObserver` on the container, and hardcoded 2560x1440 screen bounds in `SwingBridgeGraphicsConfig`. Apps exceed the browser viewport with no way to constrain them via CSS.
4. [**Download dialog fails to detect file extension with custom FileFilter**](https://github.com/vaadin/vaadin-swing-bridge/issues/143): The download counterpart of issue 1. `determineExtension()` only recognizes `FileNameExtensionFilter`, causing wrong filenames and content types on save.
5. [**Java 25 compatibility for WindowPeer API changes**](https://github.com/vaadin/vaadin-swing-bridge/issues/144): SwingBridge does not compile with Java 25. `WindowPeer.repositionSecurityWarning()` was removed and `getAppropriateGraphicsConfiguration()` was added. A multi-release JAR approach is recommended to support both Java 21 and 25.
6. [**Canvas not updated when Swing app resizes its own window internally**](https://github.com/vaadin/vaadin-swing-bridge/issues/145): When a Swing app changes its own window size (e.g. navigating from a menu to a larger game board), the canvas stays clipped to the old dimensions until the page is reloaded.

## Setup

The `setup.sh` script automates cloning and building the external applications:

1. Verifies Java 25 is installed
2. Clones and builds [Java Chess Game](https://github.com/manolo/Java-Chess-Game/tree/fix/chess-rules) (fat JAR via Maven Shade)
3. Clones and builds [Audiveris](https://github.com/Audiveris/audiveris) (56 JARs via Gradle `installDist`)
4. Copies all JARs to `applibs/`

```bash
./setup.sh
./mvnw spring-boot:run
```

Open `http://localhost:8888` for Audiveris or `http://localhost:8888/chess` for Chess.

### Prerequisites

- **Java 25** (e.g. [Eclipse Temurin 25+36](https://adoptium.net/))
- **Git**
- **Maven 3.9+** (or use the included Maven Wrapper)

A Vaadin commercial subscription or trial license is required. On first run you will be prompted to log in to [vaadin.com](https://vaadin.com) to activate a trial automatically.

## Project structure

```
├── setup.sh                          # Clone, patch, and build external apps
├── pom.xml                           # Spring Boot 4, Vaadin 25.1, SwingBridge 1.0
├── .mvn/jvm.config                   # JVM flags for java.desktop module access
├── applibs/                          # Application JARs (populated by setup.sh)
└── src/main/java/com/example/
    ├── Application.java              # Spring Boot entry point (@Push)
    └── views/
        ├── AudiverisView.java        # SwingBridge("Audiveris") on route /
        └── ChessGameView.java        # SwingBridge("com.ChessGame") on route /chess
```

### How it works

SwingBridge patches `java.desktop` at the JVM level to intercept AWT/Swing rendering. The Swing UI runs on the server and is streamed to the browser via WebSocket. User input (clicks, keyboard, scroll) travels back to the server and is replayed on the actual Swing components.

Each view creates a `SwingBridge` component pointing to the main class of the target application. The bridge loads all JARs from `applibs/` through an isolated `URLClassLoader`, keeping application dependencies separate from the server classpath. Each browser session gets its own isolated `AppContext`, so multiple users can run the apps simultaneously.

The `pom.xml` declares dependencies on the three SwingBridge modules (`swing-bridge-patch`, `swing-bridge-graphics`, `swing-bridge-flow`) and configures the `spring-boot-maven-plugin` with the required `--patch-module`, `--add-exports`, and `--add-reads` JVM flags. The same flags are mirrored in `.mvn/jvm.config` for compilation. Audiveris requires two additional flags: `--add-exports=java.desktop/com.apple.eawt=ALL-UNNAMED` (macOS menu integration) and `--enable-native-access=ALL-UNNAMED` (JavaCPP native libraries).

### Notes

- Always run with `./mvnw spring-boot:run`. IDE play buttons do not apply the required JVM flags from `.mvn/jvm.config`.
- All SwingBridge fixes are tracked in the [`hackathon/25.1-fixes`](https://github.com/vaadin/vaadin-swing-bridge/tree/hackathon/25.1-fixes) branch.
