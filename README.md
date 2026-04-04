# Durak Cross-Platform Multiplayer

A fully-featured, cross-platform implementation of the classic card game **Durak**, built with Flutter. This application allows players to enjoy Durak both solo against AI opponents and seamlessly with friends across iOS and Android devices, regardless of platform differences.

## 🌟 Key Features

* **Cross-Platform Multiplayer**: Play seamlessly between iOS and Android devices.
* **Hybrid Networking (WiFi + BLE)**: 
  * Uses Zero-configuration networking (mDNS/DNS-SD) for fast discovery and TCP sockets for reliable, high-speed connection over local WiFi.
  * Falls back to a robust Bluetooth Low Energy (BLE) implementation for offline or non-WiFi environments.
* **Single-Player Mode**: Play against a built-in AI with an understanding of Durak stragegies.
* **Full Game Rules**: Supports standard Durak rules, including attacking, defending, successful defenses, and transferring (passing the attack to the next player).
* **Rich, Animated UI**: 
  * Dynamic, animated game screens with smooth card transitions.
  * Polished interactive elements, including a dynamic game status bar and player avatars.
  * An exciting, animated Game Over screen with different states for a win or loss.
* **Production-Ready**: Comprehensive unit and integration testing suite covering game logic, networking, and serialization.

## 🏗 Architecture & Tech Stack

This project is built using:
* **Framework**: [Flutter](https://flutter.dev/)
* **State Management**: `provider`
* **Networking & Discovery**: 
  * `nsd` for mDNS/DNS-SD service discovery (WiFi).
  * `flutter_blue_plus` (Central) & `flutter_ble_peripheral` (Peripheral) for BLE networking.
* **Unique Identification**: `uuid` for consistent device routing.
* **UI & Theming**: `google_fonts`, `cupertino_icons`

### Core Packages

* `lib/engine/`: Contains the core `GameEngine` handling game rules, phases, and turn validation. It also includes the `AIPlayer` behavior.
* `lib/models/`: Domain models such as `Card`, `Deck`, `Player`, and `GameState` (fully serializable for network syncing).
* `lib/network/`: The heart of the multiplayer system. Features `SocketService` for TCP/IP, `BleNetworkService` for Bluetooth, and a higher-level `GameSync` and `DiscoveryService` to orchestrate them.
* `lib/screens/`: Fluid, state-aware UI screens (`HomeScreen`, `LobbyScreen`, `GameScreen`, `GameOverScreen`).
* `lib/widgets/`: Reusable game interface widgets (`PlayingCardWidget`, `CardHandWidget`, `TableWidget`, `DeckWidget`, etc.).

## 📡 The Hybrid Networking Model

One of the significant challenges in local mobile multiplayer is cross-platform restrictions (e.g., iOS and Android have different local networking constraints). This app solves it using a hybrid approach:

1. **Host Advertisement**: The host device advertises its presence simultaneously on the Local Area Network (via mDNS) and via Bluetooth Low Energy (as a BLE peripheral).
2. **Client Discovery**: Client devices scan for both services.
3. **Connection Prioritization**: 
   - If a WiFi connection is possible, the client connects to the host's TCP socket. TCP offers better bandwidth and stability for full game state synchronization.
   - If WiFi fails or isn't available, the client automatically falls back to pairing over BLE characteristics.
4. **Message Protocol**: A unified `MessageProtocol` encrypts and structures payloads universally, meaning the upper logic layers (`GameSync`) don't need to worry about whether a payload was delivered via TCP or BLE.

## 🚀 Getting Started

### Prerequisites
* Flutter SDK (v3.11.4 or higher)
* Android Studio or Xcode (for simulator/emulator or physical device deployment)

### Running the App
Since multiplayer relies heavily on specific hardware radios (Bluetooth and Local Network), **testing on physical devices is highly recommended**.

1. Clone the repository.
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run on a connected device:
   ```bash
   flutter run
   ```

*Note: For iOS, you may need to open the project in Xcode to assign a development team and ensure proper entitlements for Local Network and Bluetooth.*

## 🧪 Testing

The codebase includes a highly robust testing suite focused on verifying the game engine integrity and network service reliability.

To run the complete test suite:

```bash
flutter test
```

Test coverage includes:
- **Engine logic**: Attacking, defending, passing, invalid moves, and win/loss states.
- **Model serialization**: Ensuring all game primitives map perfectly to JSON for network transport.
- **Networking**: Mocked socket connections ensuring events are propagated evenly between host/client architectures.
