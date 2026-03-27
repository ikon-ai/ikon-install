# One Codebase, Three Platforms

Imagine a training simulation: a 3D environment running in a game engine, an instructor dashboard open in a browser, and sensor data streaming from a device on a kiosk. Three completely different platforms, three different rendering technologies, three different teams who would normally need to build and maintain separate backends. Now imagine all three connect to a single application, share the same live state, and update simultaneously when anything changes.

That is what it means to build on Ikon.

## What this unlocks

**Reach web, game engines, and hardware from one application.** Build your logic once, on the server. A browser client, a Unity game, and a native device all connect to the same running application and see the same state. No duplication, no drift between platforms.

**Companion apps and cross-device experiences as a side effect.** Want a web dashboard for your game? A mobile companion for your desktop tool? Just connect another client. Both see the same shared state, updated in real time.

**AI features in games without shipping API keys in game builds.** The game client sends player context to the server, which runs all AI logic and returns responses. Credentials and models stay safely on the server, never bundled into a build that ships to end users.

**One deployment updates every client instantly.** Fix a bug, add a feature, swap an AI model -- deploy the server once. Every connected client, on every platform, gets the change immediately. No app store reviews. No version fragmentation. No "the Unity build is two versions behind the web client" drift.

**Native and embedded use cases become viable.** AI-powered decision support on constrained hardware -- kiosks, medical devices, industrial controllers -- works because the heavy lifting happens on the server. The client just needs to speak the protocol.

## The usual tradeoff (and how Ikon avoids it)

Building a multiplatform application usually means choosing between compromise and duplication. Write it in JavaScript and accept limitations on desktop and native. Write it natively for each platform and maintain three codebases. Use a cross-platform framework and fight the abstraction when it doesn't match the platform.

Ikon sidesteps this entirely. The application logic lives on the server. The client is a thin renderer. And because the server communicates through a single binary protocol called Teleport, any client that speaks the protocol can connect -- regardless of what platform it runs on.

## The protocol is the API

In a traditional architecture, the API contract is defined by HTTP endpoints, request schemas, and response formats. Every client platform needs to implement the same HTTP calls, handle the same error codes, parse the same JSON responses.

In Ikon, the contract is the Teleport protocol -- a compact binary message format with typed opcodes for UI, audio, video, and events. A client needs to establish a connection, authenticate, and send and receive messages. Everything else follows from the protocol.

This means the server does not know or care what kind of client is connected. A browser, a Unity game, and an embedded device all authenticate the same way, receive the same messages, and display the same UI. Your application logic never branches by platform.

## Three native SDKs, one protocol

Ikon provides native SDKs for three platforms, each tuned to its environment:

**TypeScript -- for web and Node.js.** Runs in browsers and server-side JavaScript. Handles transport negotiation, audio processing, and bidirectional communication between client and server. This is the SDK that powers browser-based Ikon applications.

**C# -- for .NET and Unity.** Targets both .NET applications and the Unity game engine. Supports automatic reconnection, built-in audio handling, and event-driven lifecycle management. The Unity target means the SDK works in game projects directly -- enabling AI-powered NPCs, procedural content, dialogue systems, or companion apps alongside the game.

**C++ -- for native and embedded.** A lightweight library with zero external dependencies. It adapts to whatever environment it is embedded in -- game engines, embedded systems, desktop applications, industrial hardware. If it can run C++, it can connect to an Ikon server.

All three SDKs go beyond just receiving UI updates. They support bidirectional capabilities: the server can call functions registered on the client (access a camera, query a game's inventory, read sensor data), audio streams in both directions for voice applications, and video feeds from any platform stream to the server for AI analysis.

## What it looks like in practice

**AI-powered game features.** A Unity game connects to an Ikon server running AI logic. The server handles NPC dialogue, procedural quest generation, or adaptive difficulty. The game sends player context; the server returns responses and UI overlays. The game team focuses on the game. The AI team focuses on the AI. One server serves both.

**Hardware integration.** A native application running on a kiosk or specialized device connects to an Ikon server for AI-powered decision support. The device handles its hardware concerns; the server handles intelligence.

**Cross-platform collaboration.** A desktop application and a browser client connect to the same application instance. They see each other's activity, share state, and collaborate in real time -- not because someone built a collaboration layer, but because shared state is the default.

**Companion applications.** A web dashboard and a mobile app connect to the same running Ikon server. Both see the same live AI analysis, the same monitoring data, the same collaborative document. Building the second client is just connecting another SDK.

## The key insight

One codebase on the server. Three SDKs on the client. One protocol connecting them. The application you build once serves everyone -- web users, game players, and hardware devices alike -- without maintaining separate backends, separate APIs, or separate deployment pipelines. Cross-platform support is not a feature you build. It is a consequence of where the application lives.
