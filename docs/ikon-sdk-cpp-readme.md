# Ikon AI C++ SDK

The Ikon AI C++ SDK provides a way to connect to Ikon AI App from C++ applications. It is a header-only library requiring C++17.

## Features

- Two authentication modes: API Key, Local Development
- Connection state management with callbacks
- Protocol message sending and receiving
- Configurable timeouts and reconnection
- Header-only library

## Requirements

- C++17 compatible compiler
- Implementations of required interfaces:
  - `ILogInterface` - Logging
  - `IHttpInterface` - HTTP client
  - `INetworkInterface` - TCP client

## Quick Start

```cpp
#include "ikon_sdk.h"
#include "example_logger.h"
#include "example_http_client.h"
#include "example_network_client.h"

using namespace ikon;

int main()
{
    // Create interface implementations
    auto log = std::make_shared<ExampleLogger>();
    auto httpClient = std::make_shared<ExampleHttpClient>();
    auto networkClient = std::make_shared<ExampleNetworkClient>();

    // Create configuration with API key authentication
    IkonClientConfig config;
    config.apiKey = ApiKeyConfig{
        .apiKey = "ikon-xxxxx",           // API key from portal
        .spaceId = "your-space-id",
        .externalUserId = "user-123"
    };
    config.description = "My App";

    // Create and connect the client
    IkonClient client(config, log, httpClient, networkClient);

    client.Ready = [&client]()
    {
        std::cout << "Connected!" << std::endl;
        client.SignalReady();
    };

    client.MessageReceived = [](const ProtocolMessage& message)
    {
        std::cout << "Received message with opcode: " << static_cast<int>(message.GetOpcode()) << std::endl;
    };

    client.Connect();

    return 0;
}
```

## Authentication Modes

The SDK supports two authentication modes. Exactly one must be configured.

### API Key Authentication

Use this for programmatic access to Ikon AI App. Get your API key from the Ikon portal.

```cpp
IkonClientConfig config;
config.apiKey = ApiKeyConfig{
    .apiKey = "ikon-xxxxx",           // API key from portal
    .spaceId = "...",                  // Space ID
    .externalUserId = "user-123",      // Your user identifier
    .channelKey = "main",              // Optional: specific channel
    .sessionId = "session-xyz",        // Optional: target a precomputed session
    .backendType = BackendType::Production,
    .userType = UserType::Human,
    .clientType = ClientType::DesktopApp
};
```

### Local Development

Connect directly to a local Ikon server during development.

```cpp
IkonClientConfig config;
config.local = LocalConfig{
    .host = "localhost",
    .httpsPort = 8443,
    .userId = "dev-user"
};
```

## Connection Lifecycle

### Connection States

The client tracks its connection state via `GetState()`:

| State | Description |
|-------|-------------|
| `Idle` | Initial state, not connected |
| `Connecting` | Authentication and connection in progress |
| `Connected` | Fully connected and ready |
| `Reconnecting` | Lost connection, attempting automatic reconnect |
| `Offline` | Disconnected (user-initiated or max retries exceeded) |

### Callbacks

```cpp
// Connection state changes
client.StateChanged = [](ConnectionState state)
{
    std::cout << "State: " << static_cast<int>(state) << std::endl;
};

// Connection established and ready
client.Ready = [&client]()
{
    // Perform initialization here
    client.SignalReady();  // Signal that this client is ready (mandatory)
};

// Server is stopping (can still send messages)
client.Stopping = []()
{
    std::cout << "Server stopping..." << std::endl;
};

// Disconnected from server
client.Disconnected = []()
{
    std::cout << "Disconnected" << std::endl;
};

// Error occurred
client.ErrorOccurred = [](const std::string& error)
{
    std::cerr << "Error: " << error << std::endl;
};

// Protocol message received
client.MessageReceived = [](const ProtocolMessage& message)
{
    std::cout << "Message opcode: " << static_cast<int>(message.GetOpcode()) << std::endl;
};
```

### Connecting and Disconnecting

```cpp
// Connect (throws on failure)
client.Connect();

// Wait for a specific client to connect
bool found = client.WaitForClient(
    "my-product",                      // productId (optional)
    std::nullopt,                      // userId (optional)
    std::chrono::seconds(30)           // timeout
);

// Disconnect
client.Disconnect();

// Or let destructor handle it
```

### Accessing Client State

```cpp
// Access the client configuration
const IkonClientConfig& config = client.GetConfig();

// Access the global state (available after connection)
const GlobalState* state = client.GetGlobalState();
if (state)
{
    // Use global state...
}
```

