# Crosswind Motion Spec

A Tailwind-inspired, class-based DSL to describe visual motion timelines and audio behaviors using only class strings. This spec defines **tokens, forms, and grammar**. It intentionally avoids runtime/implementation details.

---

## 0) Conventions

* **Case:** all keywords and identifiers are lowercase ASCII.
* **Separators:** classes are whitespace-separated. Prefixes are colon-separated.
* **Whitespace inside brackets `[...]`:** spaces are allowed; leading/trailing spaces are ignored.
* **Escaping inside `[...]`:** to include `]` use `\]`. Backslash escapes any following char.
* **Underscore separator:** inside `motion-[...]` step utilities, `_` outside of brackets and parentheses is treated as whitespace. This allows `opacity-0_translate-y-[12px]` as equivalent to `opacity-0 translate-y-[12px]`.
* **Numbers:** decimal (`12`, `0.25`) with optional sign; no thousands separators.
* **Durations:** `<number>ms` or `<number>s` (e.g., `150ms`, `0.2s`).
* **Easings:** keywords (`linear`, `ease-in`, `ease-out`, `ease-in-out`) or `cubic-bezier(a,b,c,d)` with `a..d` numbers.
* **Identifiers:** `[a-z][a-z0-9_-]*`.
* **Negative utilities:** Tailwind-style minus prefix is allowed: `-translate-x-1`.
* **Transform variables:** transform utilities with track prefixes emit CSS custom properties of the form `--tw-xform-<hash>`.
  The `<hash>` is a deterministic value derived from the track label and transform payload, ensuring variables remain unique
  across components and tracks.

---

## 1) Prefix Chain

A **class token** may be preceded by zero or more prefixes in this order:

```
<variant-prefix>:* <track-prefix>:* <core-directive>
```

* **Variant prefixes (reserved keyword forms):**
  * Element pseudo-classes: `hover`, `focus`, `active`, `visited`, `disabled`, `enabled`, `required`, `optional`, `invalid`, `valid`, `autofill`, `placeholder-shown`, `read-only`, `read-write`, `target`, `empty`, `focus-visible`, `focus-within`, `checked`, `indeterminate`, `in-range`, `out-of-range`, `default`, `first`, `last`, `first-of-type`, `last-of-type`, `only`, `only-child`, `only-of-type`, `odd`, `even`, `open`.
  * Pseudo-elements: `before`, `after`, `first-letter`, `first-line`, `selection`, `marker`, `placeholder`, `file`, `backdrop`.
  * Group/peer scopes: `group-<state>` and `peer-<state>` where `<state>` is a pseudo-class, pseudo-element, or explicit selector in brackets `[selector]`.
  * Attribute/state forms: `aria-<name>[-<value>]`, `data-<name>[-<value>]`, `lang-[<tag>]`, `has-[<selector>]`.
  * Theme scoping: `theme-<name>` (if theme variants are enabled).
* **Track prefix:** any identifier **not** matching a reserved variant. Tracks may refer to:
  * Responsive/media contexts: `sm`, `md`, `lg`, `xl`, `2xl`, `print`, `portrait`, `landscape`, `motion-reduce`, `motion-safe`, `pointer-hover`, `pointer-none`, `any-pointer-hover`, `any-pointer-none`, `contrast-more`, `contrast-less`.
  * Container queries: `min-<breakpoint>` / `max-<breakpoint>` (Tailwind breakpoint tokens) and `supports-[<condition>]` (underscores → spaces; appends `: var(--tw)` if missing a colon).
  * Color/direction scopes: `dark`, `light`, `rtl`, `ltr`.
  * Custom parent selectors: anything else (e.g., `.prose`, `#panel`, `[data-mode=hero]`).
  Zero or more track prefixes are allowed; the innermost (closest to the directive) owns that directive.

Examples:

```
hover:motion-[...]                 // variant only
glitch:motion-[...]                // track only
hover:glitch:motion-[...]          // variant + track
group-hover:glitch:motion-loop     // variant + track + flag
```

---

