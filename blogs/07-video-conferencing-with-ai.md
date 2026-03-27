# Video Conferencing with AI in a Few Thousand Lines

You join a meeting. As people start talking, their names light up smoothly when they speak -- not flickering on and off with every breath, but a natural glow that responds instantly when someone starts talking and lingers through natural pauses. Underneath the video, a live transcript scrolls: each participant's words appearing in real time, attributed to the right speaker. In a side panel, an AI-generated summary updates itself periodically, distilling the key points of the conversation so far. When you join late, you can read the summary and catch up in seconds.

This entire experience -- video conferencing with live transcription and AI-powered meeting summaries -- was built by one person, in under four thousand lines of code.

## What this unlocks

**Multiuser by default, not by effort.** This is worth stating up front: multiuser support in this app was not built. There is no code that says "when participant A's transcript updates, send it to participants B, C, and D." No event routing, no real-time sync layer, no pub/sub configuration. The developer updates a value, and every connected participant's screen reflects the change. That is how Ikon works -- shared state is shared by default.

**A single developer can build what normally takes a team.** Video conferencing with AI features is one of the hardest application categories. On a traditional stack, you need a WebRTC signaling server, a media routing server, a speech-to-text microservice, a separate AI service for summarization, a real-time state sync layer, and a frontend application with its own state management. That is a multi-team, multi-month effort. Here, it is one person and a few files.

**AI features that feel native, not bolted on.** The transcription and summarization are not separate services wired together with API calls and message queues. They run inside the same application process, with direct access to the audio streams and shared state. This makes them feel like natural parts of the experience rather than add-ons.

## The experience in detail

### Audio that routes itself

Every participant's microphone audio reaches every other participant -- but never loops back to the sender. On a traditional stack, this requires a selective forwarding unit that tracks which streams go where, plus ICE negotiation and TURN server fallbacks for network traversal.

On Ikon, the application describes the routing intent: send each participant's audio to everyone except themselves. The platform handles the actual transport. There is no signaling server to configure, no peer connection management, no media server to deploy.

### Speaker detection that feels natural

When someone starts talking, their indicator lights up immediately. When they pause between sentences, it stays lit. When they stop for real, it fades. This sounds simple, but getting it right is surprisingly subtle.

The app uses a technique where the volume tracker reacts quickly to increases (someone starts speaking) but decays slowly to decreases (a natural pause between words). The result is that the indicator snaps on instantly but does not flicker during normal speech cadence. A timeout catches the case where someone mutes or disconnects -- if no audio arrives for a couple of seconds, the indicator resets.

The entire speaker detection logic is two lines:

```csharp
float alpha = rmsVolume > state.EmaVolume ? EmaAlphaUp : EmaAlphaDown;
state.EmaVolume = (alpha * rmsVolume) + ((1 - alpha) * state.EmaVolume);
```

`EmaAlphaUp` is 0.4 -- reacts quickly when someone starts speaking. `EmaAlphaDown` is 0.03 -- decays slowly so brief pauses don't flicker the indicator off. Two numbers, one smooth experience.

This kind of detail is what separates a polished experience from a prototype, and the fact that the developer had time to get it right speaks to how much the platform handles elsewhere.

### Live transcription for every participant

Each participant gets their own dedicated speech recognizer. As someone speaks, their audio is piped through a silence filter (stripping dead air before it reaches the model) and segmented on natural silence boundaries. Recognized text flows into a shared transcript that every participant sees updated in real time.

The key insight here is that updating the shared transcript is the entire broadcast mechanism. The developer writes a new entry to the transcript list. Every connected participant's screen updates to show it. There is no event bus, no WebSocket broadcast code, no frontend subscription logic. Writing to shared state is the broadcast.

### AI summaries that build incrementally

A meeting that runs for an hour generates a lot of transcript. Sending the entire history to an AI model every time you want an updated summary would be wasteful and slow.

Instead, the app tracks what has already been summarized. Every 60 seconds, it checks whether new transcript entries or chat messages have arrived since the last summary update. If so, it sends only the new content to the AI along with the previous summary, asking it to integrate the new information. As the meeting progresses and the summary grows, the AI is instructed to filter out less important details -- creating a self-compressing meeting record that stays useful without growing unbounded.

## Three kinds of state, handled automatically

The app demonstrates three natural tiers of state, each handled differently:

**State everyone sees together.** The participant list, transcript entries, chat messages, and the AI-generated summary. When any of these change, every participant's screen updates. The developer simply declares these as shared values.

**State personal to each connection.** Whether your camera is on, which settings tab you have open, your chat input text, your device selections. Your camera toggle does not affect anyone else's camera state. The developer declares these as per-client values.

**State that follows a user across devices.** Theme preference, timezone, device type. If the same person connects from a laptop and a phone, both sessions pick up their preferences.

In a traditional stack, implementing these three tiers means building separate state management layers: shared stores with selective broadcasting, session-scoped state with connection affinity, and a user preferences database with cross-device sync. Here, the developer chooses the type of value, and the framework handles the rest.

## Multiuser as a natural consequence

It is worth returning to this point because it is the most revealing. The only place selective routing appears in this app is where it is semantically meaningful: audio is sent to everyone except the sender (to prevent echo), and video is sent to everyone including the sender (for self-view). Those are the domain-specific routing decisions.

Everything else -- transcripts, summaries, chat messages, the participant list, speaking indicators -- is shared automatically because it is declared as shared state. The developer never writes broadcast logic, never configures channels, never thinks about "how do I push this update to other participants." They update a value, and the platform ensures everyone sees it.

## What this demonstrates

The video conferencing app is a stress test for a platform: real-time media routing, multiple concurrent participants, live AI processing, three tiers of state, responsive layout across desktop and mobile. It exercises audio, video, speech recognition, AI orchestration, and reactive UI in a single application.

That all of this fits in under four thousand lines -- with configurable speech-to-text models, configurable AI models for summarization, device selection, screen sharing, theme switching, mobile layout detection, and meeting link generation -- says something concrete about what happens when the platform handles transport, rendering, and real-time sync. The developer's job reduces to the decisions that actually matter: how audio should be routed, how speech should be segmented, how summaries should be structured. The infrastructure disappears.
