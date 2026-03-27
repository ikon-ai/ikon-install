# A Natural Language 3D Globe

Type "CO2 emissions" into a text field. A spinning 3D globe lights up with animated spikes at locations around the world -- sized by magnitude, colored to match the data type, clickable to inspect individual values. Type "who's online?" and the globe redraws with internet usage data in blue. Type "how hot is it?" and temperature data appears in red. Multiple people can connect simultaneously, ask different questions, and watch the globe update together.

The backend is about four hundred lines. The 3D rendering component is about six hundred lines. There is no API layer, no state synchronization code, no WebSocket configuration. Here is how it works and why that matters.

## What you experience

You type a question in plain language -- anything about the world that has a geographic dimension. The system interprets your question, generates geographically accurate data points, and renders them as animated spikes on a slowly rotating globe. Click any spike to see the details: location name, coordinates, and value. A side panel shows the current visualization, your query history, and detail cards for selected data points.

The globe responds to creative, casual questions. "Carbon footprint" becomes CO2 emissions data. "Who's online?" becomes internet usage by country. "Show me the money" becomes GDP data. The system figures out what you mean and picks appropriate colors -- green for environmental data, blue for technology, orange for energy.

## Multiuser for free

There is no multiuser code in this application. When one person asks "GDP per capita," every connected user sees the globe update with the new data. This is not a feature that was built -- it is a consequence of how the platform works. The server owns the state, and every connected client receives updates automatically.

In practice this means the app works as a presentation tool without any modification. One person drives the queries while a room full of people watches the globe respond on their own screens. Or multiple analysts explore different questions and everyone benefits from seeing each other's results. The query history is shared, so the group builds up a collective exploration record.

Per-user state does exist where it makes sense -- the text in your query input field is yours alone, and your spike selection is independent. But the globe data, the visualization, and the history are shared.

## Two-stage AI pipeline

The system splits the AI work into two passes rather than asking a single model to do everything at once, and the split matters.

The interpretation call -- a fast, cheap model figures out what you're asking:

```csharp
var (result, _) = await Emerge.Run<DataQueryResult>(
    LLMModel.Gpt41Mini,
    new KernelContext(),
    pass =>
    {
        pass.Command = command;
        pass.Temperature = 0.3f;
    },
    cancellationToken
).FinalAsync();
```

The result is a typed object with the interpreted query, a display label, a suggested color, and a data category. No JSON parsing, no response extraction -- just structured data back.

The second pass uses a more capable model to generate the actual geographic data. It produces fifty to a hundred data points, each with realistic latitude and longitude coordinates and proportional magnitudes. This model needs more creative latitude -- it is synthesizing plausible data across dozens of locations -- so it runs with more freedom to vary its output.

Why split them? Cost and precision. The interpretation step is cheap and deterministic. The data generation step needs a bigger, more capable model. Splitting also means you can swap or upgrade either model independently, or add caching on the interpretation layer without affecting data freshness.

The output of each AI pass is structured and typed -- not raw text that needs parsing. The system asks for specific fields (interpreted query, display label, color, data source category in the first pass; location coordinates, magnitudes, and labels in the second) and gets them back in a usable format directly.

## Custom 3D rendering inside a server-driven UI

The globe is not a standard chart or widget. It is a full custom 3D scene with atmospheric glow effects, continent outlines drawn from coordinate data, animated spikes, a latitude/longitude grid, orbit controls for spinning and zooming, and click detection that identifies which spike you tapped.

This is the part that demonstrates these apps are not limited to forms and charts. The 3D component is a custom piece built with standard web 3D technology (THREE.js), but it plugs into the server-driven UI system seamlessly. From the creator's perspective, using the custom globe component feels no different from using a built-in text field -- you pass it parameters (data points, colors, rotation speed) and handle callbacks (spike clicks). The framework takes care of sending the data to the client and routing interactions back to the server.

When you click a spike on the globe, the click is detected on the client, sent to the server, and the server updates its state, which causes a detail card to appear in the side panel. From the creator's perspective, this round trip across the network boundary is invisible -- it reads like a simple callback.

## What this would take on a traditional stack

Building the equivalent without a server-driven UI framework means assembling several independent systems: a frontend application with 3D rendering, a backend API, an AI integration layer with prompt management and structured output parsing, a state management library for the frontend, WebSocket infrastructure for real-time updates across clients, session management, serialization logic between API and frontend, error handling on both sides, and deployment configuration for at least two services.

The custom 3D component would be roughly the same size regardless of framework -- 3D rendering code is 3D rendering code. But everything around it -- the API boundary, the state synchronization, the real-time broadcast, the callback routing -- adds hundreds or thousands of lines and introduces entire categories of bugs: stale state, race conditions, reconnection handling, schema drift between client and server.

Here, the backend is about four hundred lines across seven files. There is no API layer because there is no API. There is no state sync because the server owns the state. There is no WebSocket configuration because the framework handles the transport.

## Takeaway

The interesting thing about this application is not the globe itself. Plenty of 3D globe visualizations exist. What is unusual is the combination: natural language input driving a two-stage AI pipeline whose output feeds directly into a custom 3D renderer, with multiuser support, in a codebase small enough to read in one sitting. Each of those capabilities -- AI orchestration, custom rendering, real-time collaboration -- usually belongs to a different team or a different service. Here they coexist in the same process, connected by shared reactive values instead of network calls. That is what makes the four hundred lines possible.
