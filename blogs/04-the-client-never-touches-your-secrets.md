# The Client Never Touches Your Secrets

Open your browser's developer tools on most AI-powered web applications. Inspect the network tab. You'll find API keys in headers, tokens stored where anyone can read them, and service credentials embedded in the code that shipped to your browser.

Ikon's architecture makes this problem disappear — not by adding security layers, but by eliminating the condition that creates the vulnerability in the first place.

## What this unlocks

The security model isn't just defensive — it enables creators to ship AI applications with powerful capabilities that would be reckless to expose in a traditional setup.

**Give AI agents powerful tools without exposing attack surface.** When all AI execution happens on the server, you can give your AI agent access to databases, code execution, file systems, and external APIs without any of those capabilities being reachable from the client. A developer built an app where people describe interfaces in plain English and the AI generates and runs live code that renders in real time — dynamic code execution driven by user input, with zero client-side exposure. In a traditional architecture, this would be a security nightmare. On Ikon, the client never sees the generated code, the execution environment, or the raw results.

**Ship AI apps without lengthy security reviews for the client.** The client has no business logic, no API keys, no credentials, no state management, and minimal dependencies. There's nothing sensitive to audit on the client side because there's nothing sensitive there.

**Pass enterprise security reviews on day one.** When auditors ask where API keys are stored, where credentials flow, and what the client can access, the answers are straightforward: server-side only, never transmitted, and nothing. Developers building on Ikon have shipped AI applications into regulated environments — financial services, healthcare, enterprise — without the months-long security review cycles that typically gate AI deployments.

**Use multiple AI providers without multiplying your risk.** An app that combines one service for language, another for speech, and a third for images would traditionally need separate sets of credentials managed on the client or proxied through separate backend services. On Ikon, all provider credentials live on the server. Adding a new AI provider is a code change, not a security architecture change.

## The thin client principle

In a traditional web stack, the client is "fat" — it contains business logic, state management, integration code, and often direct access to backend services. The server is a data provider.

In Ikon, this relationship is inverted. The server owns everything:

- **All interface rendering** happens on the server. The client receives pre-computed updates and applies them.
- **All AI calls** originate from the server. The client never communicates directly with any AI provider.
- **All business logic** runs in an isolated server process.
- **All state** lives on the server.

The client's job is simple: maintain a persistent connection to the server, render the interface updates it receives, and send user inputs back. That's it.

## Credentials stay on the server

When you build an AI application with Ikon, your API keys for OpenAI, Anthropic, Google, ElevenLabs, or any other provider live exclusively in server-side configuration. They're used by code running in a cloud container. They never appear in browser code, browser storage, network requests visible in developer tools, or URL parameters.

This is what server-side AI code looks like — the AI can query a database directly, and none of it is visible to the client:

```csharp
// This runs on the server — the client never sees the API key,
// the request, or the raw response
var (analysis, _) = await Emerge.Run<Report>(LLMModel.Claude46Sonnet, context, pass =>
{
    pass.Command = "Analyze this financial data";
    pass.AddTool("query_database", "Run a SQL query", async (string sql) =>
    {
        return await _database.QueryAsync(sql);
    });
}).FinalAsync();
```

The client sees the final rendered result — a chart, a summary, a table — not the API calls, database queries, or credentials that produced it. It's like watching a cooking show: you see the finished dish, but you never see (or need to see) the recipe or the ingredients list.

## Container isolation

Each Ikon application instance runs in its own isolated container with separate memory, its own filesystem, and an isolated network stack. Even if an attacker somehow compromises the application code running inside a container, the blast radius is limited to that single instance. They can't reach other apps, other users' data, or the platform infrastructure.

## The security implications compound

When you remove client-side access to APIs and credentials, several categories of vulnerabilities become irrelevant:

**No client-side injection of AI prompts.** The server controls what prompts are sent, what tools are available, and what models are used. An attacker can't craft malicious requests by modifying client-side code because the client doesn't make those requests.

**No credential theft.** Even if a cross-site scripting vulnerability existed in the client, there are no credentials to steal. The client doesn't have API keys, database passwords, or service tokens.

**No interception of AI traffic.** The client doesn't communicate with third-party AI services. An attacker monitoring network traffic from the client sees only the encrypted connection to the Ikon server.

**No supply chain exposure.** The thin client has minimal dependencies. There's no API library, no fetch wrapper, no state management framework — all common targets for supply chain attacks. Entire categories of client-side vulnerabilities become structurally impossible.

## How authentication works

People still need to log in, of course. Ikon supports OAuth (Google, Apple, Microsoft), magic links, passkeys, anonymous sessions, and API keys for programmatic access. After the initial authentication, the persistent connection carries a secure session token. The client doesn't need to manage tokens, refresh them, or include them in subsequent requests — because there are no subsequent requests. Just a persistent connection that's already authenticated.

## The trade-off

There's no offline mode. The client depends on the server connection. For applications that need offline capability — note-taking apps, document editors, read-later services — a traditional architecture with client-side logic and local storage may be more appropriate.

But interactive AI applications are fundamentally online experiences that require server-side compute, external API access, and often real-time collaboration. For this category, the security model isn't a constraint — it's exactly what you need.
