# Ikon Pipeline Guide

## Overview

The Ikon Pipeline is a reactive asynchronous parallel data processing framework designed for high-performance workloads. It enables you to define the structure of a processing graph once while relying on an intelligent caching system to determine which steps need re-execution when the pipeline runs again.

Key capabilities:

- **Reactive scheduling**: The pipeline run specifies the structure of the processing graph. When executed, the caching system determines what needs to be re-processed based on what has changed since the last run (code, configuration, or input changes).
- **Fully asynchronous**: Every aspect of the pipeline operates asynchronously, from pipeline definition to runtime execution.
- **Parallel processing**: Processors run in parallel where dependencies allow, fully utilizing the processing power of the host machine.
- **Step-level caching**: Every processing step is cached with automatic invalidation based on processor identity, version, configuration, and input state. This avoids unnecessary re-processing and significantly speeds up subsequent runs.
- **Flexible execution**: Pipelines can be invoked directly from code or executed with the `ikon` CLI tool.
- **Distributed execution**: Support for remote host/client modes enables distributing processor execution across multiple machines.

## Defining and Running a Simple Pipeline

Create a pipeline class and annotate it with `[Pipeline]`. Implement a `Run` method with the required signature and compose processing steps using branch operations. Annotate processor methods with `[Processor]`.

```csharp
using Ikon.Common;
using Ikon.Common.Core;
using Ikon.Pipeline;
using Ikon.Pipeline.Items;

[Pipeline]
private class SimplePipeline
{
    // Pipelines must have a Run method with this signature
    // The cancellation token is optional and can be omitted
    public async Task Run(Pipeline<Item>.Branch inputItems, CancellationToken cancellationToken)
    {
        // Transform one item at a time (but in parallel) using the MyProcessor function
        var outputItems = inputItems.Transform(item => MyProcessor(item, "my parameter", cancellationToken));

        // Output the processed items from the pipeline
        outputItems.Output();
    }

    // Processor input parameters are flexible - choose what you need
    [Processor]
    private static async Task<List<Item>> MyProcessor(Item inputItem, string myParameter, CancellationToken cancellationToken)
    {
        var content = await inputItem.GetContentAsString();
        content = $"{content} - Processed with parameter: {myParameter}";
        var outputItem = await Item.Create(inputItem, $"{inputItem.Name}.example", content, MimeTypes.TextPlain);

        return [outputItem]; // Can return empty list if no output is desired
    }
}
```

### Running the Pipeline

Instantiate a `PipelineRunner`, initialize it with the pipeline type, and submit items for processing.

```csharp
using Ikon.Pipeline;
using Ikon.Pipeline.Items;

using var pipelineRunner = new PipelineRunner();
await pipelineRunner.Initialize<SimplePipeline>();

List<Item> inputItems = [];

for (int i = 0; i < 10; i++)
{
    var item = await Item.CreateInitial($"item{i + 1}", $"Content of item {i + 1}", MimeTypes.TextPlain);
    inputItems.Add(item);
}

var outputItems = await pipelineRunner.Run(inputItems);

foreach (var outputItem in outputItems)
{
    var content = await outputItem.GetContentAsString();
    Log.Instance.Info($"Output item, Name={outputItem.Name}, MimeType={outputItem.MimeType}, Content='{content}'");
}
```

### Streaming Results with RunAsEnumerable

`RunAsEnumerable` streams results as soon as processors emit them, which is useful for long-running workflows.

```csharp
using var pipelineRunner = new PipelineRunner();
await pipelineRunner.Initialize<SimplePipeline>();

List<Item> inputItems = [];

for (int i = 0; i < 10; i++)
{
    var item = await Item.CreateInitial($"item{i + 1}", $"Content of item {i + 1}", MimeTypes.TextPlain);
    inputItems.Add(item);
}

await foreach (var outputItem in pipelineRunner.RunAsEnumerable(inputItems))
{
    var content = await outputItem.GetContentAsString();
    Log.Instance.Info($"Output item, Name={outputItem.Name}, MimeType={outputItem.MimeType}, Content='{content}'");
}
```

### Configuring the Runner

