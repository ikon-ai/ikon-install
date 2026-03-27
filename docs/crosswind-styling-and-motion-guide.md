# Crosswind Styling and Motion Guide

## Overview

Crosswind is Ikon's utility-first styling and animation system. The name comes from being Tailwind-inspired while extending it with additional features, particularly a motion language for declarative animations.

The library lives in `Ikon.Crosswind` and provides:

- **Tailwind-compatible syntax**: Standard Tailwind utility classes work as expected (`flex`, `gap-4`, `bg-blue-500`, `hover:bg-blue-600`, etc.)
- **Motion language**: Extended syntax for declarative keyframe animations, staggered text effects, and input-bound timelines
- **Server-side compilation**: Classes are parsed and compiled to CSS on the server, with only the resulting styles sent to clients

## How It Works

When you pass style strings to UI components, Crosswind processes them through a compilation pipeline:

1. **Parsing**: Class strings are tokenized, handling variant chains (`hover:`, `focus:`, `data-[state=open]:`), arbitrary values (`bg-[#ff0000]`), negative prefixes (`-translate-y-1`), and importance modifiers (`!mt-4`)

2. **Normalization**: Canonical forms are resolved (e.g., `flex-grow` becomes `grow`, `content-start` becomes `content-align-start`)

3. **Deduplication**: Duplicate utilities are eliminated, and related properties (transforms, filters) are combined

4. **CSS Generation**: Final CSS rules are emitted with unique identifiers. For motion utilities, keyframe animations and `@property` rules are also generated

5. **Delivery**: The compiled CSS is sent to clients as part of the UI stream. Clients receive only the styles they need

## Usage in Applications

In Ikon AI Apps, styles are passed as string arrays to UI components. The `Ikon.Parallax` UI system handles the integration with Crosswind automatically.

```csharp
view.Button(
    style: ["px-4 py-2 rounded-lg bg-blue-500 hover:bg-blue-600 text-white transition"],
    label: "Click me",
    onClick: async () => { }
);
```

Multiple style strings can be combined:

```csharp
private const string BaseButton = "px-4 py-2 rounded-lg font-medium transition-colors";
private const string PrimaryColors = "bg-blue-500 hover:bg-blue-600 text-white";

view.Button(
    style: [BaseButton, PrimaryColors],
    label: "Primary Action",
    onClick: async () => { }
);
```

### Organizing Styles

Applications typically organize styles into static classes with constants:

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

    public static class Card
    {
        public const string Default =
            "p-4 rounded-xl " +
            "bg-neutral-900 border border-neutral-800";

        public const string Interactive =
            Default + " " +
            "hover:border-neutral-700 transition-colors cursor-pointer";
    }
}
```

### Built-in Themes

Ikon provides built-in themes with organized style constants:

```csharp
using Ikon.Parallax.Themes.Default;

view.Button(style: [Button.PrimaryMd], label: "Submit");
view.TextField(style: [Input.Default], defaultValue: "");
view.Box(style: [Card.Default], content: view => { });
```

## Utility Classes

Crosswind supports the standard Tailwind utility classes:

| Category | Examples |
|----------|----------|
| Spacing | `p-4`, `mx-auto`, `gap-3`, `space-y-2` |
| Sizing | `w-full`, `h-screen`, `max-w-md`, `min-h-0` |
| Layout | `flex`, `grid`, `block`, `hidden`, `grid-cols-3` |
| Flexbox | `items-center`, `justify-between`, `flex-1`, `flex-wrap` |
| Typography | `text-sm`, `font-bold`, `tracking-wide`, `leading-tight` |
| Colors | `text-white`, `bg-blue-500`, `border-neutral-700` |
| Borders | `border`, `rounded-lg`, `border-2`, `divide-y` |
| Effects | `shadow-lg`, `opacity-50`, `blur-sm` |
| Transforms | `scale-105`, `rotate-45`, `-translate-y-1` |
| Transitions | `transition`, `duration-200`, `ease-in-out` |
| Interactivity | `cursor-pointer`, `select-none`, `pointer-events-none` |

### Variants

Standard Tailwind variants are supported:

```csharp
// Pseudo-classes
"hover:bg-blue-600 focus:ring-2 active:scale-95 disabled:opacity-50"

// Responsive breakpoints
"sm:flex md:grid lg:hidden"

// Dark mode
"dark:bg-neutral-900 dark:text-white"

