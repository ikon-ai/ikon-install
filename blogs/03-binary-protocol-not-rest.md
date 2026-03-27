# Binary Protocol, Not REST

Every modern web application speaks the same language: JSON over HTTP. The client makes a request, the server sends a response, the connection closes. Need real-time updates? Add WebSockets. Need file uploads? Something else. Need streaming? Another protocol. Need video? A separate media server. Each requirement bolts another layer onto the original request-response model.

Ikon takes a fundamentally different approach. A single persistent connection carries everything — interface updates, audio streams, video frames, function calls, and events — all multiplexed over one channel. No REST endpoints. No GraphQL. No separate real-time servers.

## What this unlocks

The single-connection model isn't an optimization detail — it's what makes certain categories of AI applications buildable without specialized infrastructure knowledge.

**Voice and video AI apps without media expertise.** Building a voice-enabled AI application on a traditional stack means setting up a media server, coordinating signaling protocols, handling codec negotiation, and somehow synchronizing audio with your AI responses. On Ikon, audio frames flow over the same connection as interface updates and AI responses. A developer built a full video conferencing app with per-participant speech recognition and real-time AI summaries — one connection per client, no media server, no signaling protocol. The audio, the transcription updates, and the AI-generated summaries all arrive interleaved on the same channel.

**Multimodal apps over a single connection.** An app where people describe a scene in natural language, the AI generates a visualization, and synthesized speech narrates the result — that's three modalities (text, graphics, audio) flowing in both directions. On a traditional stack, you'd coordinate separate services for each. On Ikon, it's one connection with different message types. The creator doesn't think about transport — they think about what the AI should do.

**Interactions that feel instant.** In interactive AI applications — where people type and expect streaming responses, speak and expect real-time transcription, click and expect immediate feedback — the overhead of traditional approaches adds up. Every interaction on Ikon skips the usual framing, headers, and text-based parsing. For applications like AI characters with lip-synced speech and reactive expressions, this is the difference between an experience that feels alive and one that feels like it's buffering.

**The server can reach the client, not just the other way around.** The server can push interface updates, stream audio, and invoke client-side functions without the client asking. An AI agent can work in the background and push results when ready. Text and speech can stream in lockstep. These aren't edge cases — they're the natural patterns of interactive AI applications, and the connection supports them natively.

## Teleport: a purpose-built protocol

At the core of Ikon's communication layer is **Teleport**, a binary format designed specifically for real-time interactive applications. Every message has a compact header — just 27 bytes — followed by a payload where field names are compressed to tiny identifiers at build time.

The result: a typical interface update that would be 2KB in the text-based format most web apps use is a few hundred bytes in Teleport, before compression is even applied.

## One connection, every channel

Different types of traffic — connection management, heartbeats, application events, function calls, interface updates, audio, and video — all flow over a single persistent connection. When someone speaks into their microphone, the audio arrives on the same connection that carries their interface updates. When the server generates a response with text, tool calls, and a synthesized voice, all of it streams back on the same connection.

This eliminates the architectural complexity of coordinating multiple connection types. There's no "the real-time connection dropped but the API still works" failure mode. One connection, one reconnection strategy, one keepalive mechanism.

## Smart connection handling

The connection layer supports multiple transports and negotiates automatically. The client tries the fastest option first, falls back if needed, and remembers what worked for faster reconnection next time.

Reconnection is also intelligent: a brief disconnection (under five minutes) reconnects quickly without repeating authentication. A longer gap triggers a full reconnect. This happens automatically — the creator doesn't need to handle it.

## How this feels in practice

With a persistent connection, every interaction is immediate: the user does something, the message is written to the existing connection, the server processes it, and the response streams back. There's no connection setup, no header overhead, no text-based parsing on every exchange.

For interactive AI applications where people expect immediate feedback — typing and seeing streaming responses, speaking and seeing real-time transcription, clicking and seeing instant results — this difference is perceptible. The experience feels direct and responsive rather than mediated.

## Two-way communication as a primitive

Traditional web architecture is inherently one-directional: the client asks, the server answers. Making the server push data to the client requires adding a separate mechanism.

Ikon's protocol is bidirectional from the start. The server can push interface updates, stream audio, and invoke functions on the client without the client asking. The client can send input, stream audio, and call server functions. Both directions use the same protocol and the same message format.

This enables patterns that are awkward or impossible with traditional approaches:

**Interleaved streaming**: An AI generates text while simultaneously producing speech audio. Both streams arrive interleaved on the same connection, synchronized. The client renders text and plays audio in lockstep.

**Live interface without polling**: When a background AI task completes, the server updates the interface and pushes the change. The update arrives the moment it's ready — no polling, no checking.

**Server-initiated queries**: The server can ask the client for information — GPS coordinates, camera access, local data — and get a response, all over the same connection.

## Built for production

Production systems need to handle slow clients, network congestion, and burst traffic gracefully. The protocol layer handles this with bounded message queues, independent backpressure per channel, and connection limits per server instance. If a client can't keep up, the system drops the connection rather than accumulating unbounded memory — a failure mode that has caused production outages at companies with dedicated infrastructure teams.

REST remains excellent for simple, stateless interactions. But interactive AI applications are stateful, streaming, bidirectional, multimodal, and latency-sensitive. Teleport is purpose-built for this category — where the assumptions of traditional web communication are actively working against you.
