# Crosswind Tailwind Spec

Below is a clean, exhaustive list of Tailwind CSS v4.x utility families, organized according to the official documentation structure. For each family, the canonical class pattern(s) are shown, including axis/directional shorthands, plus brief notes where v4 renamed or expanded functionality.

* The categories and families are based on Tailwind's v4 "Styling with utility classes" index, which enumerates every utility family by CSS property.
* Items documented under other pages (e.g. rings under box-shadow, gradient stops under background-image) have been incorporated.
* Where v4 removed or renamed families relative to v3, notes reference the v4 upgrade guide.

> **Notation & patterns**
>
> * `{value}` denotes Tailwind's normal value scale plus arbitrary values via brackets: e.g. `w-[3.75rem]`, `bg-[paint(worklet)]`.
> * `{n}` represents any (non‑negative) integer; v4 supports "any number" for many numeric families like `grid-cols-{n}`.
> * Axes/edges: `x|y|t|r|b|l`, logical block/inline variants where applicable (e.g. scroll snap).
> * Colors accept the normal palette or arbitrary values; transparency uses the `/alpha` suffix (e.g. `bg-red-500/20`). Families like `bg-opacity-*`, `text-opacity-*`, etc. were removed in v4.

---

## 1) Layout

* **Container**: `container` (responsive width constraints + centered)
* **Breaks**: `break-after-{auto|avoid|all|...}`, `break-before-{...}`, `break-inside-{auto|avoid|avoid-page|avoid-column}`
* **Box decoration**: `box-decoration-{clone|slice}`
* **Box sizing**: `box-{border|content}`
* **Display**: `block`, `inline`, `inline-block`, `contents`, `flow-root`, `table`, `inline-table`, `table-caption`, `table-cell`, `table-column`, `table-column-group`, `table-footer-group`, `table-header-group`, `table-row-group`, `table-row`, `list-item`, `hidden`, `flex`, `inline-flex`, `grid`, `inline-grid`
* **Float / Clear**: `float-{left|right|none}`, `clear-{left|right|both|none}`
* **Isolation**: `isolate`, `isolation-auto`
* **Object fit**: `object-{contain|cover|fill|none|scale-down}`
* **Object position**: `object-{bottom|center|left|left-bottom|left-top|right|right-bottom|right-top|top}` or `object-[<position>]`
* **Overflow**: `overflow-{auto|hidden|clip|visible|scroll}`, `overflow-x-*`, `overflow-y-*`
* **Overscroll behavior**: `overscroll-{auto|contain|none}`, `overscroll-x-*`, `overscroll-y-*`
* **Position**: `static`, `fixed`, `absolute`, `relative`, `sticky`
* **Offsets** (inset/edges): `inset-{value}`, `inset-x-{value}`, `inset-y-{value}`, `top-{value}`, `right-{value}`, `bottom-{value}`, `left-{value}`, `start-{value}`, `end-{value}` (supports tokens & arbitrary)
* **Z-index**: `z-{value}` (supports auto, negative values)
* **Visibility**: `visible`, `invisible`, `collapse`
* **Columns**: `columns-{value}`
* **Aspect ratio**: `aspect-{auto|square|video|[ratio]}`

## 2) Flexbox & Grid

* **Flex basis**: `basis-{value}`
* **Flex direction**: `flex-{row|row-reverse|col|col-reverse}`
* **Flex wrap**: `flex-{wrap|wrap-reverse|nowrap}`
* **Order**: `order-{first|last|none|{n}}`
* **Flex shorthand**: `flex-1`, `flex-auto`, `flex-initial`, `flex-none`
* **Grow/Shrink**: `grow`, `grow-0`, `shrink`, `shrink-0`
* **Align content/items/self**:

  * `content-{normal|center|start|end|between|around|evenly|baseline|stretch}`
  * `items-{start|end|center|baseline|stretch}`
  * `self-{auto|start|end|center|stretch|baseline}`