// Data attributes
"data-[state=open]:bg-blue-500 data-[disabled]:opacity-50"

// Group and peer
"group-hover:visible peer-focus:ring-2"
```

### Arbitrary Values

Use brackets for custom values:

```csharp
// Custom colors
"bg-[#ff6b6b] text-[rgb(255,255,255)]"

// Custom spacing
"p-[13px] gap-[0.875rem]"

// Custom properties
"shadow-[0_0_20px_rgba(0,255,65,0.3)]"
```

## Motion Language

Crosswind extends Tailwind with a motion system for declarative animations. Motion utilities compile to CSS keyframe animations with proper `@property` rules for animatable custom properties.

### Keyframe Timelines

Define animations with the `motion-[...]` syntax. Steps are specified as `percentage:utilities` pairs.

Within `motion-[...]`, keyframe steps are comma-separated. Within each step, multiple utilities are separated by underscores (`_`). Underscores outside of brackets and parentheses are converted to spaces during parsing, so `opacity-0_translate-y-[12px]` is equivalent to `opacity-0 translate-y-[12px]`.

```csharp
// Fade in and slide up
"motion-[0:opacity-0_translate-y-[12px],100:opacity-100_translate-y-0]"

// Scale pulse
"motion-[0:scale-100,50:scale-[1.05],100:scale-100]"

// Complex multi-step animation
"motion-[0:opacity-0_blur-[4px],30:opacity-60_blur-[2px],100:opacity-100_blur-0]"
```

### Timing Controls

Control animation timing with dedicated utilities:

```csharp
// Duration and delay
"motion-duration-300ms motion-delay-100ms"

// Easing
"motion-ease-[cubic-bezier(0.25,1,0.35,1)]"

// Fill mode
"motion-fill-both motion-fill-forwards"

// Iteration
"motion-once motion-loop motion-ping-pong"

// Step easing (discrete/glitch effects)
"motion-ease-[steps(1)]"   // instant jumps between keyframes
"motion-ease-[steps(4)]"   // four evenly-spaced steps

// Playback rate multiplier
"motion-rate-150"           // 150% speed
```

### Staggered Text Animations

Animate text character by character, word by word, or line by line:

```csharp
// Typewriter effect - letters appear one at a time
"motion-[0:opacity-0,100:opacity-100] " +
"motion-duration-80ms motion-stagger-50ms motion-per-letter motion-fill-both"

// Words fade in sequentially
"motion-[0:opacity-0_translate-y-[8px],100:opacity-100_translate-y-0] " +
"motion-duration-200ms motion-stagger-120ms motion-per-word motion-fill-both"

// Lines reveal one by one
"motion-[0:opacity-0,100:opacity-100] " +
"motion-duration-300ms motion-stagger-200ms motion-per-line motion-fill-both"
```

#### Per-Element Modes and Compound Variants

Base modes split text (or children) into individually animated segments:

- `motion-per-letter` — each character
- `motion-per-word` — each word
- `motion-per-line` — each line (split on `\n`)
- `motion-per-paragraph` — each paragraph
- `motion-per-children` — each child element

Each base mode supports compound suffixes that combine the split with a playback modifier:

| Suffix | Effect | Example |
|--------|--------|---------|
| `-loop` | Infinite iteration | `motion-per-letter-loop` |
| `-ping-pong` | Alternate direction + infinite | `motion-per-word-ping-pong` |
| `-reverse` | Stagger from last element backward | `motion-per-line-reverse` |
| `-reverse-loop` | Reverse stagger + infinite | `motion-per-letter-reverse-loop` |

These compound variants are available for `per-letter`, `per-word`, and `per-line`.

```csharp
// Looping wave — each letter bounces continuously
"wave:motion-[0:translate-y-0,50:translate-y-[-10px],100:translate-y-0] " +
"wave:motion-duration-1200ms wave:motion-stagger-80ms wave:motion-per-letter-loop wave:motion-ease-ease-in-out"

// Reverse loop — stagger starts from the last letter
"wave:motion-[0:translate-y-0,50:translate-y-[-10px],100:translate-y-0] " +
"wave:motion-duration-1200ms wave:motion-stagger-80ms wave:motion-per-letter-reverse-loop wave:motion-ease-ease-in-out"

