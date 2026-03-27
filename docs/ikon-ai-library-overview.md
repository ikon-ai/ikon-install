# Ikon.AI Library Overview

This guide summarizes the principal namespaces in the Ikon.AI .NET library for developers building AI-enabled solutions. Each section outlines module responsibilities, supported models, and usage patterns verified by automated tests.

## Emergence

`Ikon.AI.Emergence` is the recommended way to build AI workflows with typed outputs. It provides a streaming-first, C#-idiomatic API for structured object generation, tool calling, and advanced multi-agent patterns. All APIs return `IAsyncEnumerable<EmergeEvent<T>>` and non-streaming usage is achieved via the `.FinalAsync()` extension method. Emergence can target any model listed in the [LLM](#llm) section. See the [Emergence Guide](emergence-guide.md) for the full documentation.

### Object Generation

```csharp
using Ikon.AI.Emergence;
using Ikon.AI.Kernel;
using Ikon.AI.LLM;
using Ikon.Common;

var context = new KernelContext();
context = context.Add(new MessageBlock(MessageBlockRole.User, "Tell me about John Smith."));

var (result, _) = await Emerge.Run<PersonDetails>(LLMModel.Gpt5Mini, context, pass =>
{
    pass.Command = "Return invented personal details about the person the user asked about.";
}).FinalAsync();

Log.Instance.Info($"Result: {Json.To(result)}");

public class PersonDetails
{
    public string Name { get; set; } = string.Empty;
    public int Age { get; set; }
    public string Occupation { get; set; } = string.Empty;
}
```

Emergence supports 15 multi-agent patterns including `BestOf`, `ParallelBestOf`, `SolverCriticVerifier`, `DebateThenJudge`, `MapReduce`, `Refine`, `PlanAndExecute`, `Router`, `EnsembleMerge`, `TreeOfThought`, `SelfConsistency`, `Swarm`, `TaskGraph`, `TestRefine`, and `TreeSearch`. See the [Emergence Guide](emergence-guide.md) for full documentation on all patterns.

Region support is available via `pass.Regions`:

```csharp
pass.Regions = [ModelRegion.Eu, ModelRegion.Global];
```

## Shaders

