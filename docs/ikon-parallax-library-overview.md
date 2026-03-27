# Ikon.Parallax Library Overview

## Introduction

Ikon.Parallax is a server-driven, reactive UI library for building interactive applications in C#. The library provides a declarative API for constructing user interfaces where all logic runs on the server, clients act as lightweight renderers, and the framework automatically handles efficient UI updates through intelligent diffing.

The name "Parallax" reflects the library's core capability: different clients can receive different views of the same underlying UI based on reactive scopes, similar to how parallax creates different viewpoints of the same scene.

## Core Concepts

### Reactive UI Updates

Ikon.Parallax uses the reactive system from `Ikon.Common.Core.Reactive`. When a `Reactive<T>` value changes, only the UI components that depend on that value are re-rendered. The framework tracks dependencies automatically during rendering.

```csharp
private readonly Reactive<int> _count = new(0);
private readonly Reactive<string> _message = new("Hello");

// When _count.Value changes, only UI that reads _count.Value re-renders
// When _message.Value changes, only UI that reads _message.Value re-renders
```

### Server-Side Diffing

The UI tree is constructed and diffed entirely on the server. When changes occur:

1. The reactive system detects which values changed
2. Affected UI components re-render on the server
3. The framework computes a minimal diff
4. Only the diff is sent to clients

This architecture means clients can be thin renderers with minimal logic.

### Scoped Reactive Values

Reactive values can be scoped to specific contexts (per-client, per-user, etc.). This enables sending different UI to different clients from the same codebase:

```csharp
// A value that is unique per client
private readonly Reactive<int, ClientScope> _clientCounter = new(0);

// A value that is unique per user
private readonly Reactive<string, UserScope> _userPreference = new("");
```

### Crosswind Styling

Styling uses Crosswind, a Tailwind-compatible utility class system. Styles are defined as string constants and support:

- Standard Tailwind utility classes (`flex`, `gap-4`, `bg-white`, etc.)
- Extended motion and animation classes
- Built-in theme style constants (via `Ikon.Parallax.Themes.Default`)

```csharp
private const string ButtonStyle =
    "px-4 py-2 rounded-lg bg-blue-500 hover:bg-blue-600 text-white transition";

view.Button(style: [ButtonStyle], label: "Click me", onClick: async () => { });
```

## Basic Usage

### Setting Up a UI

Create a `UI` instance with the app host and call `Root` to define the UI tree:

```csharp
using Ikon.Parallax;
using Ikon.Parallax.Themes.Default;

[App]
public class MyApp(IApp<SessionIdentity, ClientParams> host)
{
    private UI UI { get; } = new(host, new Theme());

    private readonly Reactive<int> _counter = new(0);

    public async Task Main()
    {
        UI.Root(style: ["min-h-screen bg-slate-950 text-white"], content: view =>
        {
            view.Column(style: ["flex flex-col items-center gap-4 p-6"], content: view =>
            {
                view.Text(style: ["text-2xl font-bold"], text: "Counter App");
                view.Text(style: ["text-lg"], text: $"Count: {_counter.Value}");
                view.Button(
                    style: ["px-4 py-2 bg-blue-500 rounded hover:bg-blue-600"],
                    label: "Increment",
                    onClick: async () => _counter.Value++);
            });
        });
    }
}
```

When `_counter.Value` changes, only the Text displaying the count re-renders, and only that diff is sent to clients.

### Component Methods

The `UIView` class provides extension methods for common UI components:

**Layout:**
- `view.Row()` - Horizontal flex container
- `view.Column()` - Vertical flex container
- `view.ScrollArea()` - Scrollable container with optional smart auto-scroll
- `view.InfiniteScrollView()` - Scroll area with near-end callbacks for lazy loading

**Display:**
- `view.Text()` - Text content
- `view.Button()` - Clickable button
- `view.Switch()` - Toggle switch
- `view.TextField()` - Text input
- `view.Slider()` - Range slider

**Overlays:**
- `view.Dialog()` - Modal dialog
- `view.Popover()` - Popover content
- `view.Tooltip()` - Tooltip on hover

**Navigation:**
- `view.Tabs()` - Tabbed interface
- `view.AccordionSingle()` / `view.AccordionMultiple()` - Collapsible sections

### ScrollArea and Auto-Scroll

ScrollArea provides a scrollable container with smart auto-scroll support, ideal for chat interfaces and live feeds:

```csharp
view.ScrollArea(
    rootStyle: ["h-[400px]"],
    autoScroll: true,
    autoScrollKey: _messages.Value.Count.ToString(),
    content: view =>
    {
        foreach (var msg in _messages.Value)
        {
            view.Text([Text.Body], msg);
        }
    });
```

**Auto-scroll behavior (Polite priority):**
- At bottom: new content auto-scrolls into view
- Scrolled away: auto-scroll is suppressed, a floating indicator appears to notify the user
- Clicking the indicator or scrolling back to bottom resumes auto-scroll

