# LLM Shader System

This documentation describes the structure and configuration of an LLM Shader: a declarative, fully-scriptable prompt that can call functions, loop, post-process its own output, and much more.

Everything is scriptable: any scalar field shown below can be a literal or a template expression. Strings are evaluated with the current template engine; numeric/bool fields are evaluated and converted to their target types.

---

## Example LLM Shader

The example below showcases every top-level field and most advanced features.  
Comments (`//`) explain the purpose of each property.

```json5
{
  // ───────────────────────── shader meta ──────────────────────────
  ShaderVersion: 2,               // 1 = legacy, 2 = preferred (both use Scriban)

  // ───────────────────────── default model ────────────────────────
  Model: {
    Name: "Gpt41",                // leave empty to run only actions / outputs
    Regions: [],                   // preferred model regions in priority order (e.g. "Eu", "UsWest")
    RequestTimeoutSeconds: 60,
    Temperature: 0.7,
    MaxOutputTokens: 4000,        // text tokens returned
    ReasoningEffort: "None",      // None/Minimal/Low/Medium/High
    ReasoningTokenBudget: 0,      // budget for internal “scratch-pad”
    UseStreaming: true,           // stream partial results
    UseJson: false,               // force JSON response
    UseCitations: false,          // enable citation pipeline
    ForceCitations: false,        // always assume citations are needed
    UseUserNames: false,          // include user names in messages
    UseAudioOutput: false,        // enable audio output on supported LLMs
    AudioOutputVoiceId: "",       // voice id when UseAudioOutput = true
    UseCaching: false,            // enable request caching
    DisableFunctionCalling: false,// hard-disable function calls
    DiscardTextOutputWithFunctionCalls: true, // discard text if tool used
    MaxRecursionDepth: 3,         // safety limit for self-recursion
    LogFullRequest: false,        // dump raw JSON request
    LogRenderedShader: false,     // dump pretty rendered shader
    UseThrottling: false,         // simulate typing for streamed output
    CharsPerSecond: 100,          // when throttling
    CharsPerUpdate: 5,            // when throttling

    // Optional transforms executed before / after the LLM
    Transforms: [
      {
        Name: "Example",          // e.g. "safety" for the built-in moderation filter
        ProcessInput: true,
        ProcessOutput: true,
        WindowSize: 1000,         // characters processed at a time
        WindowOverlap: 200,
        Config: {}                // custom settings for the transform
      }
    ],

    // Exactly ONE of the three may be set (XOR):
    JsonSchema: {},               // schema as object
    JsonSchemaString: "",         // schema as string
    //           ↳ OR let GenerateObjectAsync<T>() inject an implicit schema

    // Optional grammar for constrained generation
    GbnfGrammar: "Example GBNF grammar" // can be combined with any of the above
  },

  // ───────────────────────── history handling ─────────────────────
  History: {
    Max: 10,   // keep last N messages
    Skip: 0    // skip most-recent N messages
  },

  // ───────────────────────── global inputs ────────────────────────
  Input: {
    KernelContext: null,              // populated by the runtime
    DateTimeUtc: "",                  // populated by the runtime
    UserName: "",                     // populated by the runtime
    UserLocale: "",                   // populated by the runtime
    HasMessageHistory: false,         // populated by the runtime
    IsFirstMessageSinceJoin: false,   // populated by the runtime
    IsLongTimeSinceLastMessage: false,// populated by the runtime
    HasResults: false,                // populated by the runtime
    Input: null,                      // used by Listeners / Process scripts
    ShaderResult: "",                 // final text collected so far
    ExampleVariable: "You are a helpful assistant." // custom variable
  },

  // ───────────────────────── misc settings ────────────────────────
  Misc: {
    FailureMessage: "Unfortunately, I could not come up with an answer.",
    CitationInsertionCommand: "",     // extra instruction when citations used
    CitationUserMessageExtension: "", // text appended to last user msg
    InsertCitationsBackToModelMessage: true, // re-insert [1] refs into message
    UseTrimming: true,                // strip duplicate blank lines & spaces
    FailClassificationLabels: [       // flagged labels → throw error
      "Unknown",
      "SafetyHateSpeech",
      "SafetyHarassment",
      "SafetySelfHarm",
      "SafetySexualContent",
      "SafetyChildAbuse",
      "SafetyViolence",
      "SafetyJailbreak",
      "SafetyCopyright",
      "SafetyDangerousContent",
      "SafetyHealth",
      "SafetyFinancial",
      "SafetyLegal",
      "SafetyPII"
    ]
  },

  // ───────────────────────── intents & passes ─────────────────────
  Intents: [
    {
      Id: "ExampleIntent",
      Select: true, // first intent with Select == true is chosen

      // Optional overrides for this intent
      // Model: { ... }, History: { ... }, Input: { ... }, Misc: { ... },

      Passes: [
        {
          Id: "ExamplePass",
          Select: "{{ !HasMessageHistory }}",

          // Optional overrides for this pass
          // Model: { ... }, History: { ... }, Input: { ... }, Misc: { ... },

          // Prompts
          Context: "{{ ExampleVariable }}",
          Command: "Please answer the user question",

          // ───── template-time helper functions ─────
          TemplateFunctions: {
            template_function1: {
              Select: true,
              Name: "other_function1" // optional rename
            }
          },

          // ───── callable model-time functions (tools) ─────
          ModelFunctions: {
            model_function1: {
              Select: true,
              Use: "other_function2",      // call another registered fn
              Description: "A description of the function",
              InlineCall: false,           // no 2nd pass when true
              CallOnlyOnce: false,         // disable after first call
              Process: "{{ Input | content }}", // post-process result
              Call: "",                    // inline script to execute instead
              Parameters: {
                param1: {
                  Use: "other_param2",
                  Description: "A description of the parameter",
                  Type: "int",             // string/int/float/bool/object or array variants: string[]/int[]/float[]/bool[]/object[]
                  HasDefaultValue: true,
                  DefaultValue: 123
                }
              }
            }
          },

          // ───── imperative hooks (template) ─────
          Actions: {
            Listeners: {
              // executed when a streaming result of given type is produced
              // common keys: "FunctionCall", "Citation", "OutputAudioTranscript", "OutputAudioId", "Reasoning", "String"
              SomeTypeName: "{{ other_function1(Input) }}"
            },
            BeforeShader: "{{ other_function1(123) }}",
            AfterShader: "",
            BeforePass: "",
            AfterPass: ""
          },

          // ───── declarative text output hooks ─────
          Output: {
            BeforeShader: "Some text output as-is",
            AfterShader: "",
            BeforePass: "",
            AfterPass: ""
          }
        }
      ]
    }
  ],

  // ───────────────────────── logging limits ───────────────────────
  MaxLogLineLength: 80,        // truncate individual log lines
  MaxLogSectionLineCount: 5000 // truncate large sections
}
```

