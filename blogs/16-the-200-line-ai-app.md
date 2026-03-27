# The Two-Hundred-Line AI App

A platform's floor matters as much as its ceiling. If the simplest possible app requires boilerplate, configuration files, and ceremony before anything works, something has gone wrong. The floor tells you the truth about a platform's abstractions -- whether they actually reduce complexity or just redistribute it.

On Ikon, the simplest AI app is about two hundred lines. A haiku generator: you type a topic, it writes a haiku, generates a matching illustration, and displays both. That is the whole thing. One file. No separate frontend, no API routes, no environment variables, no client-side state management, no loading indicators you have to wire up yourself.

The same platform produces video conferencing apps, game generators, and animated characters with lip-synced speech. The range is the point.

## Two people, one haiku

The haiku generator is collaborative without any code written for that purpose. Two people open the app. One types "winter morning" and clicks generate. Both see the button change to "Creating..." Both see the haiku appear. Both see the illustration render. The person who did not click the button watched the whole thing happen in real time.

This is not a feature someone built. It is a consequence of the architecture. The app runs as a persistent process. Shared state updates reach every connected viewer automatically. The creator did not opt into collaborative behavior -- they would have to explicitly opt out of it for values that should be private to each person, like a theme preference.

For a haiku generator, this is a nice side effect. For a collaborative AI tool, a live dashboard, or a classroom application, it is the difference between a weekend project and a multi-month build.

## What the app actually does

You type a topic. The app sends it to an AI model, which writes a haiku following the traditional 5-7-5 syllable pattern and also produces a visual description capturing the haiku's mood. That visual description is then sent to an image generation model, which creates a matching illustration. Both the haiku and the image appear on screen as they are generated.

The app has six pieces of state: the topic you typed, the generated haiku, the image data, a flag tracking whether generation is in progress, and a per-user theme preference (light or dark mode). When any shared value changes, the interface updates for every connected viewer. The theme preference is per-person -- one viewer can switch to dark mode without affecting anyone else.

The interface is declared in the same file as the logic. A text field for the topic. A generate button that disables itself and changes its label during generation. A results area that appears when there is something to show. The title has a wave animation where each letter bounces in a staggered loop. All styling uses utility classes -- no separate style files.

The entire AI orchestration — generating a haiku and a matching illustration — is this:

```csharp
private async Task GenerateHaikuAndImageAsync()
{
    _isGenerating.Value = true;
    _generatedHaiku.Value = null;
    _generatedImageData.Value = null;

    try
    {
        var haikuResult = await GenerateHaikuAsync(_topic.Value);
        _generatedHaiku.Value = haikuResult.Haiku;

        var imagePrompt = $"{_topic.Value}. {haikuResult.ImagePrompt}";
        await GenerateImageAsync(imagePrompt);
    }
    finally
    {
        _isGenerating.Value = false;
    }
}
```

Clear the previous results. Generate a haiku. Use its mood to generate an image. Reset the loading state. Every value change updates every connected viewer's screen automatically. That is the complete orchestration layer.

That is everything. About two hundred lines total.

## What is present, what is absent

The interesting thing about this app is not what it contains but what it does not.

Present: reactive state that automatically synchronizes across viewers, a way to call an AI model and get structured results back, a way to generate images, a way to display it all in a styled interface. These are the actual substance of the application.

Absent: project scaffolding, build configuration, client-server communication setup, API route definitions, environment variable management, real-time infrastructure, state synchronization code, loading state plumbing, error boundary boilerplate, image proxy endpoints. These are absent because they are not the application -- they are the cost of the architecture that most platforms impose.

## The traditional stack equivalent

Building the same app on a conventional stack requires assembling a surprising number of pieces for something this simple.

You need a project scaffold with configuration files before you write any application code. You need at least two API endpoints -- one for the AI call, one for image generation -- each with its own error handling and response formatting. You need to install and configure provider libraries, manage API keys, and handle them differently in development versus production.

On the client side, you need state variables for loading, the haiku, the image, and the topic. You need to write data fetching calls, handle loading and error states in the interface, and manage the lifecycle of two sequential network requests from the browser.

The minimum viable version -- no authentication, no persistence, no error retry -- is probably three to five files and around four hundred lines split across frontend and backend. More importantly, it requires thinking about two execution environments (browser and server), data serialization between them, and the lifecycle of cross-network calls.

And it is single-user. If two people open the page, they each get independent instances. Making them see the same haiku requires adding real-time communication infrastructure and a shared state store -- effectively doubling the complexity.

## The floor and the ceiling

The same platform that runs this two-hundred-line haiku generator also runs a video conferencing app with live transcription and AI meeting summaries. It runs a game generator that produces playable browser games from text descriptions, play-tests them automatically, critiques the results with vision models, and iterates until quality converges. It runs animated characters with lip-synced speech and reactive facial expressions.

None of those apps pay a framework tax for the platform's simplicity at the low end, and the haiku generator does not pay a framework tax for the platform's power at the high end. The building blocks are the same: reactive state, server-driven interface, AI orchestration, structured output. A haiku generator uses one AI call and one image generation call. A game generator uses AI calls with tool use, automated browser testing, and a convergence loop. The vocabulary is the same. The grammar scales.

This matters because platforms that optimize for the ceiling often neglect the floor. They provide powerful abstractions for complex use cases, but the simplest app still requires significant setup and conceptual overhead. Going the other direction is equally common -- platforms that optimize for quick starts hit a hard wall when complexity grows. The abstractions that made the simple case easy become obstacles when you need real-time collaboration, long-running processes, or multi-model AI orchestration.

A haiku generator should be about two hundred lines. A video conferencing app should be about four thousand. The ratio between those numbers should reflect the actual difference in complexity between the two applications -- not the overhead of the platform.

## What the floor reveals

The haiku generator is not a useful application. Nobody needs a platform to generate haiku. But it is a useful diagnostic. It tells you what the platform considers essential and what it considers incidental.

Two hundred lines is not a marketing number. It is a measurement of what remains when the incidental complexity is removed.
