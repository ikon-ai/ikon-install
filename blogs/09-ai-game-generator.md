# Building an AI Game Generator

Describe a game in plain English -- "a space shooter where you dodge asteroids and collect fuel cells" -- and out comes a playable browser game. Not a mockup. Not a wireframe. A finished game with a title screen, a game loop, collision detection, score tracking, particle effects, and neon glow aesthetics. Then the system play-tests the game itself, critiques the result, and iterates until the game meets quality thresholds.

The whole thing is under five thousand lines. One project. No separate backend. No job queue. No cluster of services. Here is what we learned building it, and why this kind of system is now within reach.

## What you get: describe, generate, play

A user types a game concept. The system thinks about it, builds it, tests it, judges its own work, and fixes the weakest areas -- automatically, in a loop. A few minutes later, the game is ready to play in the browser. Every step of the process is visible in real time: you can watch the system generate, test, critique, and iterate as it happens.

Multiple people can watch the same generation unfold simultaneously. One person kicks off a build, others see the progress live -- iteration counts ticking up, test screenshots appearing, scores improving. If everyone closes their browser and comes back later, the finished game is waiting. The system keeps working whether anyone is watching or not.

## Multiuser for free

This deserves emphasis early, because it is not a feature anyone built. It is a consequence of how the platform works. Because the app runs as a persistent server process with shared reactive state, every connected user automatically sees the same game library, the same generation progress, the same test results -- updated live. No WebSocket server, no event bus, no pub/sub layer. When the status changes to "Iteration 3 of 5 -- play testing," every connected browser sees it instantly.

## Plan first, then build

The generator does not jump straight into writing game code. It first produces a game design document: title, core mechanics, visual design, game objects, level design, HUD layout, polish details. This plan becomes the reference point for everything that follows.

The plan matters because without it, the quality loop has nothing to compare against. "Is this game good?" is subjective. "Does this game implement the mechanics described in the plan?" is measurable. Every critique and every fix traces back to what was promised in the design document.

## How code generation works

Once the plan exists, an AI model builds the game piece by piece. Rather than producing one giant blob of code, it writes into named sections -- styles, layout, configuration, entities, logic, rendering, input handling, game loop. This modular approach means the critique loop can pinpoint which section needs improvement and target fixes precisely.

The model can also read back what it previously wrote, so it can review its own work before moving on. The output is a single self-contained file that runs directly in a browser frame -- no build step, no dependencies, no bundler.

Multiple AI providers are supported, and switching between them is a single configuration change. The same generation process works across all of them.

## Automated QA: the system plays its own games

Generating code is the easy part. Knowing whether the code actually works is the hard part.

After each generation round, the system launches a headless browser and runs the game through multiple test phases -- the start screen, early gameplay, sustained input. Two complementary testing approaches work together:

A metrics harness measures everything quantitative: frame rate, whether frames are actually changing, whether the score counter works, whether input handlers are responding, and whether any errors occur.

An AI vision model looks at screenshots of the running game and decides what to do next -- click the start button, press arrow keys, wait for something to happen, or declare the test complete. It reports what it sees at each step. This catches problems that pure metrics miss: a game that technically runs at full speed but shows a blank screen, or a score counter that displays "NaN."

The two approaches complement each other. The vision model catches visual problems. The metrics catch invisible ones -- like a game that looks correct in a screenshot but actually rendered once and froze.

## Four-tier quality framework

After testing, a structured critique scores the game against the original plan across seven dimensions, which roll up into four tiers:

- **Functional** -- does the game run without errors and respond to input?
- **Visual** -- do the visual elements, HUD, and game objects match what was planned?
- **Gameplay** -- do the mechanics, progression, and collision detection work?
- **Polish** -- are particle effects, animations, and "juice" present?

The iteration loop targets the lowest-scoring tier for improvement. Functional issues always get priority -- there is no point refining particle effects on a game that crashes on load. Each fix prompt is narrow and specific: address only the identified issues, make the smallest possible change, do not rewrite unrelated sections.

Convergence means all section scores are above 75% and the functional score is above 50%. The loop runs up to five rounds by default. Many games converge in two or three.

## The convergence loop

The entire generation-test-critique loop is a `for` loop:

```csharp
for (int i = 1; i <= maxIterations; i++)
{
    _statusText.Value = $"ITERATION {i}/{maxIterations} - GENERATING...";

    (html, resultSections) = await RunAgenticCodeGenAsync(...);
    _currentGameHtml.Value = html;

    var testResult = await RunLLMGuidedTestAsync(html, testGoal, plan, 6);
    var structured = await RunStructuredCritiqueAsync(plan, testResult, testResult.HarnessReport);

    if (CheckConvergence(structured))
    {
        _statusText.Value = "CONVERGED - ALL SECTIONS ABOVE THRESHOLD";
        break;
    }

    iterationTarget = SelectIterationTarget(structured);
}
```

Generate. Test. Critique. Target the weakest area. Repeat. Each step updates the UI in real time. The loop is cancellable at any point.

## What you would normally need

Building an equivalent system on a traditional stack would mean assembling and maintaining several independent services: code generation backends with multiple AI provider integrations, a sandboxed execution environment for safely running generated code, headless browser infrastructure for testing, an AI evaluation pipeline for feeding screenshots back to vision models, a prompt management framework, file storage for game libraries and version histories, and job orchestration with progress tracking for loops that run for minutes at a time.

On the Ikon platform, all of these collapse into one project. AI orchestration handles multi-model calls. The persistent app process handles long-running generation loops. Reactive state handles live UI updates. The asset system handles storage. The headless browser runs in the same process.

## The meta observation

This is an AI tool that generates software, built on an AI platform. It orchestrates multiple AI models across multiple roles -- planner, coder, tester, critic -- in a convergence loop with real-world validation between each cycle.

The interesting lesson is not that AI can generate games. It is that the distance between "I can call an AI" and "I have a production system that generates, tests, critiques, and iterates on generated software" is almost entirely infrastructure. The AI calls themselves are straightforward. The hard part is the scaffolding: running untrusted code safely, capturing runtime metrics, feeding visual output back to evaluator models, maintaining state across a multi-step loop, pushing live progress to users, persisting results.

When the platform provides that scaffolding, what remains is the domain logic. How should games be structured? What makes a good critique? When should the loop stop? Those are design questions, not infrastructure questions. And they are the only questions that matter.