// Ping-pong — alternating direction per word
"motion-[0:opacity-70_scale-[0.95],100:opacity-100_scale-100] " +
"motion-duration-500ms motion-stagger-150ms motion-per-word-ping-pong"
```

### Track Prefixes

Scope motion parameters to named tracks for independent control:

```csharp
// 'title' track for text, 'glow' track for background effect
"title:motion-[0:opacity-0,100:opacity-100] title:motion-duration-300ms title:motion-per-letter " +
"glow:motion-[0:scale-100,50:scale-[1.02],100:scale-100] glow:motion-duration-2000ms glow:motion-loop"
```

### State-Based Animations

Combine motion with data attribute variants for state-driven animations:

```csharp
// Dialog content animation
"data-[state=open]:motion-[0:opacity-0_scale-[0.95],100:opacity-100_scale-100] " +
"data-[state=open]:motion-duration-200ms data-[state=open]:motion-fill-both " +
"data-[state=closed]:motion-[0:opacity-100,100:opacity-0] " +
"data-[state=closed]:motion-duration-150ms data-[state=closed]:motion-fill-both"
```

### 3D Transforms in Keyframes

Crosswind supports 3D rotation and translation utilities inside keyframe steps: `rotate-x-[angle]`, `rotate-y-[angle]`, and `translate-z-[length]`. These emit CSS custom properties with auto-registered `@property` rules so they animate smoothly.

```csharp
// Card flip (Y-axis rotation)
"motion-[0:rotate-y-0,50:rotate-y-[180deg],100:rotate-y-[360deg]] " +
"motion-duration-3000ms motion-loop motion-ease-ease-in-out"

// Depth pop with translate-z
"motion-[0:translate-z-[-50px]_blur-[3px]_opacity-50_scale-[0.95]," +
"50:translate-z-[10px]_blur-0_opacity-100_scale-[1.02]," +
"100:translate-z-0_blur-0_opacity-100_scale-100] " +
"motion-duration-600ms motion-stagger-40ms motion-per-letter-loop motion-ease-ease-out"

// Cube face rotation (combined X + Y)
"motion-[0:rotate-x-0_rotate-y-0," +
"25:rotate-x-[90deg]_rotate-y-0," +
"50:rotate-x-[90deg]_rotate-y-[90deg]," +
"75:rotate-x-0_rotate-y-[90deg]," +
"100:rotate-x-0_rotate-y-0] " +
"motion-duration-4000ms motion-loop motion-ease-ease-in-out"
```

### Filter Animations in Keyframes

Filter functions animate smoothly inside `motion-[...]` keyframes. Crosswind auto-registers `@property` rules for filter-related custom properties, enabling proper interpolation.

Supported filter utilities: `blur`, `brightness`, `contrast`, `hue-rotate`, `saturate`, `grayscale`, `sepia`, `invert`.

```csharp
// Hue rotation cycle — rainbow color shifting
"motion-[0:hue-rotate-0,100:hue-rotate-[360deg]] " +
"motion-duration-3000ms motion-loop motion-ease-linear"

// Brightness flash
"motion-[0:brightness-100,15:brightness-[2],30:brightness-100,100:brightness-100] " +
"motion-duration-2000ms motion-loop"

// Saturate pulse
"motion-[0:saturate-100,50:saturate-[2],100:saturate-100] " +
"motion-duration-1500ms motion-loop motion-ease-ease-in-out"

// Grayscale fade
"motion-[0:grayscale-0,50:grayscale-100,100:grayscale-0] " +
"motion-duration-4000ms motion-loop motion-ease-ease-in-out"

// Combined filters (blur + brightness + hue-rotate)
"motion-[0:blur-0_brightness-100_hue-rotate-0," +
"25:blur-[2px]_brightness-[1.2]_hue-rotate-[45deg]," +
"50:blur-[4px]_brightness-[1.5]_hue-rotate-[90deg]," +
"75:blur-[2px]_brightness-[1.2]_hue-rotate-[135deg]," +
"100:blur-0_brightness-100_hue-rotate-[180deg]] " +
"motion-duration-4000ms motion-loop motion-ease-ease-in-out"
```

### Text Shadow Animations in Keyframes

`text-shadow-[...]` can be used inside keyframe steps for chromatic aberration and glow effects. Since text-shadow values are arbitrary, they use `'*'` syntax in `@property` and interpolate as whole values.

```csharp
// Chromatic aberration glitch
"glitch:motion-[0:text-shadow-[0_0_0_transparent,0_0_0_transparent]," +
"20:text-shadow-[3px_0_0_rgba(255,0,0,0.8),-3px_0_0_rgba(0,255,255,0.8)]," +
"40:text-shadow-[-2px_1px_0_rgba(255,0,0,0.6),2px_-1px_0_rgba(0,255,255,0.6)]," +
"60:text-shadow-[2px_0_0_rgba(255,0,0,0.8),-2px_0_0_rgba(0,255,255,0.8)]," +
"80:text-shadow-[-1px_-1px_0_rgba(255,0,0,0.5),1px_1px_0_rgba(0,255,255,0.5)]," +
"100:text-shadow-[0_0_0_transparent,0_0_0_transparent]] " +
"glitch:motion-duration-150ms glitch:motion-loop glitch:motion-ease-[steps(1)]"