## 2) Core Directives (tokens)

All directives are classes (whitespace-separated items). Many accept **dash parameters** or **bracket payloads**.

### 2.1 Motion Timeline Block

```
motion-[ <step>( , <step> )* ]
```

* **Step:** `<time> : <step-utilities>`
* **Time:** either **percent** (`0..100` as integer or decimal without `%`) **or** **duration** (`<number>ms|s`).
  **Rule:** all steps in one block MUST use the same time basis (percent **or** duration).
* **Step utilities:** one or more **utility tokens**, separated by spaces.
  A utility token is any Tailwind-like utility (e.g., `opacity-0`, `scale-105`, `-translate-x-1`) **or** a property with arbitrary value `name-[value]`.

Examples:

```
motion-[0:opacity-0,100:opacity-100]
motion-[0:opacity-0 scale-95, 100:opacity-100 scale-100]
glitch:motion-[0:opacity-100 -translate-x-1,10:opacity-0 translate-x-1,20:opacity-100 translate-x-0]
```

### 2.2 Motion Track Timing & Flags

All may be prefixed by variants and/or a track.

* `motion-duration-<dur>` or `motion-duration-[<dur>]`
  `<dur>` is a duration literal (`250ms`, `0.6s`).
* `motion-rate-<pct>` or `motion-rate-[<number>]`
  Playback rate multiplier (e.g., `150` = 150%). **Syntax only**; semantics are impl-defined.
* `motion-ease-<keyword>` or `motion-ease-[cubic-bezier(...)]`
* `motion-delay-<dur>` or `motion-delay-[<dur>]` (alias: `motion-track-delay-<dur>`)
  Delay applied to the entire track before playback starts.
* `motion-timeline-<keyword>` or `motion-timeline-[<timeline>]`
  Assigns the CSS `animation-timeline` value for the track. Bracket payloads support arbitrary timeline expressions (`scroll()`, `view()`, custom timeline names, etc.).
* `motion-composition-<mode>` or `motion-composition-[<mode>]`
  Maps to `animation-composition`; `<mode>` follows CSS Animations Level 2 (`replace|add|accumulate`).
* `motion-play-state-<state>` or `motion-play-state-[<state>]`
  Controls `animation-play-state` (`running|paused` plus arbitrary states for future expansion).
* `motion-range-[<value>]`
  Emits `animation-range` for the track. Payloads follow CSS shorthand syntax (e.g., `entry 10% exit 90%`).
* `motion-range-start-[<value>]` / `motion-range-end-[<value>]`
  Emit `animation-range-start` and `animation-range-end` respectively. Values support keywords (`normal|entry|exit|contain|cover`) and arbitrary timeline offsets.
* `motion-letter-delay-<dur>` or `motion-letter-delay-[<dur>]` (sequential offset; alias: `motion-stagger-<dur>`)
* `motion-fill-<mode>` where `<mode>` ∈ `none|forwards|backwards|both`
* `motion-loop` (boolean flag)
* `motion-once` (boolean flag)
* `motion-ping-pong` (boolean flag; alternates playback direction)
* `motion-per-letter` (boolean flag)
* `motion-per-letter-loop` (boolean flag; combines `motion-per-letter` with `motion-loop`)
* `motion-per-letter-ping-pong` (boolean flag; combines `motion-per-letter` with `motion-ping-pong`)
* `motion-per-letter-reverse` (boolean flag; pairs with `motion-per-letter` to stagger from the last glyph backward)
* `motion-per-letter-reverse-loop` (boolean flag; combines `motion-per-letter-reverse` with `motion-loop`)
* `motion-per-word` (boolean flag)
* `motion-per-word-loop` (boolean flag; combines `motion-per-word` with `motion-loop`)
* `motion-per-word-ping-pong` (boolean flag; combines `motion-per-word` with `motion-ping-pong`)
* `motion-per-word-reverse` (boolean flag; pairs with `motion-per-word` to stagger from the last word backward)
* `motion-per-word-reverse-loop` (boolean flag; combines `motion-per-word-reverse` with `motion-loop`)
* `motion-per-line` (boolean flag)
* `motion-per-line-loop` (boolean flag; combines `motion-per-line` with `motion-loop`)
* `motion-per-line-ping-pong` (boolean flag; combines `motion-per-line` with `motion-ping-pong`)
* `motion-per-line-reverse` (boolean flag; pairs with `motion-per-line` to stagger from the last line backward)
* `motion-per-line-reverse-loop` (boolean flag; combines `motion-per-line-reverse` with `motion-loop`)
* `motion-per-paragraph` (boolean flag)
* `motion-per-children` (boolean flag)
* `motion-priority-<int>` or `motion-priority-[<int>]` (track precedence hint; syntax only)