* **Place content/items/self**: `place-content-{...}`, `place-items-{...}`, `place-self-{...}`
* **Justify content/items/self**: `justify-{start|end|center|between|around|evenly}`, `justify-items-{start|end|center|stretch}`, `justify-self-{auto|start|end|center|stretch}`
* **Gap**: `gap-{value}`, `gap-x-{value}`, `gap-y-{value}`
* **Grid templates**: `grid-cols-{n}`, `grid-rows-{n}`
* **Grid lines**: `col-{auto|span-{n}|start-{n}|end-{n}}`, `row-{auto|span-{n}|start-{n}|end-{n}}`
* **Grid auto**: `grid-flow-{row|col|dense|row-dense|col-dense}`, `auto-cols-{min|max|fr|auto|[...]}`, `auto-rows-{min|max|fr|auto|[...]}`

## 3) Spacing

* **Padding**: `p-{value}`, `px-*`, `py-*`, `pt|pr|pb|pl-*`, `ps|pe-*` (logical inline-start/end)
* **Margin**: `m-{value}`, `mx-*`, `my-*`, `mt|mr|mb|ml-*`, `ms|me-*` (logical inline-start/end; supports negative values, e.g. `-mt-2`, `-m-[3px]`)
* **Space between** (siblings): `space-x-{value}`, `space-y-{value}` (+ `space-x-reverse`, `space-y-reverse`).

## 4) Sizing

* **Width**: `w-{value}` (includes `w-{fraction}`, `w-{screen|min|max|fit}`, arbitrary)
* **Min/Max width**: `min-w-{value}`, `max-w-{value}`
* **Height**: `h-{value}` (includes `h-{screen|min|max|fit}`, arbitrary)
* **Min/Max height**: `min-h-{value}`, `max-h-{value}`
* **Square size (both axes)**: `size-{value}`

## 5) Typography

* **Font family**: `font-{sans|serif|mono}` or `font-[...]`
* **Font size**: `text-{xs|sm|base|lg|xl|2xl|...|9xl}` or `text-[...]`
* **Font smoothing**: `antialiased`, `subpixel-antialiased`
* **Font style/stretch/variant**: `italic`, `not-italic`; `font-stretch-{ultra-condensed...ultra-expanded}`; `normal-nums`, `slashed-zero`, `lining-nums`, etc.
* **Font palette (COLRv1)**: `font-palette-{normal|light|dark|match-parent}` or `font-palette-[--custom]`; define palettes with `font-palette-values-[--id font=<family> base=<n> 0=<color> ...]`.
* **Font weight**: `font-{thin|extralight|light|normal|medium|semibold|bold|extrabold|black}`
* **Leading (line-height)**: `leading-{none|tight|snug|normal|relaxed|loose|[number]|[length]}`
* **Lists**: `list-{inside|outside}`, `list-{disc|decimal|...}`, `list-image-[url(...)]`
* **Text align**: `text-{left|center|right|justify|start|end}`
* **Text decoration**:

  * Line: `underline`, `overline`, `line-through`, `no-underline` (`decoration-none` also acceptable)
  * Color: `decoration-{color}`
  * Style: `decoration-{solid|double|dotted|dashed|wavy}`
  * Thickness: `decoration-{from-font|[length]}`
  * Underline offset: `underline-offset-{auto|[length]}`
* **Text indent/overflow/transform/wrap**: `indent-{value}`, `text-{ellipsis|clip}`, `truncate`, `uppercase|lowercase|capitalize|normal-case`, `text-wrap-{wrap|nowrap|balance|pretty}`
* **Line clamp**: `line-clamp-{n}` (multi-line text truncation)
* **Content**: `content-[value]` (sets CSS `content` property, for `before`/`after` pseudo-elements)
* **Vertical align**: `align-{baseline|top|middle|bottom|text-top|text-bottom|sub|super}`
* **Whitespace / word-break / hyphens**: `whitespace-{normal|nowrap|pre|pre-line|pre-wrap|break-spaces}`, `break-{normal|words|all|keep}`, `hyphens-{none|manual|auto}`
* **Text color**: `text-{color}`

## 6) Backgrounds