// Neon glow pulse
"glow:motion-[0:text-shadow-[0_0_0_rgba(0,0,0,0)]," +
"25:text-shadow-[0_0_0.5em_rgba(255,0,128,0.5)]," +
"50:text-shadow-[0_0_0.8em_rgba(255,100,150,0.4)]," +
"75:text-shadow-[0.1em_0_0_rgba(255,0,100,0.6),-0.1em_0_0_rgba(255,150,200,0.6)]," +
"100:text-shadow-[0_0_0_rgba(0,0,0,0)]] " +
"glow:motion-duration-3000ms glow:motion-loop"
```

### Common Animation Patterns

Entry animations:

```csharp
public static class Enter
{
    public const string FadeUp =
        "motion-[0:opacity-0_translate-y-[12px],100:opacity-100_translate-y-0] " +
        "motion-duration-300ms motion-ease-[cubic-bezier(0.25,1,0.35,1)] motion-fill-both";

    public const string ScaleIn =
        "motion-[0:opacity-0_scale-[0.95],100:opacity-100_scale-100] " +
        "motion-duration-300ms motion-ease-[cubic-bezier(0.25,1,0.35,1)] motion-fill-both";
}
```

Hover effects (CSS transitions are often better for hover states):

```csharp
public static class Hover
{
    // CSS transition - smoother for hover
    public const string Lift =
        "hover:-translate-y-[2px] hover:shadow-lg transition-all duration-200";

    // Motion-based hover (for complex sequences)
    public const string Glitch =
        "hover:motion-[0:translate-x-0,30:translate-x-[2px],60:translate-x-[-1px],100:translate-x-0] " +
        "hover:motion-duration-200ms";
}
```

Looping effects:

```csharp
public static class Loop
{
    public const string Pulse =
        "motion-[0:opacity-70,50:opacity-100,100:opacity-70] " +
        "motion-duration-2000ms motion-loop motion-ease-ease-in-out";

    public const string Breathe =
        "motion-[0:scale-100,50:scale-[1.02],100:scale-100] " +
        "motion-duration-3000ms motion-loop motion-ease-ease-in-out";
}
```

### Animatable Properties

The following properties animate smoothly in `motion-[...]` keyframe animations:

- **Opacity**: `opacity`
- **2D transforms**: `translate-x`, `translate-y`, `scale`, `scale-x`, `scale-y`, `rotate`, `skew-x`, `skew-y`
- **3D transforms**: `rotate-x`, `rotate-y`, `translate-z`
- **Filter functions**: `blur`, `brightness`, `contrast`, `grayscale`, `hue-rotate`, `invert`, `saturate`, `sepia`
- **Colors**: `text-*`, `bg-*`, `border-*` (color values)
- **Text shadow**: `text-shadow-[...]` (arbitrary values)
- **Border properties**: `border-{n}` (width), `border-{color}`, `rounded-*` (border-radius)
- **Ring and outline**: `ring-{n}`, `outline-offset-{n}`
- **Box shadow**: `shadow-[...]` (arbitrary values)

Crosswind auto-registers `@property` rules for filter functions, transform variables, and typed custom properties (colors, lengths, angles, numbers). This enables smooth CSS interpolation without manual setup.

### Advanced Motion Utilities

Crosswind supports CSS Animations Level 2 properties for scroll-driven animations, composition control, and playback management.

#### Scroll Timelines

Declare a scroll timeline on a scroll container, then bind an animation track to it:

```csharp
// On the scroll container
"scroll-timeline-[--hero_y]"

