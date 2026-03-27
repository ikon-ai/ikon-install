# Teleport message schema specification

## 1. Purpose

The Teleport message schema defines the compile-time structure and version evolution of a Teleport message type.
It is the schema used to generate code, not a runtime schema or reflection system.
Every Teleport file represents a message definition that compiles into strongly typed, deterministic code for multiple languages - C#, TypeScript, C++, etc.
Teleport schema aligns 1:1 with the Teleport binary format, ensuring that field ordering, identity, and layout produce identical bytes across languages and builds.

---

## 2. Core Goals

- Deterministic - same definition → same bytes.
- Cross-language identical - every compiler generates identical encoders/decoders.
- No runtime schema - the schema is purely compile-time.
- Compact - minimal syntax, no optional features.
- Composable - nested messages, arrays, and dicts supported.
- Versioned - explicit evolution between message versions.
- Schema-optional - field names map to 32-bit hash IDs at compile time.

---

## 3. File Structure

| Property               | Description                          |
|------------------------|--------------------------------------|
| Extension              | `.tp`                                |
| MIME Type              | `application/x-teleport-schema`      |
| Syntax                 | TOML 1.0                             |
| Runtime Representation | Binary `.tpx` (Teleport core format) |

Each file defines a single root message and may contain nested messages, enums, transforms, and constraints.

---

## 4. Top-Level Keys

| Key              | Required | Description                                                                              |
|------------------|----------|------------------------------------------------------------------------------------------|
| `type`           | optional | Message type. Required when defining fields/nested messages.                             |
| `namespace`      | optional | Root namespace applied to every code generator unless `[namespaces]` overrides it.       |
| `[namespaces]`   | optional | Code generator specific namespaces.                                                      |
| `version`        | optional | Integer version for message. Required when `type` is present.                            |
| `opcode`         | optional | Protocol opcode (int or string). Required when `type` is present.                        |
| `doc`            | optional | Comment or docstring                                                                     |
| `[fields]`       | optional | Field names and types. Only allowed when `type` is present.                              |
| `[nested.*]`     | optional | Nested subtypes                                                                          |
| `[enums.*]`      | optional | Enumerations. When `type` is omitted, these enums become namespace-level (global) types. |
| `[[transforms]]` | optional | Version upgrade logic                                                                    |
| `[constraints]`  | optional | Numeric/string constraints                                                               |

---

## 5. Field Definitions

### Example

```toml
type = "CacheConfig"
version = 1
opcode = "CACHE_CONFIG"
namespace = "Example.Namespace"

[namespaces]
csharp     = "Example.Namespace"
typescript = "Example.Namespace"
cpp        = "Example.Namespace"

[fields]
Description = "string"
Codec       = "AudioCodec"
SampleRate  = "int32"
Channels    = "int32"
BitDepth    = "int32 = 16"
```

`opcode` may be specified as an integer literal or as a string that names an opcode enum defined in the system.

### Namespaces

Set the root namespace with the top-level `namespace` field. This value is used by every code generator unless a language specific override is provided. Leaving `namespace` empty or omitting it entirely removes the namespace.

```toml
namespace = "Example.Namespace"

[namespaces]
csharp     = "Example.Namespace"  # C#
typescript = "Example.Namespace"  # TypeScript
cpp        = "Example.Namespace"  # C++
```

The `[namespaces]` table is optional and may contain only the `csharp`, `typescript`, and `cpp` keys. Set any of those entries to an empty string to suppress the namespace for that specific target while keeping it for the others.

### Allowed Field Type Forms

| Syntax                                                                                         | Meaning                                      |
|------------------------------------------------------------------------------------------------|----------------------------------------------|
| `int32`, `int64`, `uint32`, `uint64`, `float32`, `float64`, `bool`, `string`, `binary`, `guid` | Primitive Teleport types                     |
| `TypeName`                                                                                     | Reference to another defined message or enum |
| `TypeName[]`                                                                                   | Array of homogeneous elements                |
| `{K:V}`                                                                                        | Dictionary from key type K to value type V   |
| `string?`                                                                                      | Optional field                               |
| `int32 = 16`                                                                                   | Default value                                |
| `EnumType = Variant`                                                                           | Enum default                                 |
| `{string:User}`                                                                                | Dict of complex values                       |

### Field Identity

Each field's binary ID is:

```
fieldId = xxHash32(fieldName.UTF8, seed = 0)
```

This ensures reversible mapping between `.tp` and binary `.tpx` - identical to Teleport binary specification section 2.

---

## 6. Nested Messages

```toml
[nested.User]
Id     = "string"
Name   = "string"
Online = "bool = false"
```

- Defines a sub-message within the parent message.
- Nested messages share the parent's version unless explicitly versioned.

---

## 7. Enumerations

```toml
[enums.AudioCodec]
PCM16 = 0
FLAC  = 1
OPUS  = 2
```

- Enum values may be integer literals or quoted string literals.
- Every member within the same enum must use the same value kind (all integers or all strings).
- References appear as `AudioCodec` field types.
- Defaults: `AudioCodec = PCM16`.
- Numeric enums generate real enums in every target language.
- String enums generate TypeScript enums with string initializers, and `public static class` declarations with `const string` fields in C#.
- Fields that use string enums are serialized as strings on the wire while still exposing strongly typed constants in each target language.

```toml
[enums.UIElementLabels]
ChatMessage = "chat-message"
Disabled    = "disabled"
```

## 8. External Dependencies

