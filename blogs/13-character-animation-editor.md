# A Character Animation Editor for AI Video

Imagine defining a character's expressions -- happy, angry, thinking -- uploading a reference image for each, and having AI generate looping animation videos for every expression and smooth transition videos between every pair of them. That is what this editor does. The result is a complete set of character animations, ready to drive an interactive character that can shift between moods on command.

The entire application logic -- state management, prompt generation, image processing, video generation across six providers, bulk generation, cloud persistence, and the full editing interface -- is under eleven hundred lines. One project. No separate backend, no job queue, no image processing service.

## What you can do with it

The editor is built around two concepts: **states** and **transitions**.

A **state** is a character expression. You give it a name ("happy," "angry," "thinking"), upload a reference image, and the system can generate a looping animation -- a short video of the character in that expression with subtle idle motion like breathing, blinking, or a slight sway.

A **transition** connects two states. It is a video showing the character moving from one expression to another -- the shift from angry to happy, or from thinking to surprised.

When you add a new state, the editor automatically creates transition slots for every pair. If you already generated a video for "happy to angry," adding a third state preserves that work. Three states produce six transitions. Four states produce twelve. The combinatorial growth is the reason bulk generation exists.

## Collaboration built in

Multiple people can work in the same editor simultaneously. One person uploads a reference image, and everyone else sees the thumbnail appear. Someone starts a bulk generation, and all viewers watch the progress indicators update in real time. There is no setup for this -- it is how the platform works by default.

The generation continues even if everyone disconnects. You can start a sixteen-video bulk generation, close the browser, and come back later to find everything done and saved.

## AI writes the video prompts for you

You do not need to know how to write prompts for video generation models. The editor handles that.

When you hit "Generate Loop" on a state, the system sends the reference image and the state name to an AI, which produces a short animation description tailored for video generation. A character description field in the settings gives the AI consistent context -- something like "a small cartoon fox with orange fur, standing on hind legs" -- so framing stays coherent across the entire set of animations.

Every generated prompt includes an instruction that the character must stay fully in frame with no camera movement or zoom. Video generation models tend toward cinematic camera moves unless explicitly told not to, and a loop video where the character drifts off-screen is useless.

Transition prompts work the same way but describe the movement between two expressions rather than idle motion.

## Smart image handling

Video generation models expect specific aspect ratios. Character reference images come in arbitrary dimensions. Rather than cropping -- which risks cutting off the character -- the editor pads the image to fit. The padding color is sampled from the four corners of the original image and averaged, producing a background that blends naturally rather than introducing a hard border. It is a small detail, but it matters -- a jarring border in the reference image propagates directly into the generated video.

## Six video generation models, one dropdown

The settings panel offers a dropdown with six different video generation models. You pick one and generate. The same setup -- prompt, video length, aspect ratio, input images -- goes to whichever model you choose.

This matters because video generation models have wildly different characteristics. Some handle character consistency better. Some produce smoother motion. Some are faster. Being able to generate the same transition with multiple models and compare results -- without changing anything except a dropdown selection -- is the practical use case. On a traditional stack, integrating six video generation providers would mean six separate integrations, six authentication setups, six response format handlers, and a layer to normalize them all. Here it is a menu selection.

## Bulk generation

For a four-state character, you need four loop videos and twelve transition videos. Generating them one at a time would be tedious. The "Generate All" buttons fire all pending generations at once. Each one updates its own progress indicator in real time -- you see items tick from "Generating..." to complete as they finish. If one fails, the rest keep going.

## Cloud persistence

Everything saves automatically. Every time you add a state, rename one, upload an image, or complete a generation, the project saves to the cloud. Images and videos are stored separately as files, so the project stays lightweight. When you reopen the editor, everything is exactly where you left it.

## State machine playback

The preview area is not just a gallery of thumbnails. Click "happy" while the character is in "angry," and the editor plays the angry-to-happy transition video, then seamlessly switches to the happy loop. If there is no transition video yet, it jumps directly to the loop. If there is no loop video, it shows the static reference image. The experience degrades gracefully based on what has been generated so far.

The state switching logic is straightforward — find the transition video, play it, then switch to the loop:

```csharp
private async Task SwitchToState(string targetStateId)
{
    var transition = _transitions.Value.Find(t =>
        t.SourceStateId == currentStateId && t.TargetStateId == targetStateId);

    if (transition?.VideoUrl != null)
    {
        _playingVideoUrl.Value = transition.VideoUrl;
        await Task.Delay(TimeSpan.FromSeconds(_videoLength.Value));
    }

    if (targetState.LoopVideoUrl != null)
    {
        _playingLoop.Value = true;
        _playingVideoUrl.Value = targetState.LoopVideoUrl;
    }
}
```

Play the transition, wait for it to finish, start the loop. The reactive values update the video player automatically for every connected viewer.

## What would this normally require?

Building this as a standalone application would mean assembling several independent systems: a visual editor for creating states and transitions, an image processing service for padding images to the right aspect ratios, six separate video generation integrations, an AI pipeline for writing prompts, a job queue for managing long-running video generations, cloud storage for assets, a database for project state, and real-time infrastructure for pushing progress updates to connected viewers.

When the platform provides the integration -- multi-model AI, reactive state, cloud persistence, asset storage, in-process image manipulation -- what remains is the state machine logic, the prompt design, and the aspect ratio math. Just the part where a character gains expressions and learns to move between them.
