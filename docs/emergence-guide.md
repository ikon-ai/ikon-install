# Ikon.AI.Emergence Guide

Ikon.AI.Emergence is a streaming-first, C#-idiomatic library for building AI workflows with typed JSON outputs. It provides a collection of patterns for common AI tasks, from simple single-shot generation to complex multi-agent orchestration.

## Core Concepts

### Streaming-First Design

All APIs return `IAsyncEnumerable<EmergeEvent<T>>`. Non-streaming usage is achieved via the `.FinalAsync()` extension method.

```csharp
// Streaming - observe progress
await foreach (var ev in Emerge.Run<MyType>(model, ctx, pass => { ... }))
{
    switch (ev)
    {
        case ModelText<MyType> t: Console.Write(t.Text); break;
        case ToolCallPlanned<MyType> tc: Console.WriteLine($"Calling {tc.Call.Function.Name}"); break;
        case Completed<MyType> done: Console.WriteLine($"Result: {done.Result}"); break;
    }
}

// Non-streaming - just get the result
var (result, context) = await Emerge.Run<MyType>(model, ctx, pass => { ... }).FinalAsync();
```

### Event Types

| Event | Description |
|-------|-------------|
| `ModelText<T>` | Streaming text chunk from the model |
| `ToolCallPlanned<T>` | Tool call detected (contains `FunctionCall`) |
| `ToolCallResult<T>` | Tool execution completed (contains `FunctionCall`, `StreamingResult[]`, result) |
| `Stage<T>` | Pattern stage boundary (e.g., "Solver", "Critic") |
| `Progress<T>` | Progress message |
| `Retry<T>` | Retry attempt (contains `Reason`, `AttemptNumber`, `MaxAttempts`) |
| `TokenUpdate<T>` | Token usage update (contains `InputTokens`, `OutputTokens`) |
| `Completed<T>` | Final result with `Result`, `Context`, and `Trace` |
| `Stopped<T>` | Execution stopped (budget exceeded, user stop, etc.) with optional `Reason` |

### Typed JSON Output

All patterns produce typed results. The library automatically generates JSON schemas and examples for your types:

```csharp
public class AnalysisResult
{
    public string Summary { get; set; } = "";
    public List<string> KeyPoints { get; set; } = [];
    public float Confidence { get; set; }
}

var (result, _) = await Emerge.Run<AnalysisResult>(model, ctx, pass =>
{
    pass.Command = "Analyze the following text and provide structured output.";
}).FinalAsync();

// result.Summary, result.KeyPoints, result.Confidence are typed
```

### Configuration Inheritance

Pattern options inherit from `EmergeScopeBase`. Child scopes (like `InitialScope`, `RefinementScope`) inherit settings from the parent unless overridden:

```csharp
await Emerge.Refine<T>(model, ctx, opt =>
{
    // Parent settings - inherited by all scopes
    opt.Temperature = 0.3f;
    opt.SystemPrompt = "You are an expert...";

    opt.Initial(s =>
    {
        // Only set what's different
        s.Command = "Generate initial draft.";
    });

    opt.Refinement(s =>
    {
        s.Temperature = 0.2f;  // Override for refinement
        s.Command = "Improve the draft.";
    });
}).FinalAsync();
```

### Context Behavior

Patterns handle context in two ways:

- **Shared context**: Sequential stages (Solver→Critic→Verifier, Refine iterations) share context. Each stage's output is automatically added to context before the next stage runs.
- **Isolated context**: Parallel runs (BestOf candidates, MapReduce chunks, Swarm agents) use isolated derived contexts to ensure deterministic parallel execution.

---

## Patterns

### Run — Single Agent Loop

The core pattern. Generates a typed JSON result with optional tool use.

```csharp
var (result, ctx) = await Emerge.Run<ChatResponse>(LLMModel.Claude45Sonnet, context, pass =>
{
    pass.SystemPrompt = "You are a helpful assistant.";
    pass.Command = "Answer the user's question.";
    pass.Temperature = 0.7;
    pass.MaxIterations = 5;
    pass.AddTool("search_web", "Search the web for information",
        (string query) => SearchWeb(query));
}).FinalAsync();
```

The `EmergePass<T>` configure callback is invoked on every iteration, giving access to runtime state:

- `pass.Iteration` — current iteration number
- `pass.HasFunctionResults` / `pass.HasNewFunctionResults` — whether tool results exist in context
- `pass.Stop(reason?)` — early termination from within the callback

**Options:**
- `SystemPrompt` - System instruction
- `Command` - User command/prompt
- `Temperature`, `MaxOutputTokens`, `ReasoningEffort`, `ReasoningTokenBudget` - Model parameters
- `MaxIterations`, `MaxToolCalls`, `MaxWallTime` - Budget limits
- `MaxRetries`, `RetryDelay` - Automatic retry on transient failures
- `Tools` - Available tools (see [Inline Tool Registration](#inline-tool-registration))

---

### BestOf — Score and Select Best

Run N independent attempts and select the best result based on a scoring function.

```csharp
var (best, _) = await Emerge.BestOf<Answer>(LLMModel.Claude45Sonnet, ctx, opt =>
{
    opt.Count = 5;
    opt.Command = "Solve this problem step by step.";
    opt.Score = (answer, trace) => answer.Confidence * (1f / trace.Duration.TotalSeconds);

    opt.Candidate(c =>
    {
        c.Temperature = 0.7 + 0.1 * c.Index;  // Vary temperature per candidate
        c.Seed = 1000 + c.Index;
    });
}).FinalAsync();
```

**Options:**
- `Count` - Number of candidates (default: 3)
- `Score` - Scoring function `Func<T, EmergenceTrace, double>`
- `Candidate(Action<CandidateScope<T>>)` - Configure each candidate (has `Index`, `Seed`)

**Context flow:** Each candidate runs with an isolated derived context.

---

### ParallelBestOf — Parallel Score and Select

Like BestOf but explicitly parallelized with concurrency control.

```csharp
var (best, _) = await Emerge.ParallelBestOf<Answer>(LLMModel.Claude45Sonnet, ctx, opt =>
{
    opt.Count = 10;
    opt.MaxParallel = 4;  // Run 4 at a time
    opt.Command = "Generate a creative solution.";
    opt.Score = (answer, _) => ScoreAnswer(answer);
}).FinalAsync();
```

**Options:**
- `Count` - Number of candidates (default: 3)
- `MaxParallel` - Concurrency limit (default: 4)
- `Score` - Scoring function

---

### SolverCriticVerifier — Draft, Critique, Verify

Three-stage pattern: generate a draft, critique it, then produce a verified final version.

```csharp
var (final, _) = await Emerge.SolverCriticVerifier<Report>(LLMModel.Claude45Sonnet, ctx, opt =>
{
    opt.MaxRounds = 2;

    opt.Solver(s =>
    {
        s.Temperature = 0.8;
        s.Command = "Draft a comprehensive report on the topic.";
    });

    opt.Critic(c =>
    {
        c.Temperature = 0.3;
        c.Command = "Review this draft. List factual errors, logical gaps, and areas for improvement.";
    });

    opt.Verifier(v =>
    {
        v.Temperature = 0.4;
        v.Command = "Produce the final report addressing all critique points.";
    });
}).FinalAsync();
```

**Options:**
- `MaxRounds` - Number of solver→critic→verifier cycles (default: 1)
- `Solver(Action<EmergeScope<T>>)` - Configure the draft generator
- `Critic(Action<EmergeScope>)` - Configure the critic (untyped output)
- `Verifier(Action<EmergeScope<T>>)` - Configure the final verifier

**Context flow:** Solver output is automatically added to context before Critic runs. Critic output is added before Verifier runs.

---

### DebateThenJudge — Multiple Perspectives

Multiple debaters generate competing proposals, then a judge selects or synthesizes the best.

```csharp
var (final, _) = await Emerge.DebateThenJudge<Decision>(LLMModel.Claude45Sonnet, ctx, opt =>
{
    opt.Debaters = 3;
    opt.DebateRounds = 1;

    opt.Debater(d =>
    {
        d.Temperature = 0.9;
        d.Command = $"As debater {d.Index}, argue for your position on this issue.";
    });

    opt.Judge(j =>
    {
        j.Temperature = 0.3;
        j.Command = "Review all arguments. Synthesize the best points into a final decision.";
    });
}).FinalAsync();
```

**Options:**
- `Debaters` - Number of debaters (default: 2)
- `DebateRounds` - Rounds of debate (default: 1). Each round, debaters receive previous round arguments in context.
- `Debater(Action<AgentScope<T>>)` - Configure debaters (has `Index`, `Role`, `Seed`)
- `Judge(Action<EmergeScope<T>>)` - Configure the judge

**Context flow:** Debaters run with isolated contexts. After all debaters complete, the Judge receives all arguments in context.

---

### MapReduce — Chunk Processing

Split input into chunks, process each in parallel, then reduce to a final result.

```csharp
var (report, _) = await Emerge.MapReduce<ChunkSummary, FinalReport>(LLMModel.Claude45Sonnet, ctx, opt =>
{
    opt.Chunks = documents.Select(d => (object)d).ToList();
    opt.MaxParallel = 8;

    opt.Map(m =>
    {
        m.Temperature = 0.5;
        m.Command = "Summarize the key points from this document chunk.";
    });

    opt.Reduce(r =>
    {
        r.Temperature = 0.3;
        r.Command = "Combine all chunk summaries into a comprehensive final report.";
    });
}).FinalAsync();
```

**Options:**
- `Chunks` - Pre-split input chunks (takes precedence if set)
- `Input` + `Split` - Or provide input with a split function (used only if `Chunks` is null)
- `MaxParallel` - Concurrency for map phase (default: 4)
- `Map(Action<EmergeScope<TChunk>>)` - Configure chunk processing
- `Reduce(Action<EmergeScope<TResult>>)` - Configure reduction

**Context flow:** Map runs use isolated contexts. All map outputs are collected and provided to Reduce in context.

---

### Refine — Iterative Improvement

Generate an initial result, then iteratively improve it based on feedback.

```csharp
var (final, _) = await Emerge.Refine<Code>(LLMModel.Claude45Sonnet, ctx, opt =>
{
    opt.MaxRefinements = 3;

    opt.Initial(s =>
    {
        s.Command = "Write initial implementation of the feature.";
    });

    opt.Refinement(s =>
    {
        s.Command = "Improve the code based on the issues found.";
    });

    // Async validation - continue refining while there are errors
    opt.ShouldContinue = async (result, trace) =>
    {
        var error = await ValidateCodeAsync(result.Code);
        return error != null;
    };
}).FinalAsync();
```

**Options:**
- `MaxRefinements` - Maximum improvement iterations (default: 3)
- `ShouldContinue` - Async callback `Func<T, EmergenceTrace, Task<bool>>` to control refinement
- `Initial(Action<EmergeScope<T>>)` - Configure initial generation
- `Refinement(Action<EmergeScope<T>>)` - Configure refinement passes

**Context flow:** Each refinement automatically receives the previous attempt's JSON output in context.

---

### TestRefine — Agentic Loop with Real-World Testing

Generate an initial result, then iteratively apply it to the real environment, evaluate via testing, and refine based on feedback. Unlike Refine which operates purely on the serialized result, TestRefine includes caller-provided side effects for grounding each iteration in real-world testing (screenshots, browser tests, compilation, etc.).

```csharp
var (final, _) = await Emerge.TestRefine<UIComponent>(LLMModel.Claude45Sonnet, ctx, opt =>
{
    opt.MaxIterations = 5;

    opt.Initial(s =>
    {
        s.Command = "Generate a responsive card component.";
    });

    opt.Refinement(s =>
    {
        s.Command = "Fix the issues found during testing.";
    });

    // Apply the result to the real environment
    opt.Apply = async (result, iteration) =>
    {
        await RenderToPreview(result.Code);
    };

    // Test the environment, score, decide whether to continue
    opt.Evaluate = async (result, iteration) =>
    {
        var screenshots = await CaptureScreenshots();
        var critique = await RunVisualCritique(screenshots);
        return new TestRefineFeedback
        {
            Continue = critique.Issues.Count > 0,
            Feedback = string.Join("\n", critique.Issues.Select(i => $"Fix: {i}")),
            Score = critique.Score
        };
    };
}).FinalAsync();
```

**Options:**
- `MaxIterations` - Maximum apply→evaluate→refine cycles (default: 5)
- `Initial(Action<EmergeScope<T>>)` - Configure initial generation
- `Refinement(Action<EmergeScope<T>>)` - Configure refinement passes
- `Apply` - Async callback `Func<T, int, Task>` to apply the result to the real environment (e.g., render UI, serve HTML, deploy to sandbox). Receives the result and iteration index. Optional.
- `Evaluate` - Async callback `Func<T, int, Task<TestRefineFeedback>>` to test the environment and decide whether to continue. Returns `TestRefineFeedback` with `Continue`, `Feedback`, and optional `Score`. Optional.

**Callback behavior:**
- Without `Apply`, generates and evaluates without side effects
- Without `Evaluate`, generates, applies, and loops to `MaxIterations` (degenerates to Refine with Apply side effects)
- `TestRefineFeedback.Feedback` is injected into the next refinement prompt alongside the current result JSON

**Context flow:** Each refinement receives the current result JSON and evaluation feedback in context. The Apply and Evaluate callbacks run between LLM calls.

---

### PlanAndExecute — Strategic Execution

First create a plan, then execute each step to produce the final result.

```csharp
var (result, _) = await Emerge.PlanAndExecute<ProjectPlan>(LLMModel.Claude45Sonnet, ctx, opt =>
{
    opt.MaxSteps = 10;
    opt.Tools.Add(fileReadTool);
    opt.Tools.Add(searchTool);

    opt.Planner(p =>
    {
        p.Command = "Create a step-by-step plan to complete this task.";
    });

    opt.Executor(e =>
    {
        e.Command = "Execute the current step and report results.";
    });
}).FinalAsync();
```

**Options:**
- `MaxSteps` - Maximum execution steps (default: 10)
- `Planner(Action<EmergeScope<ExecutionPlan>>)` - Configure plan generation
- `Executor(Action<EmergeScope<T>>)` - Configure step execution

The `ExecutionPlan` type contains `List<PlanStep> Steps` and optional `Summary`. Each `PlanStep` has `Description`, `RequiresTool`, and optional `ToolName`.

---

### Router — Dynamic Routing

Select the best route/model/approach for the task, then execute it.

```csharp
var (result, _) = await Emerge.Router<Response>(LLMModel.Claude45Sonnet, ctx, opt =>
{
    opt.AddRoute("code", "Programming and technical questions", LLMModel.Claude45Sonnet);
    opt.AddRoute("creative", "Creative writing and brainstorming", LLMModel.Claude45Sonnet);
    opt.AddRoute("analysis", "Data analysis and reasoning", LLMModel.Claude45Sonnet);

    opt.Router(r =>
    {
        r.Command = "Analyze this request and select the most appropriate route.";
    });

    opt.Command = "Handle the user's request.";
}).FinalAsync();
```

**Options:**
- `AddRoute(name, description, model?, configure?)` - Define available routes
- `Router(Action<EmergeScope<RouterDecision>>)` - Configure route selection

The `RouterDecision` type contains `SelectedRoute` and optional `Reasoning`.

---

### EnsembleMerge — Diverse Solutions Merged

Run multiple diverse solvers in parallel, then merge their outputs into a coherent result.

```csharp
var (merged, _) = await Emerge.EnsembleMerge<Analysis>(LLMModel.Claude45Sonnet, ctx, opt =>
{
    opt.SolverCount = 4;
    opt.MaxParallel = 4;

    opt.Solver(s =>
    {
        s.Temperature = 0.6 + 0.15 * s.Index;  // Varying temperatures
        s.Command = "Analyze this data from your unique perspective.";
    });

    opt.Merger(m =>
    {
        m.Temperature = 0.3;
        m.Command = "Synthesize all analyses into a comprehensive unified result.";
    });
}).FinalAsync();
```

**Options:**
- `SolverCount` - Number of parallel solvers (default: 3)
- `MaxParallel` - Concurrency limit (default: 3)
- `Solver(Action<AgentScope<T>>)` - Configure each solver (has `Index`, `Role`, `Seed`)
- `Merger(Action<EmergeScope<T>>)` - Configure the merger

**Context flow:** Solvers run with isolated contexts for deterministic parallel execution. Merger receives all solver outputs in context.

---

### TreeOfThought — Branching Reasoning

Explore multiple reasoning paths with beam search, evaluating and pruning to find the best solution.

```csharp
var (best, _) = await Emerge.TreeOfThought<Solution>(LLMModel.Claude45Sonnet, ctx, opt =>
{
    opt.MaxDepth = 4;
    opt.BranchingFactor = 3;
    opt.BeamWidth = 2;

    opt.Evaluate = (thought, trace) => ScoreThought(thought);

    opt.Thought(t =>
    {
        t.Command = "Generate the next reasoning step.";
    });
}).FinalAsync();
```

**Options:**
- `MaxDepth` - Maximum tree depth (default: 3)
- `BranchingFactor` - Branches per node (default: 3)
- `BeamWidth` - Best paths to keep at each level (default: 2)
- `Evaluate` - Scoring function `Func<T, EmergenceTrace, double>`
- `Thought(Action<EmergeScope<T>>)` - Configure thought generation
- `Evaluator(Action<EmergeScope<T>>)` - Configure evaluator scope

**Context flow:** Each branch runs with an isolated derived context containing its parent thought path.

---

### SelfConsistency — Majority Voting

Sample multiple completions and select the most consistent/majority answer.

```csharp
var (answer, _) = await Emerge.SelfConsistency<MathAnswer>(LLMModel.Claude45Sonnet, ctx, opt =>
{
    opt.Samples = 7;
    opt.MaxParallel = 7;

    opt.Sample(s =>
    {
        s.Temperature = 0.8;
        s.Seed = s.Index * 1000;
        s.Command = "Solve this math problem step by step.";
    });

    // Optional custom majority selection
    opt.SelectMajority = answers => answers
        .GroupBy(a => a.FinalAnswer)
        .OrderByDescending(g => g.Count())
        .First()
        .First();
}).FinalAsync();
```

**Options:**
- `Samples` - Number of samples (default: 5)
- `MaxParallel` - Concurrency limit (default: 5)
- `SelectMajority` - Custom selection function (default: JSON equality grouping)
- `Sample(Action<CandidateScope<T>>)` - Configure sampling (has `Index`, `Seed`)

**Context flow:** Each sample runs with an isolated derived context to ensure independent sampling.

---

### Swarm — Multi-Agent Orchestration

Coordinate multiple agents with different roles across rounds.

```csharp
var (result, _) = await Emerge.Swarm<ProjectOutput>(LLMModel.Claude45Sonnet, ctx, opt =>
{
    opt.MaxRounds = 2;
    opt.MaxParallel = 3;

    opt.AddAgent("researcher", s =>
    {
        s.Command = "Research and gather relevant information.";
    });

    opt.AddAgent("analyst", s =>
    {
        s.Command = "Analyze the gathered information.";
    });

    opt.AddAgent("writer", s =>
    {
        s.Command = "Write the final output based on analysis.";
    });

    opt.Coordinator(c =>
    {
        c.Command = "Synthesize all agent outputs into the final deliverable.";
    });

    // Or use a custom merge function
    // opt.Merge = results => MergeResults(results);
}).FinalAsync();
```

**Options:**
- `MaxRounds` - Number of orchestration rounds (default: 1)
- `MaxParallel` - Agents running concurrently (default: 4)
- `AddAgent(role, configure)` - Add an agent with a role and configuration
- `Coordinator(Action<EmergeScope<T>>)` - Configure final coordination
- `Merge` - Custom merge function instead of coordinator

Each `SwarmAgent<T>` has `Role`, optional `Id`, and `DependsOn` list for declaring inter-agent dependencies.

**Context flow:** Agents run with isolated contexts per round. All agents run every round. Coordinator receives all agent outputs in context.

---

### TaskGraph — Dependency-Aware Task Execution

Define a graph of tasks with dependencies, execute them in parallel where possible, with periodic review and plan revision.

```csharp
var (result, _) = await Emerge.TaskGraph<FinalReport>(LLMModel.Claude45Sonnet, ctx, opt =>
{
    opt.MaxParallel = 4;
    opt.EnableParallelReview = true;
    opt.ReviewIntervalTasks = 2;

    opt.AddTask("research-benefits", "Research the benefits of the approach");
    opt.AddTask("research-challenges", "Research the challenges and risks");
    opt.AddTask("synthesize", "Synthesize findings into a report",
        "research-benefits", "research-challenges");  // blocked by both

    opt.Worker(w =>
    {
        w.Temperature = 0.7;
        w.Command = "Complete the assigned task thoroughly.";
    });

    opt.Reviewer(r =>
    {
        r.Temperature = 0.3;
        r.Command = "Review completed tasks for quality and suggest improvements.";
    });

    opt.Synthesizer(s =>
    {
        s.Temperature = 0.4;
        s.Command = "Synthesize all task results into the final deliverable.";
    });

    opt.OnTaskCompleted = (task, result) => Console.WriteLine($"Task {task.Id} done");
}).FinalAsync();
```

**Options:**
- `AddTask(id, description, params blockedBy)` - Add a task with optional dependencies
- `MaxParallel` - Concurrent task limit (default: 4)
- `EnableParallelReview` - Run reviews alongside execution (default: true)
- `ReviewIntervalTasks` - Review after every N completed tasks (default: 2)
- `Worker(Action<EmergeScope<T>>)` - Configure task executor
- `Reviewer(Action<EmergeScope<ReviewFeedback>>)` - Configure reviewer
- `PlanReviser(Action<EmergeScope<PlanRevision>>)` - Configure plan reviser
- `Synthesizer(Action<EmergeScope<T>>)` - Configure final synthesis
- `OnTaskCompleted`, `OnReviewCompleted`, `OnPlanRevised` - Progress callbacks
- `OnHumanFeedback` - Async callback for human-in-the-loop

Each `TaskNode` has `Id`, `Description`, `BlockedBy`, `Blocks`, `Status`, optional `Owner`, `Result`, and `Error`.

---

### TreeSearch — Document Tree Navigation

Navigate a hierarchical document index to find relevant sections without vector embeddings.

```csharp
// Step 1: Build a tree index from content
TreeIndex index = null;
await foreach (var ev in TreeIndex.BuildAsync(LLMModel.Claude45Sonnet, documentContent,
    new TreeIndexOptions { MaxDepth = 4, GenerateSummaries = true }))
{
    if (ev is Completed<TreeIndex> done)
    {
        index = done.Result;
    }
}

// Step 2: Search the tree
var (result, _) = await Emerge.TreeSearch<TreeSearchResult>(LLMModel.Claude45Sonnet, ctx, opt =>
{
    opt.Index = index;
    opt.Query = "How does authentication work?";
    opt.MaxSteps = 10;
    opt.MaxResults = 3;

    opt.Navigator(n =>
    {
        n.Command = "Navigate the document tree to find sections relevant to the query.";
    });
}).FinalAsync();

// result.Sections contains found sections with NodeId, Path, Content, Relevance, Page
```

**Options:**
- `Index` - The `TreeIndex` to search
- `Query` - Search query
- `MaxSteps` - Maximum navigation steps (default: 10)
- `MaxResults` - Maximum sections to return (default: 5)
- `Navigator(Action<EmergeScope<NavigationDecision>>)` - Configure navigator

**Tree indexing types:**

`TreeIndex` builds a hierarchical document structure:
- `BuildAsync(model, string content, options?)` - Build from raw text
- `BuildAsync(model, IContentReader reader, options?)` - Build from custom reader
- `ToTableOfContents(maxDepth)` - Generate table of contents
- `FindById(id)` - Look up a node by ID

`TreeIndexOptions`: `MaxDepth` (default: 4), `MaxSummaryTokens` (default: 100), `GenerateSummaries` (default: true)

`TreeNode`: `Id`, `Title`, `Summary`, `Content`, `Page`, `Children`, `Parent`, `Depth`

`IContentReader` / `ContentSection`: Interface for custom content sources. `StringContentReader` wraps a plain string.

---

## Inline Tool Registration

The `EmergePass<T>` provides fluent `AddTool` extension methods for registering tools inline with lambda functions. Tools are deduplicated by name.

```csharp
await foreach (var ev in Emerge.Run<CoderResponse>(LLMModel.Claude45Sonnet, ctx, pass =>
{
    pass.AddTool("write_file", "Write content to a file",
            (string path, string content) => WriteFile(path, content))
        .AddTool("read_file", "Read file contents",
            (string path) => ReadFile(path))
        .AddTool("list_files", "List all files",
            () => ListFiles());

    pass.Command = "Complete this coding task.";
    pass.MaxIterations = 10;
    pass.MaxToolCalls = 50;
}))
{ ... }
```

**Methods:**
- `AddTool(Function)` - Add a pre-built `Function` object
- `AddTools(params Function[])` - Add multiple pre-built functions
- `AddToolsFrom(object instance)` - Auto-discover methods with `[Function]` attributes
- `AddTool(name, description, Func<..., TResult>)` - Inline sync function (0-8 parameters)
- `AddTool(name, description, Func<..., Task<TResult>>)` - Inline async function (0-8 parameters)

All `AddTool` overloads return `EmergePass<T>` for chaining.

---

## Structured Tag Parser

`StructuredTagParser` extracts XML-style tags from LLM responses, useful for structured output outside of JSON mode.

```csharp
using Ikon.AI.Emergence.Structured;

var parsed = StructuredTagParser.Parse(content, "reasoning", "answer");

// parsed.PlainText — text outside tags
// parsed.Blocks — list of ParsedBlock (TagName, Content, StartIndex, EndIndex)

// Utility methods
bool has = StructuredTagParser.HasTag(content, "reasoning");
string? text = StructuredTagParser.GetTagContent(content, "answer");
```

---

## KernelContext Extensions

Extension methods for inspecting tool call history in a `KernelContext`:

```csharp
bool hasFn = ctx.HasFunctionResults();
var results = ctx.GetFunctionResults(take: 10);  // IReadOnlyList<FunctionResultPart>
var calls = ctx.GetFunctionCalls(take: 10);       // IReadOnlyList<FunctionCall>
```

---

## Common Options Reference

All pattern options inherit these from `EmergeScopeBase`:

| Option | Type | Description |
|--------|------|-------------|
| `Model` | `LLMModel?` | Override the model |
| `Temperature` | `double?` | Sampling temperature |
| `MaxOutputTokens` | `int?` | Maximum output tokens |
| `ReasoningEffort` | `ReasoningEffort?` | Reasoning effort level |
| `ReasoningTokenBudget` | `int?` | Token budget for reasoning |
| `Timeout` | `TimeSpan?` | Request timeout |
| `Regions` | `IReadOnlyList<ModelRegion>?` | Model region preferences |
| `MaxIterations` | `int?` | Max agentic iterations |
| `MaxToolCalls` | `int?` | Max tool calls |
| `MaxWallTime` | `TimeSpan?` | Max wall clock time |
| `MaxRetries` | `int?` | Max retries on transient failures |
| `RetryDelay` | `TimeSpan?` | Delay between retries |
| `SystemPrompt` | `string?` | System instruction |
| `Command` | `string?` | User command |
| `Tools` | `IList<Function>` | Available tools |
| `UseLastNMessages` | `int?` | Context window limit |
| `SkipLastNMessages` | `int?` | Skip N most recent messages |
| `OptimizeContext` | `bool?` | Enable context optimization |
| `UseCitations` | `bool?` | Enable citations |
| `IncludeJsonExample` | `bool?` | Include JSON example in prompt (default: true) |

`UseLastMessages(count, skipLast)` is a convenience method for setting both `UseLastNMessages` and `SkipLastNMessages`.

`EmergeScope<T>` adds `UseJson` (default: true), `CaseInsensitiveJson` (default: true), `JsonSchema`, and `JsonExample` (both read-only, auto-generated from `T`).

### EmergenceBudget

Pre-defined budget configurations:

```csharp
var budget = EmergenceBudget.Default;    // 10 iterations, 50 tool calls, 5 min
var budget = EmergenceBudget.Unlimited;  // No limits
var budget = new EmergenceBudget(maxIterations: 20, maxToolCalls: 100, maxWallTime: TimeSpan.FromMinutes(10));
```

### EmergenceTrace

Returned with `Completed<T>` events:

| Property | Type | Description |
|----------|------|-------------|
| `Iterations` | `int` | Number of LLM iterations |
| `ToolCalls` | `int` | Number of tool calls made |
| `InputTokens` | `long` | Total input tokens consumed |
| `OutputTokens` | `long` | Total output tokens generated |
| `Duration` | `TimeSpan` | Total wall time |
| `ToolCallHistory` | `IReadOnlyList<FunctionCall>` | Full tool call history |
| `FinishReason` | `string?` | Model finish reason (e.g., "length", "max_tokens") |
| `Error` | `Exception?` | Error if one occurred |
| `IsTruncated` | `bool` | True when `FinishReason` indicates output was cut short |

## Testing with Mock LLM

All pattern methods have an overload accepting `ILLM` for testing:

```csharp
var mockLlm = new MockLLM(responses);

var (result, _) = await Emerge.Run<MyType>(
    LLMModel.Claude45Sonnet,
    ctx,
    pass => { ... },
    mockLlm  // Injected for testing
).FinalAsync();
```