`PipelineRunner.Initialize` accepts a `PipelineRunner.Config` object for fine-grained control over processor retry limits, metadata output, type discovery, and more.

```csharp
using var pipelineRunner = new PipelineRunner();

var pipelineRunnerConfig = new PipelineRunner.Config
{
    TypeName = typeof(SimplePipeline).FullName!,
    ProcessFailureThreshold = 2,
    DisableMetadataOutput = true
    // Additional options available, such as cache paths, default retry configuration, and remote execution toggles
};

await pipelineRunner.Initialize(pipelineRunnerConfig);

List<Item> inputItems = [];

for (int i = 0; i < 10; i++)
{
    var item = await Item.CreateInitial($"item{i + 1}", $"Content of item {i + 1}", MimeTypes.TextPlain);
    inputItems.Add(item);
}

var outputItems = await pipelineRunner.Run(inputItems);

foreach (var outputItem in outputItems)
{
    var content = await outputItem.GetContentAsString();
    Log.Instance.Info($"Output item, Name={outputItem.Name}, MimeType={outputItem.MimeType}, Content='{content}'");
}
```

### Cancellation Support

Pass a `CancellationToken` when invoking the pipeline to halt execution cooperatively.

```csharp
using var pipelineRunner = new PipelineRunner();
await pipelineRunner.Initialize<SimplePipeline>();

List<Item> inputItems = [];

for (int i = 0; i < 10; i++)
{
    var item = await Item.CreateInitial($"item{i + 1}", $"Content of item {i + 1}", MimeTypes.TextPlain);
    inputItems.Add(item);
}

List<Item> outputItems = [];
var cts = new CancellationTokenSource();

try
{
    outputItems = await pipelineRunner.Run(inputItems, cts.Token);
}
catch (OperationCanceledException)
{
    Log.Instance.Info("Pipeline run was cancelled");
}

foreach (var outputItem in outputItems)
{
    var content = await outputItem.GetContentAsString();
    Log.Instance.Info($"Output item, Name={outputItem.Name}, MimeType={outputItem.MimeType}, Content='{content}'");
}
```

## Creating Items

Pipelines operate on immutable `Item` instances that carry content, metadata, and lineage.

### Initial Items

Initial items are created outside a pipeline run (but after pipeline initialization) and are meant to be given as input to a pipeline. Initial items do not have any parent item(s) and must not be created inside a processor.

```csharp
List<Item> inputItems = [];

// Create an initial item from a string
// MIME type specified for small text content as automatic detection may not work well
string stringContent = "This is a string content";
inputItems.Add(await Item.CreateInitial("string_item_name", stringContent, mimeTypeOverride: MimeTypes.TextPlain));

// Create an initial item from a byte array
// MIME type will be analyzed from the content
byte[] byteContent = new byte[1024];
inputItems.Add(await Item.CreateInitial("binary_item_name", byteContent));

// Create an initial item from a stream
// MIME type will be analyzed from the content
await using var stream = new MemoryStream(1024);
inputItems.Add(await Item.CreateInitial("stream_item_name", stream));

// Create an initial item from an object (will be serialized to JSON)
// MIME type will be set automatically
var exampleData = new ExampleData();
inputItems.Add(await Item.CreateInitialFromObject("object_item_name", exampleData));
```

The examples rely on a simple data transfer object for object-based items:

```csharp
private class ExampleData
{
    public string Name { get; set; } = string.Empty;
    public int Age { get; set; }
    public string Occupation { get; set; } = string.Empty;
}
```

### Items Produced by Processors

Non-`Item.CreateInitial*` functions are meant to be used inside processors and (almost) always take in a parent item. The `name` parameter specifies the full item name. Use string interpolation to derive names from parent items. It is also possible, though uncommon, to create items without parents.