Examples:

```
glow:motion-duration-800ms glow:motion-ease-ease-in-out glow:motion-loop
motion-delay-[120ms] motion-fill-both
title:motion-per-letter title:motion-letter-delay-60ms
```

**Per-track semantics.** Each Level 2 utility stores its value on the addressed track. During compilation Crosswind emits
comma-separated longhands only when a track overrides that property and fills in defaults (`auto`, `replace`, `running`,
`normal`) for tracks that omit them, so you can pause or retarget one layer without affecting the others.

Concrete patterns:

```html
<div class="scroll-timeline-[--hero y]">
  <div class="lead:motion-[0:opacity-0,100:opacity-100] lead:motion-timeline-[--hero]
              lead:motion-play-state-paused body:motion-[0:scale-95,100:scale-100]">
    ...
  </div>
</div>
```

* `lead:` binds its track to the scroll timeline and starts paused so a class toggle can resume it while the unprefixed track
  plays immediately.
* Adding `flare:motion-composition-add` later yields `animation-composition: replace, add, replace`, letting the additive track
  blend with the existing ones instead of replacing them.

```html
<button class="pulse:motion-[0:scale-100,100:scale-110] pulse:motion-composition-add
                 halo:motion-[0:opacity-0,100:opacity-100] halo:motion-range-[entry 0% exit 60%]">
  CTA
</button>
```

* `pulse:` accumulates with other transforms while `halo:` clamps its playback window to the first 60 % of the timeline.

### 2.3 Input Binding

Binds a **virtual timeline progress** (0–100) to an input source.

* **Binding source & range**

  ```
  motion-bind-<source>/[<min>-<max>]
  ```

  `<source>` ∈ `scrollx|scrolly|dragx|dragy|value|time`.
  `<min>`, `<max>` are numbers (units depend on source; syntax only).

* **Clamp policy** (empty brackets default to `clamp`)

  ```
  motion-bind-[clamp]           // default
  motion-bind-[freeze-start]
  motion-bind-[freeze-end]
  motion-bind-[unclamped]
  ```

* **Direction**

  ```
  motion-bind-reverse
  ```

* **Input easing**

  ```
  motion-bind-ease-<keyword>
  motion-bind-ease-[cubic-bezier(...)]
  ```

* **Output mapping (window remap)**

  ```
  motion-map-[<a>..<b>-><c>..<d>]
  ```

  All `<a..d>` are 0–100 numbers (syntax).

> **Relation to CSS scroll-driven animation primitives.**
> Crosswind now emits CSS Animations Level 2 longhands (`animation-timeline`, `animation-range`,
> `animation-composition`, `animation-play-state`) when the matching utilities are present.
> Use `scroll-timeline-[...]` on scrolling containers to declare timelines and pair them with
> `motion-timeline-*` track assignments. Existing `motion-bind-*` directives remain available for
> declarative metadata and backwards compatibility with runtime-driven bindings.

Examples:

```
motion-bind-scrolly/[100-500] motion-bind-ease-[cubic-bezier(0.4,0,0.2,1)] motion-bind-[clamp]
motion-map-[0..100->10..90] motion-bind-reverse
```

### 2.4 Scroll Timelines

```
scroll-timeline-[<value>]
```