// On the animated element
"lead:motion-[0:opacity-0,100:opacity-100] lead:motion-timeline-[--hero]"
```

#### Animation Composition

Control how multiple animations combine on the same element:

```csharp
// Additive composition — transforms blend instead of replacing
"pulse:motion-[0:scale-100,100:scale-110] pulse:motion-composition-add"
```

Values: `replace` (default), `add`, `accumulate`.

#### Play State Control

Pause and resume animations programmatically:

```csharp
"lead:motion-play-state-paused"    // starts paused
"lead:motion-play-state-running"   // resumes
```

#### Animation Range

Clamp animation playback to a portion of a scroll timeline:

```csharp
"halo:motion-range-[entry_0%_exit_60%]"
"halo:motion-range-start-[entry_10%]"
"halo:motion-range-end-[exit_90%]"
```

#### Motion Priority

Control stagger ordering with a priority hint (0–999):

```csharp
"motion-priority-0"     // default
"motion-priority-100"   // higher priority staggers first
```

## Complete Example

A button component combining multiple style aspects:

```csharp
public static class Button
{
    private const string Base =
        "px-4 py-2 rounded-lg font-medium " +
        "transition-all duration-200";

    private const string PrimaryColors =
        "bg-blue-500 hover:bg-blue-600 active:bg-blue-700 " +
        "text-white border border-blue-400/50";

    private const string HoverEffect =
        "hover:-translate-y-[1px] hover:shadow-lg";

    private const string ActivePress =
        "active:motion-[0:scale-100,50:scale-[0.97],100:scale-100] " +
        "active:motion-duration-150ms";

    public const string Primary = Base + " " + PrimaryColors + " " + HoverEffect + " " + ActivePress;
}

// Usage
view.Button(style: [Button.Primary], label: "Submit", onClick: async () => { });
```

## Common Pitfalls and Solutions

### Full-Screen Layouts with Padding

Both approaches work correctly because Crosswind includes `box-sizing: border-box` in its preflight (like Tailwind):

```csharp
// Option 1: Padding on Root (preferred for semantic clarity)
UI.Root(style: ["h-screen bg-slate-950 p-4"], content: view =>
{
    view.Column(style: ["w-full h-full"], content: col => { ... });
});

// Option 2: Padding on inner container (also works)
UI.Root(style: ["h-screen bg-slate-950"], content: view =>
{
    view.Column(style: ["w-full h-full p-4"], content: col => { ... });
});
```

With `border-box`, padding is included in the element's dimensions, so `h-full p-4` means "100% height with padding inside" rather than "100% + padding".

### Width and Sizing Context

Design width with padding, alignment, and flex proportions — never hardcoded pixel widths for layout containers.

**Percentage widths need context:** Classes like `w-1/4` or `w-1/3` resolve against the parent's computed width. If the parent is `position: absolute` with no explicit width, or has `width: auto` without flex constraints, the percentage resolves to zero. The element with the percentage class must be a direct child of a flex/grid container or a parent with an explicit width.

```csharp
// WRONG — percentage on child of auto-width absolute element
view.Box(["absolute"], content: view =>
{
    view.Column(["w-1/4"], ...); // Collapses to zero!
});

// RIGHT — percentage on child of flex container
view.Row(["flex-1 min-w-0"], content: view =>
{
    view.Column(["w-1/4 flex-shrink-0"], ...); // 25% of parent flex item
    view.Column(["flex-1 min-w-0"], ...);      // Remaining space
});
```

**Panel pattern:** Use `Panel.*` theme constants for side panels — they bundle proportional width + minimum + `flex-shrink-0`:

| Constant | Value | Use case |
|---|---|---|
| `Panel.Sidebar` | `w-1/4 min-w-48 flex-shrink-0` | Standard sidebar |
| `Panel.SidebarNarrow` | `w-1/5 min-w-40 flex-shrink-0` | Compact sidebar |
| `Panel.Side` | `w-1/3 min-w-48 flex-shrink-0` | Log/artifact/detail panels |
| `Panel.Wide` | `w-2/5 min-w-64 flex-shrink-0` | Wide side panel |
| `Panel.Fill` | `flex-1 min-w-0` | Fluid content area |

**When pixel widths are acceptable:** Floating overlays (popovers, tooltips, dropdowns), small decorative elements (status dots, avatars), and fixed-size interactive controls. Never use pixel widths for layout-level containers like sidebars or content areas.

### Icon Sizing

Icons automatically size and center their SVG content. Just set width and height:

```csharp
row.Icon(style: ["w-4 h-4"], name: "message-circle");  // 16x16
row.Icon(style: ["w-5 h-5"], name: "settings");        // 20x20
```

Note: The Icon component internally uses `display: inline-flex` to ensure width/height CSS properties work correctly (CSS width/height don't apply to inline elements by default).

### Canonical Icon + Text Pattern

This is the robust, clean pattern that works everywhere:

```csharp
// Button with icon and text
view.Button(
    style: ["text-white bg-blue-600 px-4 py-2 rounded-lg"],  // Always set text color!
    content: btn =>
    {
        btn.Row(style: ["flex items-center gap-3"], content: row =>
        {
            row.Icon(style: ["w-4 h-4"], name: "play");
            row.Text(text: "Activate");
        });
    });