---

## LLM Shader Components

### ShaderVersion
1 → legacy (originally used Liquid, now uses Scriban), 2 → Scriban templates (recommended).
The engine is chosen automatically from `ShaderVersion`.

### Input

Declare every variable that should be visible inside `{{ }}` templates.  
Runtime automatically sets / updates the following:

- KernelContext: The current Ikon AI kernel context
- DateTimeUtc: Current UTC timestamp
- UserName, UserLocale: User info
- HasMessageHistory, IsFirstMessageSinceJoin, IsLongTimeSinceLastMessage: Conversation flags
- HasResults: true if any function result is present in the context
- <function>_HasResults: Per-function flag (true if that function has results)
- Messages: Array of visible messages – each { Role, Content } built from text parts only
- ImplicitJsonExample: Auto-generated example when using GenerateObjectAsync<T>()
- Input: Set by Listeners and Process scripts (current StreamingResult value)
- ShaderResult: Accumulated text output of the current run

You can freely add your own custom variables (like ExampleVariable above).

### Model

Controls how the LLM is invoked:

- Name: LLM model id (see list below). Empty → no model call (only actions/outputs).
- Regions: Preferred model regions in priority order (e.g. Eu, UsWest). Values from the ModelRegion enum: Global, Eu, EuNorth, EuWest, EuCentral, EuSouth, Us, UsEast, UsWest.
- RequestTimeoutSeconds: Hard timeout for the request.
- Temperature, MaxOutputTokens: Standard sampling limits.
- ReasoningEffort: Hint for the model on how much internal reasoning to allocate (None/Low/Medium/High).
- ReasoningTokenBudget: Upper limit for the model’s hidden scratch-pad (0 → let the model decide).
- UseStreaming: Stream partial results (StreamingResult).
- UseJson: Ask the model to reply in pure JSON.
- UseCitations / ForceCitations: Enable the citation pipeline / force it to assume citations are required.
- UseUserNames: Include user/assistant names in the message history (for LLMs that support it).
- UseAudioOutput / AudioOutputVoiceId: Enable text-to-speech generation; transcript is surfaced if the model returns only audio.
- UseCaching: Deduplicate identical requests.
- DisableFunctionCalling: Force no tools even if functions are provided.
- DiscardTextOutputWithFunctionCalls: Ignore LLM text if it also called a function.
- MaxRecursionDepth: Stop after N self-triggered reruns.
- LogFullRequest: Dump the raw JSON sent to the LLM.
- LogRenderedShader: Dump the fully rendered shader (pretty printed).
- UseThrottling, CharsPerSecond, CharsPerUpdate: Typewriter effect for output.

#### Structured-output helpers

Exactly one of the following can be set (XOR check enforced):

- JsonSchema (object form)
- JsonSchemaString (string form)
- Implicit schema – automatically injected when using Shader.GenerateObjectAsync<T>()

GbnfGrammar can be used alongside or instead of a JSON schema.

ImplicitJsonExample (see Input) holds a valid example that matches the generated schema.

#### Transforms

Bidirectional post-processing steps (executed in order of appearance). Input transforms run on the concatenated text of the most recent user message before the LLM call; output transforms wrap the streamed LLM response. Both use the configured sliding window.

