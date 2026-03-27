# Asset System Developer Guide

## Overview

The Ikon asset system exposes a uniform abstraction for storing and retrieving files, JSON payloads, and other binary or textual artifacts without binding application code to a specific backend. Each `Asset` instance dispatches every read, write, delete, and listing request to the storage driver that corresponds to the asset class encoded in the `AssetUri`, and propagates change notifications through `AssetEventAsync` so caches can react to updates. The API is asynchronous end-to-end, providing cancellation support where appropriate and surfacing metadata on every transfer to enable optimistic concurrency and lifecycle management.

## Asset URIs

All asset identifiers use the `assets://` scheme defined by `AssetUri`. URIs are composed of optional scope segments followed by the asset class and backend-specific path:

```
assets://space/{spaceId}/user/{userId}/channel/{channelId}/{asset-class}/{path/to/resource}?{query}
```

Key rules:

- `space`, `user`, and `channel` segments are optional and may appear in that order. They scope the asset inside the storage backend.
- The asset class segment must match one of the values defined in `AssetClass` (for example `cloud-file`, `cloud-json`, or `embedded-file`).
- The remaining path is interpreted by the storage driver and can include nested folders.
- `AssetUri` instances normalize the file name, expose `With` helpers for cloning with modified components, and provide converters for filesystem paths when assets need to be mirrored locally.

## Storage classes

`AssetClass` maps human-readable URI segments to the available backend implementations. Use the class that best matches the data profile:

| Asset class | URI segment | Characteristics |
|-------------|-------------|-----------------|
| `LocalFile` | `local-file` | File-system backed, primarily for local development and tooling. Paths are rooted under a system-managed directory. |
| `EmbeddedFile` | `embedded-file` | Read-only assets embedded into an assembly. Ideal for shipping seed data and scripts. |
| `CloudFile` | `cloud-file` | Private cloud object storage optimized for arbitrary binary payloads. Supports signed URLs, metadata, and optimistic concurrency tokens. |
| `CloudFilePublic` | `cloud-file-public` | Same backing service as `CloudFile` but exposes public URLs for assets meant to be shared openly. |
| `CloudJson` | `cloud-json` | JSON documents persisted through the Hub API, suited for low-latency configuration payloads. Supports optimistic concurrency via the `LastModified` timestamp. |
| `CloudProfile` | `cloud-profile` | Legacy profile projection support. Marked obsolete and scheduled for removal once dependent workloads migrate. |

Each storage reports metadata such as MIME type, byte size, update timestamp, tags, download URL (when applicable), and the backend-specific identifier through `AssetMetadata` so callers can perform fine-grained reconciliation.

## Asset metadata helpers

Most read and write operations accept or return an `AssetMetadata` instance. Populate `MimeType`, `Tags`, or `LastModified` when writing so that storage drivers can set headers or enforce optimistic concurrency. `Get*WithMetadataAsync` helpers pair the payload with the metadata in an `AssetContent<T>`, disposing underlying streams automatically when needed.

## Storing data

### `GetWriteStreamAsync`

`GetWriteStreamAsync` returns a writable stream bound to the storage driver identified by the URI. The write is committed when the stream is disposed, allowing each storage to finalize uploads (for example by issuing signed PUT requests).

```csharp
var assets = Asset.Instance;
var photoUri = new AssetUri(
    assetClass: AssetClass.CloudFile,
    path: "images/hero.png",
    spaceId: "space-42");

await using var writeStream = await assets.GetWriteStreamAsync(
    photoUri,
    metadata: new AssetMetadata(mimeType: "image/png"));
await using var fileStream = File.OpenRead("./hero.png");
await fileStream.CopyToAsync(writeStream);
```

### `SetTextAsync` / `TrySetTextAsync`

Use `SetTextAsync` to persist UTF-8 encoded text to any storage class that accepts textual payloads (for example `CloudJson`). Provide `AssetMetadata.LastModified` when you need optimistic concurrency: the driver validates the value against the current revision and throws `AssetUpdateConflictException` (or returns `AssetWriteStatus.Conflict` from `TrySetTextAsync`).

```csharp
var settingsUri = new AssetUri(AssetClass.CloudJson, "config/app.json", spaceId: "space-42");
var payload = JsonSerializer.Serialize(settingsObject);
await assets.SetTextAsync(
    settingsUri,
    payload,
    new AssetMetadata(lastModified: cachedMetadata?.LastModified));
```

`TrySetTextAsync` mirrors the behavior but returns an `AssetWriteResult` so you can branch without exceptions:

```csharp
var write = await assets.TrySetTextAsync(settingsUri, payload);
if (write.IsConflict)
{
    // Inspect write.Metadata to decide whether to re-read and retry.
}
```

### `SetBytesAsync` / `TrySetBytesAsync`

