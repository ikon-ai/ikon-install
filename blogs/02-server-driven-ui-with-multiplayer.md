# Server-Driven UI with Built-In Multiplayer

Every web framework today assumes the same architecture: the server sends data, the client renders the interface. Then you need state management libraries, client-side routers, hydration strategies, WebSocket layers for real-time updates — all to bridge the gap between where your data lives and where pixels appear on screen.

Ikon removes that gap entirely. The interface is defined on the server, diffed on the server, and only minimal updates stream to each connected client. The client is a thin renderer with no business logic. And because the server controls what every connected person sees, multiuser collaboration comes for free.

## Multiuser for free

This is the part that surprises people. Because Ikon's server renders the interface for every connected client, collaboration isn't a feature you add — it's a consequence of how the system works.

A developer built a full video conferencing app with per-participant speech recognition, live transcription, and AI-generated meeting summaries — all updating in real time. Participants see each other's transcripts appear as they speak, watch AI summaries form while the meeting is still happening, and interact with shared artifacts. That developer wrote zero real-time synchronization code. The system handled it because it controls rendering for every client.

When AI generates content — an analysis, a visualization, a creative piece — every connected person sees it form in real time. A natural language data visualization app renders AI-generated data points on a 3D globe; when one person asks a question, everyone watching sees the globe update. This isn't a feature that was added. It's a consequence of the architecture.

## What this unlocks

The server-driven model doesn't just simplify the technical stack — it makes an entire category of applications buildable by a single person that previously required separate frontend, backend, and infrastructure teams.

**Real-time collaborative AI apps without real-time expertise.** The video conferencing example above is real. One developer, no WebSocket code, no pub/sub configuration, no client-side state synchronization. The reactive system handled all of it.

**One person builds what looks like a team effort.** Consider what it takes to build an animated AI character with lip-synced speech, reactive facial expressions, and the ability to switch between different AI models mid-conversation. On a traditional stack, you'd need a frontend engineer for the character rendering, a backend engineer for the AI orchestration, real-time infrastructure for communication, and media handling for audio streaming. On Ikon, one person builds the entire thing as a single project.

**Interface and AI logic live in the same place.** There's no separation between your AI orchestration and your interface rendering. When an AI analysis completes, the result flows directly into the interface. AI-driven applications can be genuinely responsive — showing streaming text, tool call progress, and intermediate results as they happen, not after a round-trip through a separate layer.

## How the interface works

In Ikon, you describe your interface the same way you'd write any server-side logic — with full access to all your backend services, your data, and your AI capabilities. There's no separate frontend language or framework to learn.

Here is a complete chat interface — shared messages that everyone sees, with a personal input field for each user:

```csharp
UI.Root(content: view =>
{
    // Shared state — all clients see the same messages
    foreach (var msg in _messages.Value)
    {
        view.Text(msg.Content);
    }

    // Per-client state — each client has their own input
    view.TextField(
        value: _inputText.Value,
        onValueChange: async val => { _inputText.Value = val; },
        onSubmit: async () =>
        {
            _messages.Value.Add(new Message(_inputText.Value));
            _inputText.Value = "";
        });
});
```

One person types "hello" — only their text field shows it. They submit — everyone sees the new message. That distinction between shared and personal state is handled by the framework, not by the developer.

This isn't server-side rendering in the traditional sense. The server doesn't generate a page once and send it. It maintains a live interface tree, tracks what depends on what, and when data changes, re-renders only the affected portion and sends a compressed diff to every connected client.

When data changes — whether from a background task, an AI completing its work, or another person's action — the interface updates automatically. No event handlers to write. No client-side state to synchronize. No optimistic updates to reconcile.

## Three tiers of reactivity

The reactive system is where Ikon's multiuser model comes alive. There are three types of values, each scoped differently:

### Shared across all clients

When any person adds a message, every connected person sees it instantly. The server re-renders the relevant portion of the interface for each client and sends the updates. This is your shared application state — a collaborative document, a chat room, a live scoreboard.

### Per-connection state

Each person gets their own independent value. One person can type a search query without affecting anyone else's view. The sidebar can be open for one person and closed for another. Same application, different local state — resolved automatically.

### Per-user across devices

If someone connects from both their laptop and phone, both sessions share the same value. Change the theme on one device, it updates on the other. This follows the user identity, not the connection.

## How the magic works

When the interface renders, it doesn't render once. The system runs the render pass once per connected client, each time with different scopes active. During each pass, shared values resolve the same for everyone, per-client values resolve differently for each connection, and per-user values resolve the same across a person's devices but differently for different people.

This means you describe one interface and it naturally produces different results for different clients. One person types "hello" — only their text field shows "hello." They submit — everyone sees the new message. No event bus, no state synchronization code, no pub/sub. The system handles it because it controls rendering for every client.

## Efficient by design

A fair concern with server-driven interfaces is bandwidth and performance. Ikon addresses this at every level:

**Differential updates**: The server keeps the previous interface tree for each client. After a value changes, it re-renders the affected subtree and computes a minimal diff. Only what actually changed gets sent — not the entire tree.

**Automatic dependency tracking**: When the interface reads a value during rendering, the system records that dependency. When the value changes, only the parts of the interface that actually use it re-render. Unrelated parts are untouched.

**Compact binary format**: Interface diffs are serialized in a compact binary format and optionally compressed before transmission. A typical update is a few hundred bytes.

**Server-compiled styling**: The styling system compiles CSS on the server. Only the styles used by the current interface are delivered. No unused styles, no client-side compilation overhead.

## Crosswind: styling with built-in motion

Styling in Ikon uses Crosswind — a utility-first styling system that's compatible with Tailwind's approach but extends it with a motion language for declarative animations. The motion syntax supports keyframe animations, per-letter and per-word text animations, staggered delays, easing functions, 3D transforms, and filter animations — all as styling utilities. No separate CSS files, no JavaScript animation libraries. You describe how something should look and move in the same place.

## The three-tier reactivity model eliminates an entire class of design problems

Shared state for what everyone should see. Per-connection state for individual interface controls. Per-user state that follows someone across devices. These three primitives replace the combination of state management stores, real-time event handlers, session management, and cross-device sync that traditional stacks require. You declare the scope, and the system handles the rest.
