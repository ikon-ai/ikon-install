# Not an API Wrapper — An AI Orchestration Engine

When someone starts building an AI-powered application, the journey usually begins the same way: pick a provider, wire up some calls, get responses back. It works for a prototype.

Then things get real. You want to try a different model. You need structured data back, not just raw text. You want the AI to use tools, or to run the same task several different ways and pick the best result. Suddenly you're building and maintaining an entire layer of plumbing you never planned for.

Ikon.AI takes a different approach. Instead of wrapping individual provider APIs, it gives you a unified orchestration engine that spans 30+ providers, 165+ models, and 14 capability categories — with production-ready multi-agent patterns built in.

## What this unlocks

The practical consequence is that one person can build AI applications that previously required a dedicated ML engineering team.

**Use many models in one app without juggling integrations.** A language learning app can use one model for conversation, another for pronunciation scoring, a third for generating lesson images, and a fourth for text-to-speech — all through the same library, the same error handling, the same streaming behavior. Switching any of those models is a one-word change.

**Production-grade AI workflows without the infrastructure.** The orchestration patterns described below encode workflows that AI teams at large companies spend months building from scratch — task decomposition, parallel execution, multi-perspective evaluation, iterative refinement. A solo creator gets these as composable building blocks.

**Benchmark and compare without rebuilding.** Because every pattern is provider-agnostic, you can run the same workflow against Claude, GPT-5, and Gemini, compare the results on quality, speed, and cost — then switch in production by changing a single value.

**The floor is low, the ceiling is high.** A haiku generator with AI-created illustrations is about 200 lines. A full language learning platform with 20+ voices, speech recognition, image generation, AI-driven conversation, and gamification — that uses the same library. The difference is how many patterns you compose and how many capabilities you combine, not how much infrastructure you set up.

## One interface, every model

At the simplest level, Ikon.AI lets you switch between any supported model by changing a single value. Want to try GPT-5 instead of Claude? Change one word. Gemini 3 Pro? One word. The interface stays identical — tool definitions, structured output, streaming, retry logic all adapt automatically to whatever provider you point at.

Here is what an AI call looks like — one line to run a model, get typed results back, and stream progress:

```csharp
var result = await Emerge.Run<Analysis>(LLMModel.Claude46Sonnet, context, pass =>
{
    pass.Command = "Analyze this dataset and identify trends";
}).FinalAsync();
```

Change `LLMModel.Claude46Sonnet` to `LLMModel.GPT5` and everything else stays the same — the prompt format, tool definitions, and response parsing all adapt automatically.

This isn't just convenience. The library knows the capabilities of every model — whether it supports streaming, parallel tool use, structured output, reasoning tokens, or image input. Your application doesn't need to know any of that. Ikon.AI handles the translation behind the scenes.

## Beyond text: 14 capability categories

Language models are just the beginning. Ikon.AI provides unified access across:

- **Image generation** — DALL-E, Imagen, FLUX, Gemini (21 models)
- **Video generation** — Sora, Veo, Runway, Kling, Luma, and more (18 models)
- **Speech synthesis** — OpenAI TTS, ElevenLabs, Google Chirp (13 models)
- **Speech recognition** — Whisper, Deepgram, AssemblyAI (9 models)
- **Embeddings** — OpenAI, Cohere, Google, Jina, Voyage (11 models)
- **Reranking** — Cohere, Jina, Voyage (5 models)
- **OCR** — Azure Document Intelligence, Mistral OCR
- **Classification** — Content moderation with score-level transparency
- **Web search and scraping** — Google, Bing, Jina, Spider
- **Video enhancement** — Upscaling and frame interpolation
- **Sound effects** — Text-to-sound synthesis
- **File conversion** — Document format transformation

Every category follows the same approach: you describe what you want, you get typed results back, streaming happens where it makes sense, retries are automatic, and nothing is tied to a specific provider. You learn the approach once and it applies everywhere.

## The real differentiator: Emergence patterns

Access to many models is table stakes. What sets Ikon.AI apart is **Emergence** — a library of 15+ composable orchestration patterns that solve the hard problems of building production AI workflows. These aren't theoretical — they're the patterns that show up again and again when you build real applications.

### Run the same task multiple ways, pick the best

**BestOf** runs several independent attempts with controlled randomness, scores each result, and returns the highest-scoring one. You describe what "good" looks like, and the system handles the parallel execution, collection, and ranking. No manual task management, no collecting results, no writing comparison logic.

```csharp
var (best, _) = await Emerge.BestOf<Solution>(model, context, opt =>
{
    opt.Count = 5;
    opt.Temperature = 0.8f;
    opt.Score = (solution, trace) => solution.Confidence;
}).FinalAsync();
```

Five attempts, scored by confidence, best one returned. That is the entire implementation.

### Multi-stage refinement

**SolverCriticVerifier** implements a draft-critique-verify loop. A solver produces a first attempt. A critic reviews it and suggests improvements. A verifier checks the final result. Each stage can use a different model and different settings. Context flows automatically between stages — the critic sees the solver's output, the verifier sees both. You define the stages; the framework handles the handoffs.

### Competing perspectives

**Debate** gives multiple agents different viewpoints and has them generate competing proposals. A judge synthesizes the best elements. Each participant works independently, which produces genuine diversity of thought rather than groupthink.

### Dependency-aware parallel execution

**TaskGraph** breaks a complex goal into subtasks, figures out which ones depend on each other, runs independent tasks in parallel, and respects blocking relationships. It can even revise the plan mid-execution if a review step identifies problems.

### And more

- **MapReduce** — distribute work across parallel agents, then combine into a final output
- **TreeOfThought** — branching exploration with pruning for complex reasoning problems
- **PlanAndExecute** — generate a step-by-step plan, then carry it out with tools
- **Router** — dynamically route queries to the best model or sub-agent for the job
- **EnsembleMerge** — diverse solvers produce independent answers, a merger synthesizes
- **Refine** — iterative improvement based on structured feedback
- **TestRefine** — an agentic loop that writes, tests, and fixes until the tests pass

These patterns are composable. A Router can delegate to a SolverCriticVerifier which uses BestOf internally. Budget controls propagate automatically. You spend your time on what the AI should do, not on how to wire up the orchestration.

## Everything streams

Every pattern emits progress as it happens — text appearing word by word, tool calls firing, stages transitioning, retries kicking in. You can build interfaces that show the user exactly what the AI is doing at every moment, not just a loading indicator followed by a wall of text. This is the foundation, not an add-on.

## Structured output without the headaches

Getting structured data out of an AI model usually means carefully writing prompt instructions, parsing responses, handling malformed output, and building retry logic for when things go wrong. With Ikon.AI, you define the shape of the data you want, and the library handles everything else — generating the right schema for the provider, parsing the response, validating the result. You describe what you want back, and you get it — typed and ready to use.
