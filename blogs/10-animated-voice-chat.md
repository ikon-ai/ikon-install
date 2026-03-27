# Animated Voice Chat with Live2D Characters

Talk to an animated character. It listens, thinks, and responds with lip-synced speech -- mouth shapes perfectly matched to every syllable, expressions shifting with the conversation. You can interrupt it mid-sentence and the character gracefully stops talking. Stack audio effects on the voice -- reverb, robot filter, telephone crackle -- and tweak them live while the character speaks. Choose from five characters and three camera angles. Multiple people can join the same conversation simultaneously.

All of this runs as about twelve hundred lines in a single project. Here is what that means and how it works.

## What you experience

You press a button and start talking. Your voice is captured, transcribed, and sent to an AI that generates a conversational response. That response is converted to speech, and the animated character delivers it with synchronized lip movements. The whole cycle -- speak, transcribe, think, reply, animate -- happens in one continuous flow, with no perceptible gaps between services because there are no gaps. Everything runs in a single process.

Five character models are available, each with its own personality in the animation. Three camera angles let you frame the conversation: full body, portrait, or close-up on the face. Each character needs different framing adjustments at each zoom level because every artist rigs their model differently -- what looks right as a portrait for one character needs completely different settings for another.

## Multiuser by default

This deserves attention up front because it shapes how you think about the app. Multiple people can connect and talk to the same character, see each other's messages, and hear the same voice. When one person changes the character model or adds an audio effect, every connected user sees the change immediately.

No additional code was written for this. It is a property of the platform's architecture. The server maintains the shared state, and every connected client receives updates automatically. This means the app works as a group experience without modification -- a team can gather around a shared character conversation, or a presenter can demonstrate the voice interaction while an audience watches on their own screens.

## Two ways to listen

The app supports two speech recognition modes, and the difference matters for the feel of the interaction.

**Batch mode** waits for you to finish speaking, then processes the entire recording at once. You press a button, say your piece, release, and the transcription appears. This is clean and predictable -- good for deliberate, turn-based conversation.

**Continuous mode** streams your speech to the recognizer as you talk, producing partial transcriptions in real time. You see your words appearing as you say them. For recognizers that do not natively support continuous input, the system uses silence detection to segment the audio -- it listens for half-second pauses to identify natural sentence boundaries.

The bridge between the microphone input (which arrives frame by frame) and the recognizer (which wants a continuous stream) is handled by a message queue that accumulates audio frames and feeds them to the recognizer at its own pace. When you stop talking, the queue closes and the recognizer finishes naturally.

## Smooth interruption

When you start talking while the character is still speaking, the app handles it gracefully. The character's voice fades out smoothly rather than cutting off abruptly. The speech generation is cancelled. Your microphone activates. There is no jarring audio pop or awkward silence -- just a natural-feeling handoff from the character's turn to yours.

The entire interruption handler is three lines:

```csharp
Audio.SpeechMixer.FadeOut();
StopSpeaking();
_sttIsToggleRecording.Value = true;
```

Fade the character's voice, cancel the speech generation, start listening. On a traditional stack, coordinating audio output, speech cancellation, and microphone activation across multiple services would be a significant engineering effort.

## Orderly conversation

User messages do not go directly to the AI. They go through a queue that processes them one at a time, in order. This prevents the situation where someone sends multiple messages quickly and the AI responses overlap or the speech outputs stack on top of each other. Each message waits for the previous response to finish speaking before the next one begins. The conversation stays coherent and natural.

## Lip sync that never drifts

The character's mouth movements are driven by viseme data -- information about what mouth shape corresponds to each moment of audio. The key design decision is that this data is embedded directly into the audio stream itself. It travels with the sound it describes, so the character's mouth is always perfectly in sync regardless of network conditions, buffering, or latency.

There is no separate channel for lip sync data, no timestamp-based synchronization between audio playback and mouth animation. The mouth shape information arrives in the same packet as the audio it matches. This is why the lip sync never drifts.

The character itself is rendered as a Live2D model -- a 2D illustration that moves and emotes in real time using WebGL. The server controls which model is loaded, what expression is shown, and what motion is playing. The client handles the rendering.

## Eight chainable audio effects

The app includes eight audio effects that can be stacked and adjusted in real time: Delay, Reverb, Chorus, Tremolo, BitCrusher, Saturation, RobotVoice, and Telephone. Each has its own set of parameters.

These are real audio processing algorithms -- delay lines with feedback and damping, Schroeder reverb, ring modulation for the robot voice, bandpass filtering for the telephone effect. You can layer Reverb on top of RobotVoice on top of Telephone and adjust each one's parameters while the character is speaking. Tweaking a slider immediately changes how the next audio chunk sounds.

The effects are applied on the server before the audio reaches the client, so there is no processing cost on the user's device. On a traditional stack, this would either be a browser-based audio processing chain (with all the complexity of the Web Audio API) or a separate audio processing service with its own protocol for parameter updates. Here it is a list of effects passed to the audio output.

## What would normally be six-plus services

Consider what building this on a conventional web stack would require:

**Audio transport**: a protocol for bidirectional audio streaming, codec negotiation, jitter buffering, echo cancellation.

**Speech services**: separate speech-to-text and text-to-speech services, each with their own setup, authentication, and error handling. A message broker between them and the application.

**AI conversation**: an API client with streaming support, conversation history management, and retry logic.

**Character rendering**: a WebGL canvas with the Live2D SDK, a connection for receiving model parameters from the server, timestamp synchronization between audio playback and mouth animation.

**Audio processing**: a real-time audio effects pipeline with dynamic parameter updates.

**State management**: a store for conversation history, audio stream state, effect parameters, model selection, and view mode. Synchronization between server and client. Race condition management for concurrent audio streams and AI calls.

**Multiuser support**: additional channels, presence management, state synchronization between connected clients.

Each of those is a separate integration surface, a separate category of bugs, and a separate thing to maintain. Here, they are all part of the same twelve hundred lines.

## The actual scope

Twelve hundred lines for a voice-driven animated character app with five selectable models, three camera angles, dual speech recognition modes, smooth speech interruption, eight chainable audio effects with live parameter control, orderly conversation management, viseme-driven lip sync, and built-in multiuser support.

The ratio of capability to code is not the result of hiding complexity behind a thin wrapper. The audio effects are real signal processing. The speech recognition supports both batch and continuous modes with silence detection. The message queue handles concurrency correctly. The viseme data is embedded in audio frames for drift-free lip sync.

The ratio exists because the platform eliminates the integration work. There is no glue code between the speech recognizer and the AI. There is no protocol for streaming audio parameters. There is no state synchronization layer between server and client. There is no separate infrastructure for multiuser support. Each of those would be hundreds or thousands of lines on a conventional stack, and none of them would be the interesting part of the application.

The interesting part -- the part where a character listens to you, thinks, and responds with lip-synced speech through a robot voice filter while someone else watches -- that part is the twelve hundred lines you actually write.