* Emits the `scroll-timeline` shorthand on the current element.
* Payloads can combine timeline names and axes (e.g., `scroll-timeline-[--hero x]`) or function-style definitions (`scroll()`, `view()`).
* Multiple values are supported via comma-separated payloads inside the brackets.

### 2.5 Audio: Sources, Triggers, Automation

> **Note:** The audio directives described in this section define syntax for future implementation. They are not currently processed by the Crosswind compiler.

#### 2.5.1 Source Attachment

```
sfx:source-[<uri-or-id>]
```

* Payload accepts any non-empty string; `]` must be escaped as `\]`.
* Multiple sources may be specified with different track prefixes or IDs (see below).

Optional hints (boolean / identifiers):

```
sfx:prime                      // hint to prime/preload a source
sfx:id-[<identifier>]          // label a source for reuse (syntax)
```

#### 2.5.2 Trigger Playback

```
<variant>:sfx:play
<variant>:sfx:play-[<id>]      // target a labeled source
```

* Without `[<id>]`, targets the nearest `sfx:source-[...]` in the same class list (syntax ordering is not enforced; selection is impl-defined).

#### 2.5.3 Parameter Automation (within motion steps)

Audio parameters are expressible as utilities inside `motion-[...]` steps:

```
volume-[<0..1>]
pitch-[<number>]               // 1.0 = normal
pan-[-1..1]
reverb-[<0..1>]
filter-[<number><unit>?]       // e.g., 800Hz, 1kHz (unit text is free-form)
```

Examples:

```
sfx:source-[/snd/zap.wav] sfx:prime hover:sfx:play
sfx:motion-[0:volume-[0],10:volume-[1] pan-[-0.3],100:volume-[0]]
click:sfx:play-[zap]
sfx:id-[zap] sfx:source-[/snd/zap.wav]
```

#### 2.5.4 Shorthand Alias (optional)

```
<variant>:sound-[<uri>]
```

**Purely syntactic sugar** equivalent to:

```
sfx:source-[<uri>] <variant>:sfx:play
```

### 2.6 Presets & Track Aliases

* **Preset expansion**

  ```
  motion-track-<name>
  ```

  A macro token that expands (outside this spec’s scope) into one or more `motion-*` and/or `motion-[...]` directives.

* **Named track timelines (inline)**

  ```
  <track>:motion-[...]
  <track>:motion-duration-...
  ```

  `<track>` is any identifier.

Examples:

```
motion-track-glow glitch:motion-[...]
glitch:motion-duration-300ms glitch:motion-loop
```

---

## 3) Utility Tokens inside `motion-[...]`

Inside a timeline step, **utilities** follow Tailwind forms:

* **Named tokens:** `opacity-0`, `scale-105`, `shadow-xl`, etc.
* **Negative prefix:** `-translate-x-1`, `-rotate-3`.
* **Arbitrary values:** `translate-x-[3.5rem]`, `rotate-[12deg]`, `shadow-[0_0_10px_rgba(0,0,0,0.4)]`.
* **Audio params:** as listed in §2.5.3.

**Separator:** single space or `_` (underscore) between utilities. Underscores outside of brackets and parentheses are normalized to spaces.
**Commas:** separate steps.
**Colons:** separate `time` and `utilities` in a step.

Example (mixed utilities):

```
motion-[0:opacity-0 -translate-y-[8px], 100:opacity-100 translate-y-0]
```

---

## 4) Variant Prefixes (reserved list)

The following identifiers are **reserved** as variants when used as a prefix ending with `:`:

* Element pseudo-classes and pseudo-elements listed in §1.
* `group-<state>`, `peer-<state>`, `aria-<name>[-<value>]`, `data-<name>[-<value>]`, `lang-[<tag>]`, `has-[<selector>]`, `theme-<name>`.

> Any other prefix is treated as a **track** label (see §1).

---

## 5) Formal Grammar (EBNF)

> Notes:
> • Terminals in **bold**; literals in quotes.
> • `_` denotes optional whitespace.
> • This grammar covers syntax only; semantic constraints are listed after.