```csharp
Item parentItem = /* existing pipeline item */;
Item anotherParentItem = /* another pipeline item */;
List<Item> outputItems = [];

// Create an item from a string with single parent
string stringContent = "This is a string content";
outputItems.Add(await Item.Create(parentItem, $"{parentItem.Name}.name_suffix", stringContent, mimeTypeOverride: MimeTypes.TextPlain));

// Create an item from a string with multiple parents
outputItems.Add(await Item.Create([parentItem, anotherParentItem], "full_item_name", stringContent, mimeTypeOverride: MimeTypes.TextPlain));

// Create an item from a string without any parents (not recommended, but possible)
outputItems.Add(await Item.Create([], "full_item_name", stringContent, mimeTypeOverride: MimeTypes.TextPlain));

// Create an item from a byte array
// MIME type will be analyzed from the content
byte[] byteContent = new byte[1024];
outputItems.Add(await Item.Create(parentItem, $"{parentItem.Name}.name_suffix", byteContent));

// Create an item from a stream
// MIME type will be analyzed from the content
await using var stream = new MemoryStream(1024);
outputItems.Add(await Item.Create(parentItem, $"{parentItem.Name}.name_suffix", stream));

// Create an item from an object (will be serialized to JSON)
// MIME type will be set automatically
var exampleData = new ExampleData();
outputItems.Add(await Item.CreateFromObject(parentItem, $"{parentItem.Name}.name_suffix", exampleData));
```

## Reading Item Content

Items provide asynchronous helpers for working with content in multiple representations.

```csharp
Item parentItem = /* existing pipeline item */;

var stringItem = await Item.Create(parentItem, $"{parentItem.Name}.string", "This is a string content", mimeTypeOverride: MimeTypes.TextPlain);
var byteItem = await Item.Create(parentItem, $"{parentItem.Name}.bytes", new byte[1024]);
await using var stream = new MemoryStream(1024);
var streamItem = await Item.Create(parentItem, $"{parentItem.Name}.stream", stream);
var exampleData = new ExampleData { Name = "John Doe", Age = 30, Occupation = "Engineer" };
var objectItem = await Item.CreateFromObject(parentItem, $"{parentItem.Name}.object", exampleData);

// Get item content as string
string stringContent = await stringItem.GetContentAsString();
Log.Instance.Info($"String content: {stringContent}");

// Get item content as byte array
byte[] byteContent = await byteItem.GetContentAsBytes();
Log.Instance.Info($"Byte content length: {byteContent.Length}");

// Get item content as stream
await using Stream streamContent = await streamItem.GetContentAsStream();
Log.Instance.Info($"Stream content length: {streamContent.Length}");

// Get item content as deserialized object
ExampleData objectContent = await objectItem.GetContentAsObject<ExampleData>();
Log.Instance.Info($"Object content: Name={objectContent.Name}, Age={objectContent.Age}, Occupation={objectContent.Occupation}");
```

## Working with Local Files

Use `LocalFile` to interoperate with APIs that require filesystem access. Temporary files are cleaned up automatically when the `LocalFile` is disposed.

```csharp
Item parentItem = /* existing pipeline item */;
var sourceItem = await Item.Create(parentItem, $"{parentItem.Name}.bytes", new byte[1024]);

// Copy any item to a temporary local file system file
// Useful for external libraries that can only read from a file path
// The local file will be automatically deleted when disposed
using (var localFile = await sourceItem.GetLocalFile())
{
    Log.Instance.Info($"Local file, Path={localFile.Path}, MimeType={localFile.MimeType}");
}

// Create a temporary local file path for writing
// You can give this path to external libraries to write content to
// An item can then be created from the local file
// The file will be automatically deleted when disposed
using (var localFile = new LocalFile(MimeTypes.TextPlain))
{
    await File.WriteAllTextAsync(localFile.Path, "This is some text content");
    var outputItem = await Item.Create(parentItem, "my_item", localFile);
}
```

## Advanced Pipeline Composition

Pipelines can accept strongly typed configuration through dependency injection of `IPipelineHost<TConfig>` and provide rich branching primitives for filtering, batching, streaming, grouping, and observation.