`SetBytesAsync` uploads byte arrays that are already materialized in memory. `TrySetBytesAsync` exposes the same optimistic concurrency semantics as the text helper.

```csharp
var thumbnailUri = new AssetUri(AssetClass.CloudFile, "thumbnails/card.jpg", spaceId: "space-42");
await assets.SetBytesAsync(thumbnailUri, thumbnailBytes, new AssetMetadata(mimeType: "image/jpeg"));
```

### `SetAsync<T>`

`SetAsync<T>` serializes arbitrary reference types to JSON (unless the value is already `string` or `byte[]`) and writes the result using `SetTextAsync`. This is a convenient way to persist strongly typed settings without manual serialization.

```csharp
await assets.SetAsync(
    new AssetUri(AssetClass.CloudJson, "layouts/dashboard.json", spaceId: "space-42"),
    new DashboardLayout { Columns = 3, Widgets = widgets });
```

## Loading data

### Existence and metadata

- `ExistsAsync` checks whether an asset is present.
- `GetMetadataAsync` returns metadata or throws if the asset is missing.
- `TryGetMetadataAsync` returns `null` when metadata is unavailable.

```csharp
if (!await assets.ExistsAsync(settingsUri))
{
    throw new InvalidOperationException("Missing configuration asset.");
}

var metadata = await assets.GetMetadataAsync(settingsUri);
Console.WriteLine($"Last updated {metadata.LastModified:O}");
```

### Streams and primitives

- `GetReadStreamAsync` returns `AssetContent<Stream>` so callers can stream large files while inspecting metadata.
- `GetTextWithMetadataAsync` / `GetTextAsync` read UTF-8 text by default and support explicit encodings. `TryGet*` variants avoid throwing.
- `GetBytesWithMetadataAsync` / `GetBytesAsync` materialize the asset into memory as a byte array.

```csharp
var download = await assets.GetReadStreamAsync(photoUri);
await using (download)
{
    await using var destination = File.Create("./downloaded.png");
    await download.Content.CopyToAsync(destination);
}

var script = await assets.GetTextAsync(new AssetUri(AssetClass.EmbeddedFile, "Scripts/init.sql"));
```

### Structured objects

`GetWithMetadataAsync<T>` deserializes JSON payloads into the requested type (with fast paths for `string` and `byte[]`) and surfaces metadata. `GetAsync<T>` and `TryGetAsync<T>` return just the content.

```csharp
var layout = await assets.GetAsync<DashboardLayout>(
    new AssetUri(AssetClass.CloudJson, "layouts/dashboard.json", spaceId: "space-42"));
```

### Change subscriptions

`GetOrUpdateWithMetadataAsync` wires a callback to an asset. The callback is invoked immediately with the current content and again whenever the underlying storage reports an add, change, or delete event. Provide `onAssetNotFound` to seed defaults before subscribing.

```csharp
await assets.GetOrUpdateWithMetadataAsync(
    settingsUri,
    async (args, content) =>
    {
        if (content is null)
        {
            cache.Remove(settingsUri);
            return;
        }

        cache[settingsUri] = content.Content;
    },
    async _ => await assets.SetAsync(settingsUri, Settings.Default));
```

## Listing assets

Use `ListAsync` with an `AssetQuery` to enumerate folders, filter by tags, and paginate through large collections. Listing is currently supported by the `LocalFile` and `EmbeddedFile` backends only. Cloud backends (`CloudFile`, `CloudFilePublic`, `CloudJson`) do not yet support listing and will throw `NotSupportedException`.

```csharp
var folderUri = new AssetUri(AssetClass.LocalFile, "albums/2024/");
var query = new AssetQuery(folderUri)
{
    Tags = new[] { "cover" },
    Limit = 50,
};

var entries = await assets.ListAsync(query);
foreach (var entry in entries)
{
    Console.WriteLine($"{entry.AssetUri.Path} updated {entry.Metadata.LastModified:O}");
}

var nextPageToken = query.NextContinuationToken;
```

Convenience overloads accept an `AssetClass` and optional prefix or a folder URI directly when only the URIs are required.

## Optimistic concurrency workflow

When an asset must not be overwritten blindly, follow this pattern:

1. Read the asset with metadata (`GetTextWithMetadataAsync`, `GetBytesWithMetadataAsync`, or `GetWithMetadataAsync<T>`).
2. Carry `metadata.LastModified` forward into `SetTextAsync` or `SetBytesAsync` via `AssetMetadata`.
3. Handle `AssetUpdateConflictException` (or check `AssetWriteResult.IsConflict`) to trigger a re-read and retry.

This approach is supported consistently across `CloudFile` and `CloudJson` backends and aligns with the Hub service’s `ifUpdatedAt` semantics.