```
document        ::= ( WS? class-token WS? )*

class-token     ::= (prefix ":")* core-directive

prefix          ::= variant-prefix | track-prefix

variant-prefix  ::= pseudo-class-variant | pseudo-element-variant
                  | group-variant | peer-variant
                  | aria-variant | data-variant
                  | lang-variant | has-variant
                  | theme-variant

track-prefix    ::= identifier | supports-track | selector-track

core-directive  ::= motion-block
                  | motion-param
                  | motion-flag
                  | bind-directive
                  | map-directive
                  | scroll-timeline-directive
                  | audio-source
                  | audio-trigger
                  | audio-flag
                  | preset

scroll-timeline-directive ::= "scroll-timeline-" bracket-value

motion-block    ::= "motion-" bracket-steps

bracket-steps   ::= "[" WS? step ( WS? "," WS? step )* WS? "]"

step            ::= time WS? ":" WS? step-utilities

time            ::= percent | duration

percent         ::= number        // 0..100 recommended; '%' not written
duration        ::= number ( "ms" | "s" )

step-utilities  ::= utility ( ( WS+ | "_" ) utility )*

utility         ::= neg? utility-name ( "-" utility-atom )*
                  | utility-name "-" bracket-value
                  | audio-param

neg             ::= "-"

utility-name    ::= identifier

utility-atom    ::= identifier | number

audio-param     ::= ( "volume" | "pitch" | "pan" | "reverb" | "filter" ) "-" bracket-value

motion-param    ::= "motion-duration-"      duration-or-bracket
                  | "motion-rate-"          number-or-bracket
                  | "motion-ease-"          easing-or-bracket
                  | "motion-delay-"         duration-or-bracket
                  | "motion-track-delay-"   duration-or-bracket
                  | "motion-letter-delay-"  duration-or-bracket
                  | "motion-stagger-"       duration-or-bracket
                  | "motion-fill-"          fill-mode
                  | "motion-priority-"      int-or-bracket
                  | "motion-timeline-"      identifier-or-bracket
                  | "motion-composition-"   identifier-or-bracket
                  | "motion-play-state-"    identifier-or-bracket
                  | "motion-range-"         bracket-value
                  | "motion-range-start-"   bracket-value
                  | "motion-range-end-"     bracket-value

duration-or-bracket   ::= duration | bracket-value
number-or-bracket     ::= number   | bracket-value
easing-or-bracket     ::= easing   | bracket-value
int-or-bracket        ::= integer  | bracket-value
identifier-or-bracket ::= identifier | bracket-value

fill-mode      ::= "none" | "forwards" | "backwards" | "both"

motion-flag    ::= "motion-loop" | "motion-once" | "motion-ping-pong"
                 | per-element-flag
                 | "motion-per-paragraph"
                 | "motion-per-children"

per-element-flag ::= ( "motion-per-letter" | "motion-per-word" | "motion-per-line" )
                     ( "-loop" | "-ping-pong" | "-reverse" | "-reverse-loop" )?

bind-directive ::= "motion-bind-" bind-source "/" bracket-range
                 | "motion-bind-ease-" easing-or-bracket
                 | "motion-bind-" bracket-clamp
                 | "motion-bind-reverse"

bind-source    ::= "scrollx" | "scrolly" | "dragx" | "dragy" | "value" | "time"

map-directive  ::= "motion-map-" bracket-map

audio-source   ::= "sfx:source-" bracket-value
                 | "sfx:id-"     bracket-id

audio-flag     ::= "sfx:prime"

audio-trigger  ::= "sfx:play" ( "-" bracket-id )?
                 | "sound-" bracket-value     // shorthand

preset         ::= "motion-track-" identifier

// --- Bracketed payloads ---

bracket-value  ::= "[" bracket-chars "]"
bracket-id     ::= "[" identifier "]"

bracket-range  ::= "[" WS? number WS? "-" WS? number WS? "]"
bracket-clamp  ::= "[" ( "clamp" | "freeze-start" | "freeze-end" | "unclamped" )? "]"
bracket-map    ::= "[" WS? number WS? ".." WS? number WS? "->"
                        WS? number WS? ".." WS? number WS? "]"

// --- Lexical ---

identifier     ::= lc-alpha ( lc-alpha | digit | "_" | "-" )*
number         ::= sign? ( digit+ ( "." digit* )? | "." digit+ )
integer        ::= sign? digit+
sign           ::= "+" | "-"
digit          ::= "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9"
lc-alpha       ::= "a" | "b" | ... | "z"

bracket-chars  ::= ( escaped | char-no-bracket )*
escaped        ::= "\" any-char
char-no-bracket::= any-char-except-] | "]" if escaped
any-char       ::= any Unicode scalar value
WS             ::= space | tab | newline
WS+            ::= WS WS*
supports-track ::= "supports-" bracket-value

selector-track ::= "." identifier | "#" identifier | bracket-value

pseudo-class-variant ::= "hover" | "focus" | "active" | "visited" | "disabled" | "enabled"
                       | "required" | "optional" | "invalid" | "valid" | "autofill"
                       | "placeholder-shown" | "read-only" | "read-write" | "target"
                       | "empty" | "focus-visible" | "focus-within" | "checked"
                       | "indeterminate" | "in-range" | "out-of-range" | "default"
                       | "first" | "last" | "first-of-type" | "last-of-type"
                       | "only" | "only-child" | "only-of-type" | "odd" | "even" | "open"

pseudo-element-variant ::= "before" | "after" | "first-letter" | "first-line"
                         | "selection" | "marker" | "placeholder" | "file" | "backdrop"

group-variant ::= "group-" ( identifier | bracket-value | pseudo-class-variant | pseudo-element-variant )

peer-variant  ::= "peer-" ( identifier | bracket-value | pseudo-class-variant | pseudo-element-variant )

aria-variant  ::= "aria-" identifier ( "-" identifier )?

data-variant  ::= "data-" identifier ( "-" identifier )?

lang-variant  ::= "lang-" bracket-value

has-variant   ::= "has-" bracket-value

theme-variant ::= "theme-" identifier
```