```csharp
// If a config object is desired, the pipeline class can take in an IPipelineHost<TConfig> parameter
// The user supplies the config either as an object or JSON when running the pipeline
// The config will be accessible via the host.Config property
[Pipeline]
private class AdvancedPipeline(IPipelineHost<AdvancedPipeline.Config> host)
{
    // The config object is a user-defined POD class
    public class Config
    {
        public int ConfigValue1 { get; set; } = 1;
        public string ConfigValue2 { get; set; } = "ConfigValue";
    }

    public async Task Run(Pipeline<Item>.Branch inputItems, CancellationToken cancellationToken)
    {
        // Filter items to only those having the "even" tag
        var evenItems = inputItems.Filter(item => item.HasTagsAsync("even"));

        // Filter items to only those having the "odd" tag
        var oddItems = inputItems.Filter(item => item.HasTagsAsync("odd"));

        // Filter items to only those that are objects of type ExampleData
        var objectItems = inputItems.Filter(item => item.IsObjectAsync<ExampleData>());

        // Filter items to only those that are images (based on MIME type)
        var imageItems = inputItems.Filter(item => item.IsImageAsync());

        // All Transform* functions take an expression; the easiest way is to pass a function with parameters
        // The variable values inside the expression are read and used to calculate a hash for the processor call
        // If any of the variable values change, then possible caching for that processor is skipped and it runs
        // If processor name, version, and expression variables are the same as a previous run, cached results are used

        // Process each item separately but in parallel
        evenItems = evenItems.Transform(item => MyProcessor(item, host.Config.ConfigValue2, cancellationToken));

        // Gather items into batches and process each batch in parallel
        // Batch size can be set with maxBatchSize parameter
        oddItems = oddItems.TransformBatch(items => MyBatchProcessor(items, host.Config.ConfigValue2, cancellationToken));

        // Process each item and produce multiple output items as a stream
        var itemToStreamItems = objectItems.TransformStream(item => MyItemToStreamProcessor(item, host.Config.ConfigValue2, cancellationToken));

        // Process multiple input items as a stream and produce multiple output items as a stream
        var streamToStreamItems = oddItems.TransformStream(items => MyStreamToStreamProcessor(items, host.Config.ConfigValue2, cancellationToken));

        // Merge multiple branches into one
        var mergedItems = evenItems.Merge(oddItems, itemToStreamItems, streamToStreamItems);

        // Group items by a key (here process ID) and process each group as a batch
        // Grouping ID can be any string value
        var groupProcessedItems = mergedItems.TransformGroup(item => item.GetProcessIdAsync(), items => MyBatchProcessor(items, host.Config.ConfigValue2, cancellationToken));

        // ForEach can be used to run code for each item without producing any output items
        imageItems.ForEach(async item =>
        {
            Log.Instance.Info($"Image item Name={item.Name}, MimeType={item.MimeType}");
        });

        // All Transform* functions also have a TransformLambda* counterpart that takes a lambda instead of an expression
        // Their use is discouraged as the lambda cannot be analyzed for variable values and thus caching is less effective
        // Also, transparent remote processor handling cannot be used with lambdas
        var doNotUseTransformLambdaItems = inputItems.TransformLambda(async item =>
        {
            return await MyProcessor(item, host.Config.ConfigValue2, cancellationToken);
        });

        // Calling output on any branch outputs those items from the pipeline
        groupProcessedItems.Output();
    }

    [Processor]
    private static async Task<List<Item>> MyProcessor(Item inputItem, string myParameter, CancellationToken cancellationToken)
    {
        var content = await inputItem.GetContentAsString();
        content = $"{content} - Single processed with parameter: {myParameter}";
        var outputItem = await Item.Create(inputItem, $"{inputItem.Name}.processed", content, MimeTypes.TextPlain);

        return [outputItem];
    }

    [Processor]
    private static async Task<List<Item>> MyBatchProcessor(List<Item> inputItems, string myParameter, CancellationToken cancellationToken)
    {
        List<Item> outputItems = [];

        foreach (var item in inputItems)
        {
            cancellationToken.ThrowIfCancellationRequested();
            var content = await item.GetContentAsString();
            content = $"{content} - Batch processed with parameter: {myParameter}";
            var outputItem = await Item.Create(item, $"{item.Name}.batch_processed", content, MimeTypes.TextPlain);
            outputItems.Add(outputItem);
        }

        return outputItems;
    }

    [Processor]
    private static async IAsyncEnumerable<Item> MyItemToStreamProcessor(Item inputItem, string myParameter, [EnumeratorCancellation] CancellationToken cancellationToken)
    {
        // It is assumed that the input item is an object of type ExampleData
        var data = await inputItem.GetContentAsObject<ExampleData>();

        for (int i = 0; i < 10; i++)
        {
            cancellationToken.ThrowIfCancellationRequested();
            var content = await inputItem.GetContentAsString();
            content = $"{content} - Streamed output {i + 1} with parameter {myParameter} for object {data.Name}, Age {data.Age}, Occupation {data.Occupation}";
            var outputItem = await Item.Create(inputItem, $"{inputItem.Name}.stream_processed{i + 1}", content, MimeTypes.TextPlain);
            yield return outputItem;
        }
    }

    [Processor]
    private static async IAsyncEnumerable<Item> MyStreamToStreamProcessor(IAsyncEnumerable<Item> inputItems, string myParameter, [EnumeratorCancellation] CancellationToken cancellationToken)
    {
        await foreach (var item in inputItems.WithCancellation(cancellationToken))
        {
            cancellationToken.ThrowIfCancellationRequested();
            var content = await item.GetContentAsString();
            content = $"{content} - Stream-to-stream processed with parameter: {myParameter}";
            var outputItem = await Item.Create(item, $"{item.Name}.stream2stream_processed", content, MimeTypes.TextPlain);
            yield return outputItem;
        }
    }
}
```