For forced scrolling (always scroll regardless of position), use `FocusHint` with `FocusPriority.Assertive`:

```csharp
anchor.FocusHint(new FocusHintProps { Priority = FocusPriority.Assertive },
    key: $"scroll-{version}");
```

## Example: Interactive Form

```csharp
private readonly Reactive<string> _name = new("");
private readonly Reactive<bool> _subscribed = new(false);
private readonly Reactive<int> _volume = new(50);

public async Task Main()
{
    UI.Root(style: ["p-8 bg-neutral-900 text-white"], content: view =>
    {
        view.Column(style: ["flex flex-col gap-4 max-w-md"], content: view =>
        {
            // Text input (use value: for controlled mode — clears reliably when set to "")
            view.TextField(
                style: ["px-3 py-2 bg-neutral-800 rounded border border-neutral-700"],
                value: _name.Value,
                onValueChange: value =>
                {
                    _name.Value = value;
                    return Task.CompletedTask;
                });

            // Switch
            view.Row(style: ["flex items-center gap-3"], content: view =>
            {
                view.Switch(
                    style: ["w-10 h-5 rounded-full bg-neutral-700 data-[state=checked]:bg-blue-500"],
                    @checked: _subscribed.Value,
                    onCheckedChange: value =>
                    {
                        _subscribed.Value = value;
                        return Task.CompletedTask;
                    },
                    content: view =>
                    {
                        view.SwitchThumb(style: ["block w-4 h-4 rounded-full bg-white transition data-[state=checked]:translate-x-5"]);
                    });
                view.Text(text: "Subscribe to newsletter");
            });

            // Slider
            view.Slider(
                style: ["w-full"],
                value: [_volume.Value],
                onValueChange: values =>
                {
                    _volume.Value = (int)values[0];
                    return Task.CompletedTask;
                },
                content: view =>
                {
                    view.SliderTrack(style: ["h-2 bg-neutral-700 rounded-full"], content: view =>
                    {
                        view.SliderRange(style: ["h-full bg-blue-500 rounded-full"]);
                    });
                    view.SliderThumb(style: ["w-4 h-4 bg-white rounded-full"]);
                });
            view.Text(style: ["text-sm text-neutral-400"], text: $"Volume: {_volume.Value}%");

            // Display current state
            view.Text(style: ["mt-4 text-neutral-400"],
                text: $"Name: {_name.Value}, Subscribed: {_subscribed.Value}");
        });
    });
}
```

## Styling with Crosswind

Styles are organized into reusable constants. Applications typically define a styles class:

```csharp
public static class AppStyles
{
    public static class Button
    {
        public const string Primary =
            "px-4 py-2 rounded-lg font-medium " +
            "bg-blue-500 hover:bg-blue-600 active:bg-blue-700 " +
            "text-white transition-colors";

        public const string Secondary =
            "px-4 py-2 rounded-lg font-medium " +
            "bg-neutral-700 hover:bg-neutral-600 " +
            "text-white transition-colors";
    }

    public static class Input
    {
        public const string Default =
            "px-3 py-2 rounded-lg " +
            "bg-neutral-800 border border-neutral-700 " +
            "focus:border-blue-500 focus:outline-none " +
            "text-white placeholder:text-neutral-500";
    }

    public static class Card
    {
        public const string Default =
            "p-4 rounded-xl " +
            "bg-neutral-900 border border-neutral-800";
    }
}
```

The library includes a built-in `Default` theme that provides a complete style system:

```csharp
using Ikon.Parallax.Themes.Default;

// Use theme style constants
view.Button(style: [Button.PrimaryMd], label: "Submit");
view.TextField(style: [Input.Default], value: _text.Value, onValueChange: async v => _text.Value = v);
```

## Per-Client UI with Scopes

The reactive scope system enables different clients to see different UI:

```csharp
// Counter that is unique per client
private readonly Reactive<int, ClientScope> _clientCounter = new(0);

public async Task Main()
{
    UI.Root(content: view =>
    {
        // Each client sees their own counter value
        view.Text(text: $"Your count: {_clientCounter.Value}");
        view.Button(
            label: "Increment",
            onClick: async () => _clientCounter.Value++);
    });
}
```

Without scopes, all clients share the same value. With `ClientScope`, each client has an independent value. This is the "parallax" effect: the same UI code produces different views for different clients.

## Architecture Summary

1. **Server-side logic**: All UI logic, state, and event handlers run on the server
2. **Reactive updates**: Changes to `Reactive<T>` values trigger targeted re-renders
3. **Differential sync**: Only UI diffs are sent to clients
4. **Scoped state**: `Reactive<T, TScope>` enables per-client or per-user state
5. **Lightweight clients**: Clients render the UI tree and forward events to the server
6. **Crosswind styling**: Tailwind-compatible utility classes with motion extensions
