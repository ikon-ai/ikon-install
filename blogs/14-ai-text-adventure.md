# Building an AI Text Adventure

We built a scored narrative game where you investigate surreal crime scenes, interrogate witnesses, and try to deduce hidden universal laws. Every playthrough is different -- the AI generates the accusations, the scenes, the witnesses, and the imagery on the fly. The whole thing is under a thousand lines.

This post is about how it creates a compelling experience from several AI capabilities working together, and why the design stays small.

## What it feels like to play

You are put on trial by a cosmic judge for abstract, metaphysical crimes -- things like "The Hoarding of Silence" or "The Weaponization of Nostalgia." Each crime was committed against a hidden universal law that you do not know. You are transported to a surreal scene -- a place where every object, every witness, every detail is a physical metaphor for that hidden law. Your job is to figure out what the law is.

You get five actions per round to investigate. You can examine objects, ask witnesses questions, reflect on what you have seen, look around for new details, or propose your theory of the hidden law. Three rounds total, each with a different crime and scene, scored and summed at the end.

## The world responds to how well you are thinking

This is the design detail that makes the game feel alive. The scene image -- a generated illustration of the surreal location -- changes as you get closer to the truth.

At the start of each round, the scene is dark and foggy, details barely visible. As you ask the right questions and examine the right objects, the AI tracks how close your line of inquiry is to the hidden law. When you cross a threshold, the image regenerates. Fog lifts. Amber light breaks through. Details sharpen. If you are close to the truth, the scene becomes radiant and golden, every element crystal clear.

The atmosphere is driven by a single proximity value — how close you are to the truth:

```csharp
var atmosphereSuffix = proximity switch
{
    < 0.3f => ", dark and obscured atmosphere, thick fog, deep shadows, mysterious and foreboding, barely visible details",
    < 0.6f => ", partially illuminated, some fog lifting, amber light breaking through, details becoming clearer",
    _ => ", radiant and illuminated, crystal clear details, golden light, truth revealed in every element"
};
```

Below 0.3, darkness and fog. Between 0.3 and 0.6, amber light breaking through. Above 0.6, golden radiance. Three tiers of visual mood, each appended to the image generation prompt.

The effect is that the game world visually rewards good reasoning. You can feel yourself getting warmer -- not through a score counter, but through the atmosphere of the world itself.

## Spectators watch the investigation unfold

Because the game runs as a persistent process with shared state, multiple people can connect and watch the same trial. One person plays. Others spectate. Everyone sees the same transcript, the same scene images, the same atmosphere shifting in real time as the investigation progresses.

When the player examines a witness and the fog lifts, every connected viewer sees the new image appear. A group of people watching someone reason through a surreal crime scene, seeing the world brighten as understanding grows -- that is the kind of experience that normally requires dedicated real-time infrastructure. Here it requires no additional code at all.

## How each round works

At the start of each round, the AI generates everything fresh: an abstract crime, a hidden universal law that was violated, a surreal scene where every element is a physical metaphor for the law, three witnesses who are part of that metaphor, and a list of objects you can examine. The AI also knows the hidden connections between scene elements and the law -- but you never see those. You have to work them out.

Earlier rounds are fed back to the AI so it avoids repeating themes across the trial.

## A five-command vocabulary

During investigation, you have five actions. Each command type produces a different kind of response from the AI:

- **Examine** -- describes observable clues about an object or element in the scene
- **Ask** -- a witness responds in character, dropping hints through their perspective
- **Reflect** -- philosophical musing that connects scene elements you have encountered
- **Look** -- reveals new details in the environment you had not noticed before
- **Propose** -- put forward your theory of the hidden law

Each response also includes the AI's assessment of how close you are to the truth -- a proximity score that drives the atmospheric changes described above.

## Judgment with partial credit

When you propose a theory (or run out of actions), the AI judges your proposal against the actual hidden law. This is not pass/fail. A player who identifies the right general area but misses the specific principle might score partial credit. The system tracks results across all three rounds and delivers a final verdict with different narrative responses based on your total performance.

## What would this normally require?

Building this as a standalone application would require several independent systems: an AI orchestration layer for managing multiple types of AI calls (generating accusations, narrating investigations, judging proposals), an image generation service that responds to game state, a state management system tracking phase, round, actions, proximity, transcript, and results across a multi-step session, real-time infrastructure for pushing updates to spectators, and a frontend application with components for the transcript, image display, proximity indicator, input field, and verdict screen.

On the Ikon platform, all of these collapse into methods on a single class that share the same process, the same state, and the same lifecycle. The distance between "the player examined the broken clock" and "the scene image regenerates with amber light breaking through fog" is a single method call and a value update.

## The design insight

The interesting thing about this game is not that it uses AI. It is how many distinct AI patterns it combines in a small space.

There is structured generation -- creating accusations with specific fields and relationships. There is contextual generation -- investigation responses that track the full transcript and adjust based on how close you are to the answer. There is evaluation -- judgment with partial credit scoring against a hidden answer. And there is image generation that responds dynamically to game state.

In a traditional architecture, each of these would likely be a separate service or module with its own integration. Here they are methods in the same file. The accusation generator, the investigation narrator, the judge, and the image generator share the same process and the same state. That proximity -- the ability to compose different AI capabilities without integration boundaries -- is what lets the game feel cohesive rather than stitched together.

Under a thousand lines for a complete scored narrative game with generated imagery, five distinct command types, proximity-driven atmosphere, multi-round progression, and a final verdict system. Not because the code is compressed, but because the infrastructure that would normally dominate the effort simply is not there. It was already provided.
