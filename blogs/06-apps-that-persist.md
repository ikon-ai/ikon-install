# Apps That Persist

Close your browser. Walk away. Come back tomorrow morning. Your AI research assistant has been working through the night -- analyzing documents, monitoring sources, building a digest of what happened while you were gone. When you open the app, the results are waiting. The conversation remembers where you left off. The analysis is further along than when you left.

This is what it feels like when applications persist.

## What this unlocks

**AI agents that work while you sleep.** A research assistant that monitors sources and builds a daily briefing runs as a background task within the application itself. It has direct access to the app's state. When it finds something, the results appear the next time any user opens the app.

**Apps that accumulate intelligence over time.** Context stays warm in memory. Each interaction builds on everything before it. This is the difference between an AI that genuinely remembers your project and one that reconstructs context from saved notes every time you return.

**Development iteration without losing your place.** During development, changing your code does not restart the world. All state is preserved across code changes. You are in the middle of a complex AI workflow, you tweak the interface, you save, and everything continues from exactly where it was.

**Long-running AI workflows that just work.** A document analysis that takes 30 minutes, a research task that runs for hours, a data pipeline that runs overnight -- these are natural patterns, not infrastructure projects. No job queues, no worker processes, no orchestration. Just a task that runs until it is done.

**Apps that feel alive.** When background processing, live state, and persistence combine, applications stop feeling like tools you query and start feeling like entities that exist. An AI character that monitors the news and has opinions about what happened while you were away. A collaborative workspace where the AI has been organizing and connecting ideas since the last time anyone checked in.

## Why most apps cannot do this

In a typical web architecture, the server is stateless by design. A request arrives, the server processes it, sends a response, and forgets everything. State lives in databases, caches, and session stores. The server itself is ephemeral, designed to be killed and replaced at any moment.

This model works well for traditional applications. It works poorly for AI applications.

AI workflows are inherently stateful. A conversation has context that spans turns. An analysis pipeline has intermediate results. A multi-agent orchestration has tasks in various stages of completion. Treating all of this as "serialize it to a database and reconstruct it per request" adds latency, complexity, and failure modes that have nothing to do with the actual problem you are trying to solve.

## How Ikon applications work differently

An Ikon application is a long-lived stateful process. It starts, it runs, and it persists -- even when no one is watching.

**State lives in the application.** The app holds its state in memory -- conversations, analysis results, queued tasks, accumulated context. When a user disconnects and reconnects later, the application is still running. Everything is exactly where they left it. No database round-trip, no state reconstruction, no cold start.

**Background work is a first-class concept.** In traditional architectures, running something in the background requires a job queue, a message broker, worker processes, and orchestration to tie them together. In Ikon, background work is simply a task that runs within the application process. It has direct access to the app's live state. When it updates something, every connected user sees the change immediately. If no users are connected, the task keeps running anyway.

Here is what a background AI task looks like — it gathers sources, analyzes each one, and updates the interface in real time as results come in:

```csharp
host.BackgroundWork.Start("deep-analysis", async ct =>
{
    var sources = await GatherSources(query);

    foreach (var source in sources)
    {
        var analysis = await Emerge.Run<SourceAnalysis>(
            LLMModel.Claude46Sonnet, context, pass =>
            {
                pass.Command = $"Analyze this source: {source.Content}";
            }).FinalAsync();

        // UI updates in real-time as each source is analyzed
        _currentAnalysis.Value = analysis.Result.Summary;
    }
});
```

If no one is watching, the task keeps running. When someone reconnects, they see wherever the analysis has gotten to.

**Scheduled and recurring work runs inside the app.** For structured background processing -- daily digests, periodic data pulls, recurring analysis -- the platform provides a pipeline system with scheduling, data transformation, parallel processing, and error handling. All of it runs within the persistent application process, not in a separate service.

## State survives hot reloads

This matters most during development. In most frameworks, changing your code means restarting the server and losing all state. You are in the middle of testing a multi-turn AI conversation, you notice a UI issue, you fix it, and now you have to recreate the entire conversation from scratch.

Ikon supports hot reload that preserves state. When you modify your code, the platform captures the current state, compiles the new code, reinstantiates the application, restores all state, and resumes. Your in-progress AI conversation continues. Your background tasks pick up where they left off. Nothing is lost.

This is not just a convenience -- it fundamentally changes how you develop AI applications. You can iterate on behavior and presentation while a complex workflow is running, without ever having to restart it.

## What persistence makes possible

**Long-running AI workflows.** An AI research agent that takes 30 minutes to analyze a corpus of documents runs as a continuous process, updating the interface as it goes. Close your browser, come back, and see the results.

**Conversational context that stays warm.** A multi-turn conversation with accumulated context lives directly in the application. No "serialize the conversation to a database, deserialize it on the next request" cycle. The context is just there, in memory, ready for the next turn.

**Collaborative state without infrastructure.** Multiple users connect to the same running application. They see each other's contributions and watch AI processes unfold in real time. No pub/sub configuration, no real-time sync layer -- shared state is the default.

**Warm AI contexts that compound.** Because context accumulates in memory over time, the application gets more useful the longer it runs. The AI builds richer models of what it is working on, maintains deeper history, and surfaces more relevant connections. Each interaction builds on everything that came before.

## The infrastructure behind it

The "app runs forever" model requires solid infrastructure to support it. Each application runs in its own isolated container. The platform manages the lifecycle -- starting apps on demand, monitoring health, handling graceful shutdown when needed. For state that must survive beyond the application process (not just across hot reloads), the platform provides persistent storage for files, structured data, and database connections. The choice of what to persist long-term is explicit and intentional, not forced by architectural limitations.

## A different kind of application

The shift from stateless request handlers to persistent stateful processes changes what applications can be. They stop being tools that respond when poked and start being environments that evolve over time. An Ikon application does not just answer your questions -- it keeps working on the problem after you close the tab.