When a Teleport document references enums or message types defined elsewhere, every occurrence MUST be annotated inline by suffixing the type name with `:enum` or `:type`. The suffix declares the dependency and removes the need for out-of-band declarations.

```toml
[fields]
ContextKind   = "Example.Namespace.ContextType:enum = Unknown"
Telemetry     = "SharedTelemetry:type"
TelemetryCopy = "SharedTelemetry:type"
Tags          = "{string:SharedTelemetry:type}"
Snapshots     = "SharedTelemetry:type[]"
```

- The suffix is required for **every** usage of an external symbol, including entries inside dictionaries or arrays. Apply the annotation to the base type before `[]` or after the key/value type inside `{}`.
- If the name includes dots before the suffix (e.g. `My.Namespace.TypeName:type`), everything before the final `.` is treated as the namespace, otherwise the current message namespace is assumed.
- A single symbol cannot be declared both as `:enum` and `:type` within the same file.

---

## 9. Version Transforms

Version transforms describe structural migrations between message versions.

### Short DSL

```toml
[[transforms]]
from = 2
to   = 3
steps = [
  "remove OldField",
  "rename sample_rate -> SampleRate",
  "map BitDepth = old.bit_depth ?? 16"
]
```

### Structured Form

```toml
[[transforms]]
from = 1
to   = 2

[[transforms.steps]]
rename = { from = "UserName", to = "Name" }

[[transforms.steps]]
remove = "ObsoleteFlag"
```

These are compiled into version-aware deserializers that automatically migrate older Teleport data streams.

---

## 10. Constraints (Optional)

```toml
[constraints]
SampleRate.min = 8000
SampleRate.max = 192000
Channels.min   = 1
Channels.max   = 8
```

Used for static validation during compilation or generated code, never serialized.

---

## 11. Canonical Intermediate Representation (IR)

Compilers normalize each `.tp` file into this in-memory shape. A serialized example looks like:

```json
{
  "type": "AudioStreamBegin",
  "namespace": "Example.Namespace",
  "version": 3,
  "layoutHash": "0x8fd2c0ea",
  "fields": [
    { "name": "Description", "type": "string", "id": "0x5f1c9a6e" },
    { "name": "Codec", "type": "AudioCodec", "id": "0x7de4e18f" },
    { "name": "SampleRate", "type": "int32", "id": "0x1ab9c8f2" },
    { "name": "Channels", "type": "int32", "id": "0x3b1e92c9" },
    { "name": "BitDepth", "type": "int32", "default": 16, "id": "0x17de889b" }
  ]
}
```

- `id` = xxHash32(fieldName.UTF8, seed = 0)
- `layoutHash` = hash of sorted field IDs + version.

---

## 12. Validation Rules

| Rule           | Description                                |
|----------------|--------------------------------------------|
| Field names    | `[A-Za-z_][A-Za-z0-9_]*`                   |
| Duplicates     | Forbidden per scope                        |
| Enum values    | Integers or strings (single kind per enum) |
| Version        | Must increase monotonically                |
| Transforms     | Must chain (vN → vN+1)                     |
| Layout hash    | Must be updated on edit                    |
| Non-zero flags | Invalid                                    |
| Depth >128     | Invalid                                    |

## 13. Compilation Workflow

```
.tp  →  Codegen  →  Generated source  →  Binary (Teleport)
```

### Example CLI

```bash
# Generate C# from one or more .tp files
ikon teleport generate --input ./messages/*.tp --type csharp --output ./generated

# Emit C++ headers for a specific schema
ikon teleport generate --input ./schemas/cache.tp --type cpp --output ./generated
```

### Language Targets

| Language    | Output Type            |
|-------------|------------------------|
| C#          | `sealed partial class` |
| TypeScript  | `interface`            |
| C++         | `struct`               |

---

## 14. Example

```toml
# ChatRoom.tp
type      = "ChatRoom"
namespace = "Example.Namespace"
version   = 2
opcode    = 0x00020010
doc       = "Describes a chat room and its members."

[fields]
Id        = "string"
Title     = "string?"
Members   = "User[]"
CreatedAt = "uint64"
State     = "RoomState = Active"

[nested.User]
Id      = "string"
Name    = "string"
Online  = "bool = false"

[enums.RoomState]
Active   = 0
Archived = 1

[[transforms]]
from = 1
to   = 2
steps = [
  "rename UserName -> Name",
  "map State = old.IsArchived ? Archived : Active"
]

[constraints]
Members.max = 1024
```

### Enum-only Example

```toml
# AudioEnums.tp
namespace = "Example.Namespace"

[enums.AudioCodec]
Pcm16 = 0
Opus  = 1
Flac  = 2
```

The compiler emits these enums directly into the namespace without generating a wrapper class. No `type`, `version`, or `opcode` keys are required when a file only defines global enums.

---

## 15. Relationship to Teleport Core Format

| Aspect         | Teleport Binary        | Teleport schema               |
|----------------|------------------------|-------------------------------|
| Data model     | Objects, Arrays, Dicts | Fields, nested types, enums   |
| Field identity | 32-bit hash            | Defined implicitly            |
| Version        | varuint                | `version = n`                 |
| Encoding       | Canonical binary       | Deterministic schema          |
| JSON mirror    | Direct                 | Generated from schema         |
| Compatibility  | Skippable unknowns     | Transforms DSL                |
| Runtime        | None                   | None                          |
| Purpose        | Wire encoding          | Build-time layout definition  |

Together they form a closed, reversible system:
`.tp` (schema) → `.tpx` (binary) ↔ `.json` (mirror)

---