### Running the Advanced Pipeline

Supply a configuration instance, enable persistent caching, and provide rich input collections including tagged items and binary payloads.

```csharp
using var pipelineRunner = new PipelineRunner();

var myPipelineConfig = new AdvancedPipeline.Config
{
    ConfigValue1 = 42,
    ConfigValue2 = "The answer"
};

await pipelineRunner.Initialize<AdvancedPipeline>(
    userConfigInstance: myPipelineConfig, // Give the user config instance to the pipeline runner
    usePersistentCache: true // This Initialize overload has common useful options (for full control, see the overload taking PipelineRunner.Config)
);

List<Item> inputItems = [];

for (int i = 0; i < 10; i++)
{
    List<string> tags = i % 2 == 0 ? ["even"] : ["odd"];
    var item = await Item.CreateInitial($"item{i}", $"Content of item {i}", MimeTypes.TextPlain, tags);
    inputItems.Add(item);
}

inputItems.Add(await Item.CreateInitialFromObject("object_item", new ExampleData { Name = "Alice", Age = 28, Occupation = "Designer" }));
inputItems.Add(await Item.CreateInitial("image_item", new byte[2048], MimeTypes.ImagePng));

var outputItems = await pipelineRunner.Run(inputItems);

foreach (var outputItem in outputItems)
{
    var content = await outputItem.GetContentAsString();
    Log.Instance.Info($"Output item, Name={outputItem.Name}, MimeType={outputItem.MimeType}, Content='{content}'");
}
```

## Running Pipelines with the ikon CLI

Use `ikon pipeline run` to execute a pipeline outside your application code.

### Common Options

| Option | Description |
|--------|-------------|
| `--type-name` | Fully qualified pipeline type to execute. Required when running from pre-built assemblies or when multiple pipelines exist in the project. |
| `--dll-path` | Load the pipeline from an external assembly instead of the current project. |
| `--input` | One or more input files, directories (supports wildcards), or asset URIs. Separate multiple paths with commas. |
| `--recursive` | Recursively enumerate input directories and wildcards. |
| `--config` | Path to a JSON configuration file whose contents are provided to the pipeline host configuration model. |
| `--output` | One or more output destinations (files, directories, or asset URIs) where generated items should be written. Separate multiple paths with commas. |

### Example Usage

```bash
# Run a pipeline from a compiled DLL with input files
ikon pipeline run --dll-path ./bin/Release/MyPipeline.dll --type-name MyNamespace.MyPipeline --input ./data/*.json --output ./output/

# Run with configuration and recursive input scanning
ikon pipeline run --dll-path ./bin/Release/MyPipeline.dll --type-name MyNamespace.MyPipeline --input ./data/ --recursive --config ./pipeline-config.json --output ./output/
```