```

**Key rules:**
1. **Button**: Always set `text-white` (or appropriate color) - icons inherit text color
2. **Row**: Use `flex items-center gap-3` for alignment and spacing
3. **Icon**: Just `w-4 h-4` for size - no other classes needed
4. **Text**: No style needed - inherits from parent

### Common Mistakes

```csharp
// WRONG: Missing text color = black/invisible icons
style: ["bg-blue-600 ..."]

// CORRECT: Always include text color
style: ["text-white bg-blue-600 ..."]
```

### Standard Sizes

Use theme constants or explicit sizes:

| Size | Theme Constant | Classes | Pixels |
|------|----------------|---------|--------|
| Extra small | `Icon.Size.Xs` | `w-4 h-4 shrink-0` | 16px |
| Small | `Icon.Size.Sm` | `w-5 h-5 shrink-0` | 20px |
| Medium (default) | `Icon.Size.Md` | `w-6 h-6 shrink-0` | 24px |
| Large | `Icon.Size.Lg` | `w-8 h-8 shrink-0` | 32px |

Common gaps: `gap-2` (tight), `gap-3` (normal), `gap-4` (spacious)

### Fullscreen Effects and Overflow

Animations that translate elements outside their container bounds (e.g. a sweep band animating `translate-y` from `-100px` to `900px`) will trigger unwanted scrollbars. Always add `overflow-hidden` to the container that holds such overlay elements:

```csharp
// WRONG: sweep band moves outside bounds, creates scrollbar
view.Column(style: ["absolute inset-0 pointer-events-none"], content: overlay =>
{
    overlay.Box(style: ["absolute w-full h-[2px] bg-white/10 " +
        "motion-[0:translate-y-[-100px],100:translate-y-[900px]] motion-duration-4000ms motion-loop"]);
});

// CORRECT: overflow-hidden prevents scrollbar
view.Column(style: ["absolute inset-0 pointer-events-none overflow-hidden"], content: overlay =>
{
    overlay.Box(style: ["absolute w-full h-[2px] bg-white/10 " +
        "motion-[0:translate-y-[-100px],100:translate-y-[900px]] motion-duration-4000ms motion-loop"]);
});
```

This applies to any fullscreen overlay effect: scan lines, sweep bands, CRT overlays, vignettes with scale animations, etc.

### Responsive Breakpoints

**All UIs must be built responsively using breakpoint prefixes.** Never use server-side viewport detection or ad-hoc mechanisms — always use CSS breakpoints (`sm:`, `md:`, `lg:`, `xl:`, `2xl:`) for responsive behavior. Mobile-first means unprefixed styles apply to all sizes, then larger breakpoints override:

```csharp
// Padding: 12px on mobile, 16px on sm+, 24px on md+
view.Column(style: ["p-3 sm:p-4 md:p-6"], content: col => { ... });

// Hidden on mobile, visible on sm+
row.Text(text: "Projects", style: ["hidden sm:block"]);

// Different layouts per breakpoint
view.Column(style: ["flex flex-col sm:flex-row"], content: col => { ... });

// Sidebar: overlay on mobile, inline on desktop
view.Box(style: ["absolute inset-y-0 left-0 z-50 md:static md:z-auto"], ...);

