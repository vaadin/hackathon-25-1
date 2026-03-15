# Vaadin SwingBridge Hackathon: Audiveris + Chess

During the Vaadin 25.1 hackathon I put [Vaadin SwingBridge](https://vaadin.com/docs/latest/tools/modernization-toolkit/swing-bridge) to the test by running two real, open source Swing desktop applications in the browser, with no changes to their original source code.

I chose two apps with very different complexity profiles:

- **[Java Chess Game](https://github.com/manolo/Java-Chess-Game/tree/fix/chess-rules)**: A simple chess game packaged as a single fat JAR. Straightforward to integrate, good baseline for testing SwingBridge with a minimal Swing app.
- **[Audiveris](https://github.com/Audiveris/audiveris)**: An advanced music score recognition (OMR) application with 56 dependency JARs, native libraries (Tesseract/Leptonica via JavaCPP), and a requirement for Java 25. A stress test for SwingBridge's classloader isolation, file dialog interception, and rendering capabilities.

| Route | Application | Description |
|-------|-------------|-------------|
| `/` | **Audiveris** | Upload a sheet music image or PDF and Audiveris transcribes it to MusicXML |
| `/chess` | **Chess Master** | Two player and AI chess game with configurable difficulty |

## Demo

https://github.com/vaadin/hackathon-25-1/raw/manolo/hackathon-25-1_x2.mp4

The video shows:

- **Responsive layout**: the Swing app adapts to the browser viewport. Resizing the window and toggling the AppLayout drawer panel both resize the app in real time.
- **File upload**: a PDF music score is uploaded through the browser. Audiveris receives it and processes each page, running OCR and music recognition.
- **Multitasking**: while Audiveris processes the score, we switch to the Chess app and play a few moves, then switch back. Each app runs in its own isolated session.
- **File download**: after processing, the recognized score is exported as MusicXML and downloaded to the local machine, ready to open in a music notation editor like MuseScore.

## Issues found

During the hackathon I identified eight issues in SwingBridge, opened tickets, and submitted PRs with fixes:

| Issue | PR | Description |
|-------|-----|-------------|
| [#140](https://github.com/vaadin/vaadin-swing-bridge/issues/140) | [#146](https://github.com/vaadin/vaadin-swing-bridge/pull/146) | Upload dialog blocks file selection with custom `FileFilter` |
| [#141](https://github.com/vaadin/vaadin-swing-bridge/issues/141) | [#147](https://github.com/vaadin/vaadin-swing-bridge/pull/147) | `FileDialog` (AWT) is not intercepted: missing toolkit peer, broken modal loop, empty `getFiles()` |
| [#142](https://github.com/vaadin/vaadin-swing-bridge/issues/142) | [#148](https://github.com/vaadin/vaadin-swing-bridge/pull/148) | Swing app does not adapt to container/viewport size |
| [#143](https://github.com/vaadin/vaadin-swing-bridge/issues/143) | [#149](https://github.com/vaadin/vaadin-swing-bridge/pull/149) | Download dialog fails to detect file extension with custom `FileFilter` |
| [#144](https://github.com/vaadin/vaadin-swing-bridge/issues/144) | [#150](https://github.com/vaadin/vaadin-swing-bridge/pull/150) | Java 25 compatibility for `WindowPeer` API changes |
| [#145](https://github.com/vaadin/vaadin-swing-bridge/issues/145) | [#151](https://github.com/vaadin/vaadin-swing-bridge/pull/151) | Canvas not updated when Swing app resizes its own window internally |
| [#152](https://github.com/vaadin/vaadin-swing-bridge/issues/152) | [#153](https://github.com/vaadin/vaadin-swing-bridge/pull/153) | Save As triggers spurious overwrite confirmation on temp file |
| [#154](https://github.com/vaadin/vaadin-swing-bridge/issues/154) | [#155](https://github.com/vaadin/vaadin-swing-bridge/pull/155) | `FileDialog` download defaults to "download" with no file extension |

## Setup

> **Note:** This project depends on `swing-bridge 1.1-SNAPSHOT` which includes all the fixes listed above. Until the PRs are merged into the official release, you need to build SwingBridge locally from the [`hackathon-25-1/manolo-all-fixes`](https://github.com/vaadin/vaadin-swing-bridge/tree/hackathon-25-1/manolo-all-fixes) branch:
>
> ```bash
> git clone https://github.com/vaadin/vaadin-swing-bridge.git
> cd vaadin-swing-bridge
> git checkout hackathon-25-1/manolo-all-fixes
> mvn install -DskipTests
> cd ..
> ```

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
├── setup.sh                          # Clone and build external apps
├── pom.xml                           # Spring Boot 4, Vaadin 25.1, SwingBridge 1.1-SNAPSHOT
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
- All SwingBridge fixes are tracked in the [`hackathon-25-1/manolo-all-fixes`](https://github.com/vaadin/vaadin-swing-bridge/tree/hackathon-25-1/manolo-all-fixes) branch.