- Name: Transform id – "safety" is the built-in moderation filter.
- ProcessInput / ProcessOutput: Enable for incoming / outgoing text.
- WindowSize / WindowOverlap: Sliding-window size & overlap in characters.
- Config: Arbitrary custom values consumed by the transform.
- The built-in safety transform calls the OpenAI moderation model. Flagged windows emit a `ClassificationResult` streaming event tagged `LLMShader.Model.Transform.Safety` and can short-circuit generation.

### History

Max messages are kept; the last Skip messages are ignored prior to inclusion.

### Misc

Runtime behaviour not specific to the model.

- FailureMessage: Fallback text if generation fails.
- CitationInsertionCommand: Extra system instruction when citations are on.
- CitationUserMessageExtension: Extra text appended to the last user message.
- InsertCitationsBackToModelMessage: Re-insert [id] markers into the final model message.
- UseTrimming: Remove unnecessary whitespace & duplicate blank lines in Context/Command.
- FailClassificationLabels: Any flagged label triggers a ClassificationResultException.

### MaxLogLineLength & MaxLogSectionLineCount

Hard caps for the pretty-printed shader log.

---

## Intents and Passes

Selection algorithm (per run):

1. First Intent whose Select evaluates to true.  
2. Inside it, first Pass whose Select is true.

If nothing is selected an error is thrown.  
Input, Model, History, and Misc can be overridden at Intent or Pass level (cascade).

### Intents

- Id: Human-readable id (useful for logs).
- Select: Template expression returning true/false.
- Input / Model / History / Misc: Optional overrides.
- Passes: Array of Pass definitions.

### Passes

Additional to the fields above:

- Context: Prompt before messages.
- Command: Prompt after messages (highest priority).
- TemplateFunctions: Register/rename template-only helpers.
- ModelFunctions: Define callable tools (see below).
- Actions: Imperative hooks.
- Output: Declarative text emitted at given stages.

#### TemplateFunctions

Enable or rename existing kernel functions for template use.

```json5
"template_function_key": {
  Select: true,
  Name: "optional_new_name"
}
```

Referencing a function name that does not exist in any registered kernel context throws during shader processing.

#### ModelFunctions (Tools)

Expose functions callable by the LLM. Besides standard parameters you can supply inline scripting (Call) to implement the function directly in the shader, or Process scripts to post-process the real function result.

```json5
"visible_name": {
  Select: true,
  Use: "registered_function_name", // optional
  Description: "...shown to the LLM...",
  InlineCall: false,               // no 2nd pass when true
  CallOnlyOnce: false,             // disable after first call
  Process: "{{ Input | content }}",// post-process function result
  Call: "{{ custom_scripting }}",  // run instead of real function
  Parameters: {
    "paramName": {
      Use: "actualParameter",
      Description: "Explain to the model",
      Type: "string",              // string/int/float/bool/object or array variants: string[]/int[]/float[]/bool[]/object[]
      HasDefaultValue: true,
      DefaultValue: "abc"
    }
  }
}
```

Notes:
- Call creates an ad hoc function implemented by your template; it receives parameters via the Input variable.
- CallOnlyOnce disables the function if it was already used earlier in the conversation.
- Process is run on function results before they are re-injected to the conversation for the next iteration.
- When Call is used the Input variable contains a dictionary of argument values keyed by the parameter names defined in Parameters.
- Process receives the function output via Input (single value or array when multiple streaming payloads are produced).
- Referencing a function that cannot be found in the source kernel contexts results in a runtime error.

#### Actions

Executed in template context – perfect for side effects.

- BeforeShader / AfterShader: Run once before/after the whole shader (AfterShader runs after the model message is assembled).
- BeforePass / AfterPass: Run before/after the selected Pass (every iteration).
- Listeners: Dictionary "<StreamingResultType> → script". Runs whenever that result type is produced – Input contains the value. Common types include `String`, `FunctionCall`, `Citation`, `OutputAudioTranscript`, `OutputAudioId`, `Reasoning`, `ToolPlan`, `ClassificationResult`, `FinalTextResponse`, and `FinalModelMessage`.

#### Output

Static text injected into the StreamingResult stream.
Allows pre-/post-ambles or fully scripted answers when Model.Name is empty.
Every emission updates `ShaderResult`, letting subsequent scripts inspect the accumulated text.

#### Invocation context & final outputs

- `ShaderInvocationContext.FailureMessage` is set to the resolved failure message of the selected pass (after templating).
- `ShaderInvocationContext.Reasoning` captures streamed reasoning traces (e.g., OpenAI O-series tool reasoning).
- After generation finishes the runtime emits `FinalTextResponse` and `FinalModelMessage` streaming results containing the sanitized text reply and the message added back to history.

---

## Built-in Default Functions & Filters

- escape: Escapes template delimiters in text.

Any function registered with the name prefix filter. becomes available as a template filter (e.g., {{ text | my_filter }}).  
Template-time functions can be exposed via TemplateFunctions; model-time tools via ModelFunctions.

---

## Available LLM Models

See the `LLMModel` enum in the auto-generated Ikon.AI Public API reference for the current list (`docs/Ikon.AI/public-api.md` in AI apps).