* **Attachment/clip/origin/position/repeat/size**:
  `bg-{fixed|local|scroll}`, `bg-clip-{border|padding|content|text}`, `bg-origin-{border|padding|content}`,
  `bg-{bottom|center|left|left-bottom|left-top|right|right-bottom|right-top|top}` or `bg-[position]`,
  `bg-{repeat|no-repeat|repeat-x|repeat-y|repeat-round|repeat-space}`,
  `bg-{auto|cover|contain|[length]|[percentage]}`
* **Images (including gradients)**:

  * **Directional gradients**: `bg-linear-to-{t|tr|r|br|b|bl|l|tl}` (aliases `bg-gradient-to-*` remain documented/used)
  * **Angles**: `bg-linear-{angle}` (e.g. `bg-linear-45`)
  * **Color stops**: `from-{color}`, `via-{color}`, `to-{color}` (+ `via-none`).
  * **Custom images**: `bg-[url('...')]`, etc.
* **Background color**: `bg-{color}`

## 7) Borders (incl. Outline)

* **Border width**: `border-{value}`, `border-x|y|t|r|b|l|s|e-{value}` (+ `divide-x|y-{value}` for sibling dividers; supports reverse modifiers).
* **Border color/style**: `border-{color}`, `border-{solid|dashed|dotted|double|hidden|none}`
* **Border radius**: `rounded`, `rounded-{none|sm|md|lg|xl|2xl|3xl|full}`, edge/corner variants `rounded-{t|r|b|l|s|e}-{...}`, `rounded-{tl|tr|br|bl|ss|se|es|ee}-{...}`
* **Outline**: `outline-*` family (`outline-{[length]|[style]|none|hidden}`, `outline-{color}`, `outline-offset-{length}`) — v4 has dedicated width/color/style/offset utilities.

## 8) Effects (shadows, rings, blend, opacity)

* **Box shadow**: `shadow`, `shadow-{2xs|xs|sm|md|lg|xl|2xl}`, `shadow-none`, `shadow-inner`, `shadow-{color}`
* **Rings** (implemented via shadow):
  `ring-{n}` (width), `ring-{color}`, `ring-inset`, plus inset rings `inset-ring-{n}`, `inset-ring-{color}`, and ring offset: `ring-offset-{n}`, `ring-offset-{color}`.
* **Mix / background blend**: `mix-blend-{mode}`, `bg-blend-{mode}`
* **Opacity** (element): `opacity-{0..100}`
* **Text shadow**: `text-shadow`, `text-shadow-{xs|sm|md|lg|xl|2xl}`, `text-shadow-none` (added in v4.1).

## 9) Filters & Backdrop filters

* **Filter primitives** (auto-emitting `filter`):
  `blur-{xs|sm|md|lg|xl|2xl|3xl|[length]}`, `brightness-{value}`, `contrast-{value}`, `drop-shadow`, `drop-shadow-{sm|md|lg|xl|2xl}`, `grayscale`, `hue-rotate-{deg}`, `invert`, `saturate-{value}`, `sepia`
* **Optional filter toggle**: `filter`, `filter-none`
* **Backdrop primitives**:
  `backdrop-blur-{...}`, `backdrop-brightness-{...}`, `backdrop-contrast-{...}`, `backdrop-grayscale`, `backdrop-hue-rotate-{deg}`, `backdrop-invert`, `backdrop-opacity-{...}`, `backdrop-saturate-{...}`, `backdrop-sepia`
* **Backdrop filter toggle**: `backdrop-filter`, `backdrop-filter-none`

## 10) Tables

* **Border collapse**: `border-{collapse|separate}`
* **Border spacing**: `border-spacing-{value}`, `border-spacing-x-{value}`, `border-spacing-y-{value}`
* **Table layout**: `table-{auto|fixed}`
* **Caption side**: `caption-{top|bottom}`

## 11) Transitions & Animation