Additional parameters cover cache directories, retry configuration, remote execution flags, and status reporting. Run `ikon pipeline run --help` for a complete listing.

## Remote Host and Client Modes

The pipeline runner can operate in remote host and client modes to distribute processor execution across multiple machines. This enables scaling processor workloads horizontally using a message bus (RabbitMQ) for communication.

### Prerequisites

Before running distributed pipelines:

1. **RabbitMQ must be running**: The message bus must be operational and accessible before starting any host or client processes.

2. **Shared cache directory**: Host and all clients must have access to the same cache directory path. Items are transmitted through the message bus as lightweight metadata containing a content hash pointer. The actual content is stored in and read from the shared cache. On a single machine, use the same `--cache` path for all processes. For multi-machine deployments, use a shared network drive or NFS mount.

3. **Same pipeline DLL**: All processes (host and clients) must use the same compiled pipeline DLL.

### Defining Remote Processors

Mark processors for remote execution using the `isRemote` parameter in the `[Processor]` attribute:

```csharp
[Pipeline]
public class DistributedPipeline(IPipelineHost<DistributedPipeline.Config> host)
{
    public class Config
    {
        public int DelayMs { get; set; } = 100;
    }

    public async Task Run(Pipeline<Item>.Branch inputItems)
    {
        var stage1 = inputItems.Transform(item => ProcessorA(item, host.Config.DelayMs));
        var stage2 = stage1.Transform(item => ProcessorB(item, host.Config.DelayMs));
        stage2.Output();
    }

    // Mark processor for remote execution with isRemote: true
    // The version parameter is used for cache invalidation and processor identification
    [Processor(isRemote: true, version: 1)]
    private static async Task<List<Item>> ProcessorA(Item item, int delayMs)
    {
        await Task.Delay(delayMs);
        var content = await item.GetContentAsString();
        content += "->A";
        return [await Item.Create(item, $"{item.Name}.a", content, MimeTypes.TextPlain)];
    }

    [Processor(isRemote: true, version: 1)]
    private static async Task<List<Item>> ProcessorB(Item item, int delayMs)
    {
        await Task.Delay(delayMs);
        var content = await item.GetContentAsString();
        content += "->B";
        return [await Item.Create(item, $"{item.Name}.b", content, MimeTypes.TextPlain)];
    }
}
```

**Important limitations for remote processors:**
- `CancellationToken` parameters are **not supported** in remote processors. Remove any `CancellationToken` parameters from methods marked with `isRemote: true`.
- All processor parameters must be JSON-serializable.

### Host Mode

Enable host mode with `PipelineRunner.Config.EnableRemoteHost` or `ikon pipeline run --remote-host`. The host:

- Reads input items and orchestrates the pipeline graph
- Dispatches remote processor calls to clients via the message bus
- Maintains the shared state and content cache
- Collects results and produces output items

### Client Mode

Enable client mode with `PipelineRunner.Config.EnableRemoteClient` or `ikon pipeline run --remote-client`. The client:

- Connects to the message bus and listens for processor calls
- Executes processors locally using content from the shared cache
- Returns results to the host via the message bus
- Runs indefinitely until terminated

### Startup Order

**Critical: Clients must start before the host.** RabbitMQ discards messages if no consumer is bound to a queue. If you start the host first, processor calls may be lost before clients connect.

Recommended startup sequence:
1. Ensure RabbitMQ is running
2. Start all client processes
3. Wait a few seconds for clients to bind to queues
4. Start the host process

### Processor Name Format

Remote processors are identified by their fully qualified name in the format:

```
{Namespace}.{ClassName}.{MethodName}.{Version}
```

For example, the `ProcessorA` method above would have the name:
```
MyNamespace.DistributedPipeline.ProcessorA.1
```

This name format is used when configuring the client processor whitelist.

### Configuration Options