// Backdrop: visible on mobile only
view.Box(style: ["absolute inset-0 bg-black/50 z-40 md:hidden"], ...);
```

Never hardcode sizes on content elements. Use responsive grids (`grid-cols-[repeat(auto-fill,minmax(220px,1fr))]`) for card layouts and `truncate` for text overflow instead of relying on fixed container widths.

## Sophisticated UI Design Patterns

### Visual Hierarchy with Gradients

Use gradients for primary actions and solid colors for secondary actions:

```csharp
// Primary button - gradient with shadow
view.Button(
    style: ["px-4 py-2 text-sm bg-gradient-to-r from-blue-600 to-purple-600 hover:from-blue-500 hover:to-purple-500 rounded-xl font-medium transition-all shadow-lg"],
    label: "Primary Action",
    onClick: async () => { });

// Secondary button - subtle with border
view.Button(
    style: ["px-4 py-2 text-sm bg-slate-700/50 hover:bg-slate-600/50 text-slate-300 hover:text-white rounded-xl font-medium transition-all border border-slate-600/50"],
    label: "Secondary",
    onClick: async () => { });
```

### Icon Containers with Gradient Backgrounds

Wrap icons in styled containers for visual weight:

```csharp
container.Column(style: ["w-8 h-8 rounded-lg bg-gradient-to-br from-blue-500/20 to-purple-500/20 flex items-center justify-center flex-shrink-0 border border-slate-600/30"], content: iconWrap =>
{
    iconWrap.Icon(style: ["w-4 h-4 text-blue-400"], name: "wrench");
});
```

### Cards and Containers

Use semi-transparent backgrounds with subtle borders:

```csharp
// Card with hover state
list.Column(style: [
    "bg-slate-800/50 rounded-2xl p-4 cursor-pointer transition-all border",
    isSelected ? "border-blue-500/50 bg-slate-800/80" : "border-slate-700/50 hover:bg-slate-700/50 hover:border-slate-600/50"
], content: card => { ... });

// Nested content container
details.Row(style: ["flex items-start gap-3 bg-slate-900/50 p-3 rounded-xl border border-slate-700/30"], content: row => { ... });
```

### Badges and Pills

Use rounded-full for pill-shaped badges:

```csharp
// Status badge with gradient
titleRow.Text(text: "● ACTIVE", style: ["text-xs px-2.5 py-1 rounded-full bg-gradient-to-r from-blue-600 to-purple-600 font-medium shadow-sm"]);

// Tag badge - solid color
titleRow.Text(text: "manual", style: ["text-xs px-2.5 py-1 rounded-full bg-slate-600 font-medium"]);

// Trigger pills in a horizontal list
container.Row(style: ["flex flex-wrap gap-2"], content: list =>
{
    list.Row(style: ["flex items-center gap-2 text-xs text-slate-300 bg-slate-800/80 px-3 py-1.5 rounded-full border border-slate-600/50"], content: pill =>
    {
        pill.Icon(style: ["w-3 h-3 text-purple-400"], name: "hash");
        pill.Text(text: "keyword");
    });
});
```

### Color Consistency

Maintain a cohesive color palette throughout the app:

| Role | Classes |
|------|---------|
| Primary accent | `from-blue-600 to-purple-600` (gradient) |
| Backgrounds | `slate-800/30`, `slate-900/50` (semi-transparent) |
| Borders | `slate-700/50`, `slate-600/50` (subtle) |
| Primary text | `text-white` |
| Secondary text | `text-slate-300` |
| Muted text | `text-slate-400`, `text-slate-500` |
| Accent icons | `text-blue-400`, `text-purple-400` |
| Neutral icons | `text-slate-400` |

### Spacing Scale

Use consistent spacing throughout:

```csharp
// Container padding (responsive)
"p-3 sm:p-4 md:p-6"

// Gap between items
"gap-2" // tight (8px)
"gap-3" // comfortable (12px)
"gap-4" // spacious (16px)

// Vertical spacing in lists
"space-y-2" // tight
"space-y-3" // comfortable
"space-y-4" // spacious
```

### Transitions and Interactions

Add subtle transitions for polished interactions:

```csharp
"transition-all duration-200" // for color and transform changes
"hover:bg-slate-700/50"       // subtle hover background
"hover:text-white"            // brighten text on hover
"hover:border-slate-600/50"   // subtle border change
```

## Related Documentation

- [Crosswind Motion Spec](crosswind-motion-spec.md) — formal grammar and syntax specification for the motion language
- [Crosswind Tailwind Spec](crosswind-tailwind-spec.md) — complete reference of all supported Tailwind utility classes