---

## 6) Semantic-Light Validation Rules (still **syntax-level** constraints)

These are minimal rules code generators MAY enforce during parse; they do not prescribe behavior.

1. **Timeline basis consistency:** every `motion-[...]` block MUST use either all percent times **or** all durations.
2. **Step form:** each step MUST contain exactly one time, a colon, and ≥1 utility token.
3. **Easing function text** inside `[...]` MUST be fully contained (balanced parentheses) and may include commas and spaces.
4. **Bracket payloads** MUST close; `\]` is the only way to include a literal `]`.
5. **Variant collisions:** multiple variants are allowed; order is preserved as written (left-to-right).
6. **Track labeling:** the **nearest** track prefix to a directive labels that directive. Outer track prefixes are inert for that directive.
7. **Alias `sound-[...]`:** purely syntactic; parsers MAY normalize it to `sfx:source-[...] <same-prefixes>:sfx:play`.

---

## 7) Canonicalization (optional, for generators)

Parsers MAY normalize input to a canonical form:

* Trim extra spaces around commas/colons inside `motion-[...]`.
* Convert `translate-x--1` to `-translate-x-1`.
* Collapse duplicate flags on the same directive (`motion-loop motion-loop` → single).
* Normalize duration literals (`.2s` → `0.2s`).
* Preserve user-written order of **steps** and **prefixes**.

---

## 8) Examples (normative data points)

**A. Basic fade**

```
motion-[0:opacity-0,100:opacity-100]
```

**B. Track + timing + loop**

```
glow:motion-[0:shadow-sm,50:shadow-xl,100:shadow-sm]
glow:motion-duration-800ms glow:motion-ease-ease-in-out glow:motion-loop
```

**C. Interaction + track + timeline**

```
hover:glitch:motion-[0:opacity-100 -translate-x-1,10:opacity-0 translate-x-1,20:opacity-100 translate-x-0]
```

**D. Per-letter + stagger**