* **Transition**: `transition` (all), `transition-none`, `transition-{property}`
* **Timing**: `duration-{ms}`, `ease-{linear|in|out|in-out|[cubic-bezier]}`, `delay-{ms}`
* **Behavior**: `transition-behavior-{normal|allow-discrete}` (added in v4.1)
* **Animation**: `animate-{spin|ping|pulse|bounce|none|[custom]}`

## 12) Transforms

* **Transform (composite/toggle)**: `transform`, `transform-none`
* **Individual transforms**:
  `scale-{n}`, `scale-x-{n}`, `scale-y-{n}`;
  `rotate-{deg}`, `rotate-x-{deg}`, `rotate-y-{deg}`;
  `translate-{value}`, `translate-x-{value}`, `translate-y-{value}`, `translate-z-{value}`, `-translate-{value}`, `-translate-x-{value}`, `-translate-y-{value}`;
  `skew-x-{deg}`, `skew-y-{deg}`;
  **Transform origin**: `origin-{center|top|top-right|...}`

## 13) Interactivity

* **Accent & caret**: `accent-{color}`, `caret-{color}`
* **Appearance**: `appearance-{none|auto}`
* **Color scheme**: `color-scheme-{light|dark|only-light|only-dark|normal}`
* **Field sizing**: `field-sizing-{content|fixed}`
* **Pointer & cursor**: `pointer-events-{none|auto}`, `cursor-{pointer|wait|text|move|help|not-allowed|...}`
* **Resize**: `resize`, `resize-{x|y|none}`
* **Scroll**: `scroll-{auto|smooth}`, `scroll-m-{value}`, `scroll-m{t|r|b|l|x|y|s|e}-{value}`, `scroll-p-{value}`, `scroll-p{t|r|b|l|x|y|s|e}-{value}`
* **Scroll snap**: `snap-{none|x|y|both}`, `snap-{mandatory|proximity}`, `snap-align-{start|center|end|none}`, `snap-stop-{normal|always}`
* **Touch action**: `touch-{auto|none|pan-x|pan-y|pinch-zoom|manipulation}`
* **User select**: `select-{none|text|all|auto}`
* **Will change**: `will-change-{auto|scroll|contents|transform|[custom]}`

## 14) SVG

* **Fill**: `fill-{color}` (+ `/alpha`)
* **Stroke**: `stroke-{color}`, `stroke-{n}`
* **Stroke styling**: `stroke-{round|square|butt}`, `stroke-join-{miter|round|bevel}`, `stroke-dasharray-[...]`, `stroke-dashoffset-[...]`

## 15) Accessibility

* **Screen reader only**: `sr-only`, `not-sr-only`
* **Forced colors**: `forced-color-adjust-{auto|none}`

> **Sibling borders & rings live under other pages, but are part of core in v4:**
>
> * **Divide (sibling borders)**: `divide-x-{value}`, `divide-y-{value}` (+ `divide-{color}`, `divide-{style}`, `divide-*-reverse`) — documented under Border width.
> * **Ring utilities** are documented under Box shadow: `ring-*`, `inset-ring-*`, `ring-offset-*`.

## 16) Masks

* **Mask image**: `mask-image-{none}` or `mask-image-[url('...')]`, `mask-image-[linear-gradient(...)]` — sets `mask-image`
* **Mask size**: `mask-size-{auto|cover|contain|[length]}` — sets `mask-size`
* **Mask repeat**: `mask-repeat-{repeat|no-repeat|repeat-x|repeat-y|round|space}`, `mask-no-repeat`, `mask-repeat-x`, `mask-repeat-y`, `mask-repeat-round`, `mask-repeat-space`
* **Mask position**: `mask-position-{center|top|bottom|left|right|[position]}` — sets `mask-position`
* **Mask origin**: `mask-origin-{border|padding|content}` — maps to `border-box`, `padding-box`, `content-box`
* **Mask clip**: `mask-clip-{border|padding|content|text}` — maps to box values or `text`
* **Mask composite**: `mask-composite-{add|subtract|intersect|exclude}` — sets `mask-composite`

> All mask utilities automatically emit both standard `mask-*` and vendor-prefixed `-webkit-mask-*` declarations for cross-browser compatibility.