## Sending Messages

### Raw Protocol Messages

```cpp
// Send a raw protocol message
auto* ctx = client.GetClientContext();
if (ctx)
{
    auto message = ProtocolMessage::Create(ctx->SessionId, payload);
    client.SendMessage(message);
}
```

### Typed Payloads

```cpp
// Send a typed payload (creates ProtocolMessage automatically)
MyCustomPayload payload;
payload.someField = "value";
client.SendMessage(payload);
```

## Interface Implementations

The SDK requires you to provide implementations of three interfaces. Example implementations are included in the SDK.

### ILogInterface

Implement logging functionality:

```cpp
class ILogInterface
{
public:
    virtual ~ILogInterface() = default;
    virtual void Initialize() = 0;
    virtual void Trace(const std::string& message) = 0;
    virtual void Debug(const std::string& message) = 0;
    virtual void Info(const std::string& message) = 0;
    virtual void Warning(const std::string& message) = 0;
    virtual void Error(const std::string& message) = 0;
    virtual void Critical(const std::string& message) = 0;
};
```

### IHttpInterface

Implement HTTP client functionality:

```cpp
struct HttpRequest
{
    HttpMethod method;
    std::string url;
    std::map<std::string, std::string> headers;
    std::string content;
    int timeoutMs;
    bool disableCertificateValidation;
};

struct HttpResponse
{
    int response_code;
    std::map<std::string, std::string> headers;
    std::string content;
};

class IHttpInterface
{
public:
    virtual ~IHttpInterface() = default;
    virtual HttpResponse Send(const HttpRequest& request) = 0;
};
```

### INetworkInterface

Implement TCP client functionality:

```cpp
class INetworkInterface
{
public:
    virtual ~INetworkInterface() = default;
    virtual bool Connect(const std::string& host, int port) = 0;
    virtual void Disconnect() = 0;
    virtual void Write(const uint8_t* data, size_t size) = 0;
    virtual size_t Read(uint8_t* buffer, size_t maxSize) = 0;
    virtual bool IsConnected() const = 0;
    virtual void SetConnectionClosedCallback(std::function<void()> callback) = 0;
};
```

## Advanced Configuration

### Timeouts

```cpp
IkonClientConfig config;
// ... authentication ...

config.timeouts = TimeoutConfig{
    .connectionTimeoutSec = 30,       // Connection timeout
    .provisioningTimeoutSec = 60,     // Server startup timeout
    .maxReconnectAttempts = 6,        // Max reconnection attempts
    .reconnectBackoffMs = 500         // Initial backoff (ms)
};
```

### Protocol Options

```cpp
IkonClientConfig config;
// ... authentication ...

// Filter which message types to receive/send
config.opcodeGroupsFromServer = Opcode::GROUP_ALL;
config.opcodeGroupsToServer = Opcode::GROUP_ALL;

// Payload serialization format
config.payloadType = PayloadType::Teleport;  // Default
```

### Client Identification

```cpp
IkonClientConfig config;
// ... authentication ...

config.deviceId = "unique-device-id";
config.productId = "my-app";
config.versionId = "1.0.0";
config.installId = "install-xyz";
config.locale = "en-US";
config.description = "My Application";
config.parameters = {
    {"custom_param", "value"}
};
```

## API Reference

### Core Types

| Type | Description |
|------|-------------|
| `IkonClient` | Main client class for connecting to Ikon servers |
| `IkonClientConfig` | Configuration struct for the client |
| `ConnectionState` | Enum: `Idle`, `Connecting`, `Connected`, `Reconnecting`, `Offline` |

### Configuration Types

| Type | Description |
|------|-------------|
| `LocalConfig` | Configuration for local server development |
| `ApiKeyConfig` | Configuration for API key authentication |
| `TimeoutConfig` | Timeout settings |
| `BackendType` | Enum: `Production`, `Development` |

### Interface Types

| Type | Description |
|------|-------------|
| `ILogInterface` | Logging interface to implement |
| `IHttpInterface` | HTTP client interface to implement |
| `INetworkInterface` | TCP client interface to implement |

### Protocol Types

| Type | Description |
|------|-------------|
| `ProtocolMessage` | Protocol message for sending/receiving |
| `Context` | Client context from server |
| `GlobalState` | Global state from server |

## License

This SDK is licensed under the Ikon AI SDK License. See `LICENSE` for details.

## Support

For issues and feature requests, contact Ikon support or open an issue on GitHub.