| Option | Description |
|--------|-------------|
| `RabbitMQConnectionString` / `--remote-rabbitmq` | RabbitMQ connection string. Format: `host=localhost;port=5672;username=guest;password=guest`. Required for distributed execution. |
| `MaxRemoteRequestParallelism` / `--max-remote-request-parallelism` | Maximum concurrent remote operations the host processes. Defaults to `ProcessorCount * 100`. |
| `RemoteClientProcessorWhiteList` / `--remote-client-processor-whitelist` | Comma-separated list of processor names this client handles. If omitted, the client handles all remote processors. |
| `CachePath` / `--cache` | Path to the shared content cache directory. Must be the same for host and all clients. |

### Example: Single Client Handling All Processors

```bash
# Terminal 1: Start the client first
ikon pipeline run \
    --dll-path ./bin/Release/MyPipeline.dll \
    --type-name MyNamespace.DistributedPipeline \
    --cache ./shared-cache \
    --remote-client \
    --remote-rabbitmq "host=localhost;port=5672;username=guest;password=guest"

# Terminal 2: Start the host after client is ready (wait a few seconds)
ikon pipeline run \
    --dll-path ./bin/Release/MyPipeline.dll \
    --type-name MyNamespace.DistributedPipeline \
    --input ./data/ \
    --output ./output/ \
    --cache ./shared-cache \
    --remote-host \
    --remote-rabbitmq "host=localhost;port=5672;username=guest;password=guest"
```

### Example: Specialized Clients

Distribute different processors to different clients using the whitelist:

```bash
# Terminal 1: Client handling only ProcessorA
ikon pipeline run \
    --dll-path ./bin/Release/MyPipeline.dll \
    --type-name MyNamespace.DistributedPipeline \
    --cache ./shared-cache \
    --remote-client \
    --remote-rabbitmq "host=localhost;port=5672;username=guest;password=guest" \
    --remote-client-processor-whitelist "MyNamespace.DistributedPipeline.ProcessorA.1"

# Terminal 2: Client handling only ProcessorB
ikon pipeline run \
    --dll-path ./bin/Release/MyPipeline.dll \
    --type-name MyNamespace.DistributedPipeline \
    --cache ./shared-cache \
    --remote-client \
    --remote-rabbitmq "host=localhost;port=5672;username=guest;password=guest" \
    --remote-client-processor-whitelist "MyNamespace.DistributedPipeline.ProcessorB.1"

# Terminal 3: Start the host after clients are ready
ikon pipeline run \
    --dll-path ./bin/Release/MyPipeline.dll \
    --type-name MyNamespace.DistributedPipeline \
    --input ./data/ \
    --output ./output/ \
    --cache ./shared-cache \
    --remote-host \
    --remote-rabbitmq "host=localhost;port=5672;username=guest;password=guest"
```

### Example: Multiple Clients for Load Distribution

Run multiple clients handling the same processors to distribute load:

```bash
# Start multiple clients (each in separate terminal)
# All clients handle all processors - work is distributed via RabbitMQ
ikon pipeline run \
    --dll-path ./bin/Release/MyPipeline.dll \
    --type-name MyNamespace.DistributedPipeline \
    --cache ./shared-cache \
    --remote-client \
    --remote-rabbitmq "host=localhost;port=5672;username=guest;password=guest"
```

### Programmatic Usage

Use `PipelineRunner.RunRemote` to orchestrate distributed execution from code:

```csharp
var config = new PipelineRunner.Config
{
    TypeName = typeof(DistributedPipeline).FullName!,
    DllPath = "./bin/Release/MyPipeline.dll",
    EnableRemoteHost = true,
    EnableRemoteClient = true, // Can run host and client in same process
    RabbitMQConnectionString = "host=localhost;port=5672;username=guest;password=guest",
    CachePath = "./shared-cache"
};

await PipelineRunner.RunRemote(config, status =>
{
    Console.WriteLine($"Processed: {status.ProcessedItemCount}, Failures: {status.ProcessFailureCount}");
}, cancellationToken);
```

When remote modes are active, `PipelineRunner.RunRemote` orchestrates the host/client lifecycle, forwards live status updates, and honors cancellation tokens for cooperative shutdown.