```
title:motion-per-letter title:motion-letter-delay-60ms
title:motion-[0:opacity-0 translate-y-[8px],100:opacity-100 translate-y-0]
```

**E. Input binding + map**

```
motion-bind-scrolly/[100-500] motion-bind-ease-[cubic-bezier(0.4,0,0.2,1)] motion-bind-[clamp]
motion-map-[0..100->10..90]
```

**F. Audio with trigger + automation**

```
sfx:id-[zap] sfx:source-[/snd/zap.wav] sfx:prime
hover:sfx:play-[zap]
sfx:motion-[0:volume-[0],10:volume-[1] pan-[-0.3],100:volume-[0]]
```

**G. Shorthand sound alias**

```
active:sound-[tap.mp3]
```

**H. State-driven exit animation**

```
data-state-closed:motion-[0:opacity-100,100:opacity-0] data-state-closed:motion-duration-200ms
```

**I. Preset + inline override**

```
motion-track-glow glow:motion-duration-1200ms
```

**J. 3D transform (Y-axis card flip)**

```
motion-[0:rotate-y-0,50:rotate-y-[180deg],100:rotate-y-[360deg]]
motion-duration-3000ms motion-loop motion-ease-ease-in-out
```

**K. Filter animation (hue rotation cycle)**

```
motion-[0:hue-rotate-0,100:hue-rotate-[360deg]]
motion-duration-3000ms motion-loop motion-ease-linear
```

**L. Per-word compound variant (reverse loop)**

```
motion-[0:translate-x-0,50:translate-x-[5px],100:translate-x-0]
motion-duration-400ms motion-stagger-120ms motion-per-word-reverse-loop motion-ease-ease-in-out
```

**M. Scroll-driven animation with range**

```
scroll-timeline-[--hero y]
lead:motion-[0:opacity-0,100:opacity-100] lead:motion-timeline-[--hero] lead:motion-range-[entry 10% exit 90%]
```

---

## 9) Reserved Words

`motion`, `sfx`, `sound`, `motion-track`, `motion-duration`, `motion-rate`, `motion-ease`, `motion-delay`, `motion-track-delay`, `motion-letter-delay`, `motion-stagger`, `motion-fill`, `motion-loop`, `motion-once`, `motion-ping-pong`, `motion-per-letter`, `motion-per-letter-loop`, `motion-per-letter-ping-pong`, `motion-per-letter-reverse`, `motion-per-letter-reverse-loop`, `motion-per-word`, `motion-per-word-loop`, `motion-per-word-ping-pong`, `motion-per-word-reverse`, `motion-per-word-reverse-loop`, `motion-per-line`, `motion-per-line-loop`, `motion-per-line-ping-pong`, `motion-per-line-reverse`, `motion-per-line-reverse-loop`, `motion-per-paragraph`, `motion-per-children`, `motion-priority`, `motion-timeline`, `motion-composition`, `motion-play-state`, `motion-range`, `motion-range-start`, `motion-range-end`, `scroll-timeline`, `motion-bind`, `motion-bind-ease`, `motion-bind-reverse`, `motion-map`, `volume`, `pitch`, `pan`, `reverb`, `filter` and all **variant** names in §4.

---

## 10) Forward-Compatibility Notes

* New **variants** and **bind sources** may be added; unrecognized prefixes not in §4 are treated as **track** labels by this grammar.
* New **audio params** MAY appear as `name-[value]` utilities inside `motion-[...]` without changing the grammar.

---

### Parsing Checklist

1. Split by whitespace → `class-token`s.
2. For each token: parse `prefix ":"` chain (variants/tracks) → `core-directive`.
3. If `motion-[...]`: parse steps; enforce single timing basis; split utilities by spaces.
4. If timing/flags: record parameter or boolean.
5. If binding/map/ease: record payloads.
6. If audio: record sources, optional id, triggers, and step-level params.
7. If shorthand `sound-[...]`: expand to `sfx:source` + `<same-prefixes>:sfx:play`.
8. Preserve written order (prefixes and steps).