> **Note:** For new development, prefer using [Emergence](#emergence) which provides a simpler, code-first API for structured AI outputs.

`Ikon.AI.Shader` provides declarative orchestration for prompt-driven automation. Shaders encapsulate model selection, context policies, and schema expectations while allowing reuse across applications. Shaders can target any model listed in the [LLM](#llm) section.

### Text Generation

Generate structured text using a shader definition stored in code, files, or embedded resources.

```csharp
using Ikon.AI.Kernel;
using Ikon.AI.Shader;
using Ikon.Common;

string shaderSource = @"
{
  ShaderVersion: 2,
  Model: {
    Name: 'Gpt5Mini',
    RequestTimeoutSeconds: 60,
    MaxOutputTokens: 4000,
    ReasoningEffort: 'Medium',
  },
  History: {
    Max: 10,
  },
  Input: {
    AssistantName: 'IkonBot',
  },
  Intents: [
    {
      Id: 'ExampleIntent',
      Passes: [
        {
          Id: 'ExamplePass',
          Context: 'You are a helpful assistant. Your name is {{ AssistantName }}.',
          Command: 'Please answer the user question.',
        }
      ]
    }
  ]
}";

var shader = new Shader.Shader(shaderSource);
var context = new KernelContext();
context = context.Add(new MessageBlock(MessageBlockRole.User, "Hello! What is your name?"));

var stringResult = await shader.GenerateStringAsync(context);
Log.Instance.Info($"Shader string result: {stringResult}");
```

### Object Generation

Emit strongly typed results when the shader is configured for JSON output.

```csharp
using Ikon.AI.Shader;
using Ikon.Common;
using Ikon.Common.Core;

string shaderSource = @"
{
  ShaderVersion: 2,
  Model: {
    Name: 'OpenAI_GPT5Mini',
    RequestTimeoutSeconds: 60,
    MaxOutputTokens: 4000,
    ReasoningEffort: 'Medium',
    LogRenderedShader: true,
    UseJson: true,
  },
  History: {
    Max: 10,
  },
  Input: {
    RequestedName: null,
  },
  Intents: [
    {
      Id: 'ExampleIntent',
      Passes: [
        {
          Id: 'ExamplePass',
          Command: 'Return a JSON object with invented personal details about {{ RequestedName }}. Please give the output in JSON format like this:\n{{ ImplicitJsonExample }}',
        }
      ]
    }
  ]
}";

var shader = new Shader.Shader(shaderSource);
var state = new Dictionary<string, object?>
{
    ["RequestedName"] = "John Smith"
};

var result = await shader.GenerateObjectAsync<ExampleResponse>(state: state);
Log.Instance.Info($"Shader object result: {Json.To(result)}");

private class ExampleResponse
{
    public string Name { get; set; } = string.Empty;
    public int Age { get; set; }
    public string Occupation { get; set; } = string.Empty;
}
```

### Implicit Shaders

Implicit shaders load their source from embedded resources that share the class name. Save the shader used in `ShaderObjectExampleTest` as `<ClassName>.shader` alongside the corresponding `<ClassName>.cs` file, set the build action to **Embedded Resource**, and access it through `ShaderCache`.

```csharp
var result = await ShaderCache.Instance.GetImplicitShader().GenerateObjectAsync<ExampleResponse>(
    contexts: null,
    cancellationToken: CancellationToken.None,
    ("RequestedName", "John Smith")
);

Log.Instance.Info($"Implicit shader object result: {Json.To(result)}");
```

## LLM

> **Note:** For most use cases, prefer using [Emergence](#emergence) which provides structured outputs and higher-level patterns on top of the LLM layer.

`Ikon.AI.LLM` offers direct, streaming-level access to language models when higher-level orchestration is unnecessary.

**Supported models:** See the model enum in the auto-generated Ikon.AI Public API reference for the current list (`docs/Ikon.AI/public-api.md` in AI apps).

Pass preferred regions as an ordered list to keep inference within a geography. If omitted, the default region is `Global`.

```csharp
using Ikon.AI;
using Ikon.AI.Kernel;
using Ikon.AI.LLM;

var context = new KernelContext();
context = context.Add(new Instruction(InstructionType.Context, "You are a helpful assistant that helps to summarize product release notes."));
context = context.Add(new MessageBlock(MessageBlockRole.User, "Summarise the latest release highlights. Here are the notes: ..."));

using var llm = new LLM.LLM(LLMModel.Gpt5Mini, regions: [ModelRegion.Eu]);

await foreach (var streamingResult in llm.GenerateAsync(context))
{
    Log.Instance.Info($"{streamingResult.SourceName} | {streamingResult.Value.GetType()} | {streamingResult.Value}");
}

var stringResult = await llm.GenerateAsync(context).AsStringAsync();
Log.Instance.Info($"String result: {stringResult}");
```

## ImageGeneration

`Ikon.AI.ImageGeneration.ImageGenerator` creates images with negative prompts, seeding, and resolution controls.

**Supported models:** See the model enum in the auto-generated Ikon.AI Public API reference for the current list (`docs/Ikon.AI/public-api.md` in AI apps).

```csharp
using Ikon.AI.ImageGeneration;

using var imageGenerator = new ImageGenerator(ImageGeneratorModel.Gemini25FlashImage);

var result = (await imageGenerator.GenerateImageAsync(new ImageGeneratorConfig
{
    Prompt = "A santa dancing in the snow",
    NegativePrompt = "summer",
    Width = 1024,
    Height = 1024,
    Seed = 42
})).First();

using MemoryStream ms = new MemoryStream(result.Data);
using SixLabors.ImageSharp.Image image = await SixLabors.ImageSharp.Image.LoadAsync(ms);
await image.SaveAsPngAsync("santa.png");
```

## VideoGeneration

`Ikon.AI.VideoGeneration.VideoGenerator` renders video clips with configurable length, resolution, and aspect ratio.

**Supported models:** See the model enum in the auto-generated Ikon.AI Public API reference for the current list (`docs/Ikon.AI/public-api.md` in AI apps).

```csharp
using Ikon.AI.VideoGeneration;

using var generator = new VideoGenerator(VideoGeneratorModel.Pollo20);

var result = await generator.GenerateVideoAsync(new VideoGeneratorConfig
{
    Prompt = "A santa dancing in the snow",
    Resolution = VideoGeneratorResolution.Resolution1080p,
    AspectRatio = VideoGeneratorAspectRatio.Ratio16x9,
    Length = 5
});

Log.Instance.Info($"Video URL: {result.Url}");
```

## VideoEnhancement

`Ikon.AI.VideoEnhancement.VideoEnhancer` upscales and frame-interpolates existing video clips.

**Supported models:** See the model enum in the auto-generated Ikon.AI Public API reference for the current list (`docs/Ikon.AI/public-api.md` in AI apps).

```csharp
using Ikon.AI.VideoEnhancement;

using var enhancer = new VideoEnhancer(VideoEnhancerModel.TensorPixUpscale4xUltra4);

var result = await enhancer.EnhanceVideoAsync(new VideoEnhancerConfig
{
    VideoUrl = "https://example.com/input.mp4"
});

Log.Instance.Info($"Enhanced video URL: {result.Url}");
```

## SpeechGeneration

`Ikon.AI.SpeechGeneration.SpeechGenerator` streams synthesized speech while exposing supported voice IDs per model.

**Supported models:** See the model enum in the auto-generated Ikon.AI Public API reference for the current list (`docs/Ikon.AI/public-api.md` in AI apps).

```csharp
using Ikon.AI.SpeechGeneration;
using Ikon.Resonance;

using var speechGenerator = new SpeechGenerator(SpeechGeneratorModel.Gpt4OmniMiniTts);

foreach (var voiceId in speechGenerator.VoiceIds)
{
    Log.Instance.Info($"Voice ID: {voiceId}");
}

List<float> samples = [];

var config = new SpeechGeneratorConfig
{
    VoiceId = "ballad",
    Language = "en-US",
    Instructions = "Speak like a angry pirate.",
    Text = "There once was a ship that put to sea. The name of that ship was a Billy of Tea."
};

await foreach (var audio in speechGenerator.GenerateSpeechAsync(config))
{
    samples.AddRange(audio.Samples);
}

using var wavFile = new WavFile(speechGenerator.SampleRate, speechGenerator.ChannelCount, WavFile.SampleFormat.Float);
wavFile.AddSamples(samples.ToArray());
wavFile.SaveToFile("speech.wav");
```

## SpeechRecognition

`Ikon.AI.SpeechRecognition.SpeechRecognizer` converts audio streams into text with configurable sample rates and languages.

**Supported models:** See the model enum in the auto-generated Ikon.AI Public API reference for the current list (`docs/Ikon.AI/public-api.md` in AI apps).

```csharp
using Ikon.AI.SpeechRecognition;
using Ikon.Resonance;

var speechRecognizer = new SpeechRecognizer(SpeechRecognizerModel.Whisper2);

var audioBytes = await File.ReadAllBytesAsync("audio.raw");

string text = await speechRecognizer.RecognizeBatchSpeechAsync(new RecognizeSpeechConfig
{
    Language = "en-US",
    SampleRate = 16000,
    ChannelCount = 1,
    Samples = AudioUtils.ConvertPcm16ToFloat(audioBytes)
});

Log.Instance.Info($"Recognized speech: '{text}'");
```

## SoundEffectGeneration

`Ikon.AI.SoundEffectGeneration.SoundEffectGenerator` generates sound effects from text prompts.

**Supported models:** See the model enum in the auto-generated Ikon.AI Public API reference for the current list (`docs/Ikon.AI/public-api.md` in AI apps).

```csharp
using Ikon.AI.SoundEffectGeneration;

using var generator = new SoundEffectGenerator(SoundEffectGeneratorModel.ElevenLabsV2);

var result = await generator.GenerateSoundEffectFileAsync(new SoundEffectGeneratorConfig
{
    Prompt = "A thunderstorm with heavy rain"
});

await File.WriteAllBytesAsync("thunder.wav", result.AudioData);
```

## WebScraping

`Ikon.AI.WebScraping.WebScraper` fetches and normalizes website content, with options for Markdown extraction and screenshots.

**Supported models:** See the model enum in the auto-generated Ikon.AI Public API reference for the current list (`docs/Ikon.AI/public-api.md` in AI apps).

```csharp
using Ikon.AI.WebScraping;

var scraper = new WebScraper(WebScraperModel.Jina, useLocalCache: true);

var page = await scraper.ScrapeSinglePageAsync(new SinglePageScrapeConfig
{
    Url = "https://example.com",
    OutputFormat = WebScraperOutputFormat.Markdown
});

Log.Instance.Info($"{page.Title}: {page.Content}...");

var screenshot = await scraper.TakeScreenshotAsync(new ScreenshotConfig
{
    Url = "https://example.com",
    Width = 800,
    Height = 600
});

await File.WriteAllBytesAsync("screenshot.png", screenshot.Data);
```

## WebSearching

`Ikon.AI.WebSearching.WebSearcher` wraps search providers for page and image discovery.

**Supported models:** See the model enum in the auto-generated Ikon.AI Public API reference for the current list (`docs/Ikon.AI/public-api.md` in AI apps).

```csharp
using Ikon.AI.WebSearching;

var searcher = new WebSearcher(WebSearcherModel.Google);

var results = await searcher.SearchPagesAsync(new SearchConfig
{
    Query = "Finnish ice hockey teams",
    MaxResults = 5
});

foreach (var result in results)
{
    Log.Instance.Info($"{result.Title}: {result.Url}");
}

results = await searcher.SearchImagesAsync(new SearchConfig
{
    Query = "Coffee beans",
    MaxResults = 5
});

foreach (var result in results)
{
    Log.Instance.Info($"{result.Title}: {result.Url}");
}
```

## FileConversion

`Ikon.AI.FileConversion.FileConverter` batches binary document conversions and handles long-running jobs transparently.

**Supported models:** See the model enum in the auto-generated Ikon.AI Public API reference for the current list (`docs/Ikon.AI/public-api.md` in AI apps).

```csharp
using Ikon.AI.FileConversion;

var fileConverter = new FileConverter(FileConverterModel.ConvertApi);
var convertedFile = await fileConverter.ConvertToPdfAsync(new FileConverterConfig
{
    Data = await File.ReadAllBytesAsync("brochure.docx"),
    FileName = "brochure.docx"
});
await File.WriteAllBytesAsync("brochure.pdf", convertedFile.Data);
```

## OCR

`Ikon.AI.OCR.OCR` extracts selectable text and structural metadata from images or PDFs.

**Supported models:** See the model enum in the auto-generated Ikon.AI Public API reference for the current list (`docs/Ikon.AI/public-api.md` in AI apps).

```csharp
using Ikon.AI.OCR;

var ocr = new OCR(OCRModel.AzureDocumentIntelligence);
var result = await ocr.AnalyzeDocumentAsync(new OCRConfig
{
    Data = await File.ReadAllBytesAsync("invoice.pdf")
});

Log.Instance.Info(result.Text);
```

## Reranking

`Ikon.AI.Reranking.Reranker` orders candidate documents for relevance to a query to improve retrieval pipelines.

**Supported models:** See the model enum in the auto-generated Ikon.AI Public API reference for the current list (`docs/Ikon.AI/public-api.md` in AI apps).

```csharp
using Ikon.AI.Reranking;

using var reranker = new Reranker(RerankModel.CohereRerank4Fast);

var items = await reranker.RerankAsync(
    ["Document about AI", "Document about cooking", "Document about space exploration"],
    query: "What is the latest in artificial intelligence?"
);

foreach (var item in items)
{
    Log.Instance.Info($"Index: {item.Index}, Score: {item.Score}");
}
```

## Classification

`Ikon.AI.Classification.Classifier` performs moderation and category detection with score-level transparency per safety label.

**Supported models:** See the model enum in the auto-generated Ikon.AI Public API reference for the current list (`docs/Ikon.AI/public-api.md` in AI apps).

```csharp
using Ikon.AI.Classification;

using var classifier = new Classifier(ClassificationModel.OpenAIOmniModeration);

var result = await classifier.ClassifyAsync("What a nice weather!");
Log.Instance.Info($"Flagged: {result.IsFlagged}");

result = await classifier.ClassifyAsync("How to kill kittens? (not really!)");
Log.Instance.Info($"Flagged: {result.IsFlagged}");

foreach (var detail in result.Details)
{
    if (detail.IsFlagged)
    {
        Log.Instance.Info($"{detail.Label} ({detail.OriginalCategory}): {detail.Score}");
    }
}
```

## Embeddings

`Ikon.AI.Embeddings.EmbeddingGenerator` creates vector representations for similarity search, clustering, or semantic scoring.

**Supported models:** See the model enum in the auto-generated Ikon.AI Public API reference for the current list (`docs/Ikon.AI/public-api.md` in AI apps).

```csharp
using Ikon.AI.Embeddings;

using var embeddingGenerator = new EmbeddingGenerator(EmbeddingModel.OpenAI3Small);

var embeddings = await embeddingGenerator.GenerateEmbeddingsAsync(
    ["Example sentence 1", "Example sentence 2", "Example sentence 3"],
    EmbeddingType.Document
);

foreach (var embedding in embeddings)
{
    Log.Instance.Info($"Embedding length: {embedding.Length}");
}
```

## Kernel

`Ikon.AI.Kernel` supplies shared primitives such as `KernelContext`, `MessageBlock`, and `Instruction` that underpin shaders and direct LLM calls.

## Chat

`Ikon.AI.Chat` provides abstractions for orchestrating multi-turn assistant conversations, including channel routing and history policies.

## Retrieving

`Ikon.AI.Retrieving` includes connectors, caches, and vector store helpers for retrieval-augmented generation flows.

## Database

`Ikon.AI.Database` offers persistence helpers for metadata, embeddings, and job tracking across AI workflows.
