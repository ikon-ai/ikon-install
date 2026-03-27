# Ikon AI TypeScript SDK

The Ikon AI TypeScript SDK provides a way to connect to Ikon AI App from browser and Node.js applications. It supports modern browsers with ES2020+ and Node.js 18+.

## Features

- Three authentication modes: API Key, Local Development, Session Token
- UI-friendly connection states with automatic slow connection detection
- Automatic reconnection with exponential backoff
- Web Worker support for off-UI-thread protocol processing
- Smart endpoint selection (WebTransport → WebSocket → proxied variants)
- Function registration and remote invocation
- Audio/video playback and capture pipelines
- Framework-agnostic UI state management (sdk-ui)

## Installation

Install the npm package:

```bash
npm install @ikonai/sdk
```

For UI state management (optional):

```bash
npm install @ikonai/sdk-ui
```

## Quick Start

```typescript
import { IkonClient } from '@ikonai/sdk';

// Create configuration with API key authentication
const client = new IkonClient({
  apiKey: {
    apiKey: process.env.IKON_API_KEY!,
    spaceId: 'your-space-id',
    externalUserId: 'user-123',
  },
  onConnectionStateChange: (state) => {
    console.log(`Connection state: ${state}`);
  },
  onProtocolMessage: (message) => {
    console.log('Received protocol message');
  },
  onJoined: async () => {
    console.log('Connected and ready!');
  },
});

await client.connect();
```

## Authentication Modes

The SDK supports three authentication modes. Exactly one must be configured.

### API Key Authentication

Use this for programmatic access to Ikon AI App. Get your API key from the Ikon portal.

```typescript
import { IkonClient, UserType, ClientType } from '@ikonai/sdk';

const client = new IkonClient({
  apiKey: {
    apiKey: 'ikon-xxxxx',              // API key from portal
    spaceId: '...',                     // Space ID
    externalUserId: 'user-123',         // Your user identifier
    channelKey: 'main',                 // Optional: specific channel
    backendType: 'production',          // 'production' | 'development'
    userType: UserType.Human,           // Optional: UserType enum
    clientType: ClientType.DesktopWeb,  // Optional: ClientType enum
  },
});
```

### Local Development

Connect directly to a local Ikon server during development.

```typescript
const client = new IkonClient({
  local: {
    host: 'localhost',
    httpsPort: 8443,
    userId: 'dev-user',  // Optional
  },
});
```

### Session Token Authentication

Use this when the session token was obtained from OAuth flow or anonymous authentication. The JWT token already contains the internal userId.

```typescript
const client = new IkonClient({
  sessionToken: {
    token: 'eyJhbGc...',       // JWT token
    spaceId: '...',             // Space ID
    channelKey: 'lobby',        // Optional: specific channel
    backendType: 'production',  // Optional: backend environment
  },
});
```

## Connection Lifecycle

### Connection States

The client tracks its connection state via the `connectionState` property:

| State | Description |
|-------|-------------|
| `idle` | Initial state, not connected |
| `waitingForExternalConnectUrl` | Waiting for external connect URL (used in preview mode) |
| `connecting` | Authentication and connection in progress |
| `connectingSlow` | Still connecting, taking longer than expected (>5s) |
| `connected` | Fully connected and ready |
| `reconnecting` | Lost connection, attempting automatic reconnect |
| `offline` | Disconnected (timeout, server stopped, user-initiated) |
| `offlineError` | Disconnected due to SDK internal error |

Helper functions are available for common state checks:

```typescript
import { isConnecting, isConnected, isOffline, isError } from '@ikonai/sdk';

// Check state categories
if (isConnecting(client.connectionState)) {
  // waitingForExternalConnectUrl, connecting, connectingSlow, or reconnecting
}

if (isConnected(client.connectionState)) {
  // connected
}

if (isOffline(client.connectionState)) {
  // idle, offline, or offlineError
}

if (isError(client.connectionState)) {
  // offlineError - check client.lastError for details
}
```

### Configuration Callbacks

```typescript
const client = new IkonClient({
  // ... authentication config ...

  // Connection state changes
  onConnectionStateChange: (state) => {
    console.log(`State: ${state}`);
  },

  // Protocol message received
  onProtocolMessage: (message) => {
    const opcode = readOpcode(message);
    console.log(`Received opcode: ${opcode}`);
  },

  // Error occurred
  onError: (error) => {
    console.error(`Error: ${error.message}`);
  },

  // Connected and ready (called after GlobalState received)
  onJoined: async () => {
    // Perform initialization here
    // SDK sends ClientReady after this callback completes
  },

  // Tab visibility changed (browser only)
  onVisibilityChange: (isVisible) => {
    console.log(`Tab visible: ${isVisible}`);
  },
});
```

### Connecting and Disconnecting

```typescript
// Connect (returns Promise, throws on failure)
await client.connect();

// Check connection state
console.log(client.connectionState);  // 'connected'

// Access session ID after connection
console.log(client.sessionId);

// Access GlobalState after connection
console.log(client.globalState);

// Disconnect
client.disconnect();

// Access the last error (when in offlineError state)
if (isError(client.connectionState)) {
  console.error(client.lastError);
}

// Notify the server of client context changes
client.sendUpdateClientContext({
  viewportWidth: window.innerWidth,
  viewportHeight: window.innerHeight,
  theme: 'dark',
});
```

### Automatic Reconnection

The SDK automatically attempts to reconnect when the connection is lost unexpectedly. Configure reconnection behavior:

```typescript
const client = new IkonClient({
  // ... authentication config ...
  timeouts: {
    slowConnectionThresholdMs: 5000,   // Time before 'connectingSlow' state
    connectionTimeoutMs: 60000,        // Connection timeout (60 seconds)
    keepaliveTimeoutMs: 15000,         // Keepalive timeout
    reconnectBackoffMs: 2000,          // Fixed delay between reconnect attempts
    maxReconnectAttempts: 2,           // Max attempts before going offline
  },
});
```

Reconnection uses a fixed delay between attempts (2s by default).

## Message Handling

### Subscribing to Protocol Messages

The SDK provides a subscription-based approach for handling protocol messages:

```typescript
import { readOpcode, readProtocolMessageHeaders } from '@ikonai/sdk';

// Subscribe to all messages
const unsubscribe = client.subscribeToProtocolMessages((message) => {
  const opcode = readOpcode(message);
  const headers = readProtocolMessageHeaders(message);

  console.log(`Opcode: ${opcode}, Sender: ${headers.senderId}`);
});

// Later: unsubscribe
unsubscribe();
```

### Filtered Subscriptions

Filter messages by opcode group for better performance:

```typescript
import { Opcode } from '@ikonai/sdk';

// Subscribe to specific opcode groups
const unsubscribe = client.subscribeToProtocolMessages(
  (message) => {
    // Only receives UI and Actions messages
  },
  {
    opcodeGroupsMask: Opcode.GROUP_UI | Opcode.GROUP_ACTIONS,
  }
);

// Subscribe to specific opcodes
const unsubscribe2 = client.subscribeToProtocolMessages(
  (message) => {
    // Only receives GlobalState messages
  },
  {
    opcodes: [Opcode.CORE_GLOBAL_STATE],
  }
);
```

### Subscribing to State Changes

```typescript
// Subscribe to state changes (called immediately with current state)
const unsubscribe = client.subscribeToState((state) => {
  console.log(`Connection state: ${state}`);
});

// Later: unsubscribe
unsubscribe();
```

### Sending Messages

```typescript
// Send a protocol message
client.sendProtocolMessage(message);

// Send an action call
client.sendActionCall('action-guid-here', JSON.stringify({ key: 'value' }));
```

## Functions

The SDK provides a function registry system that allows you to register callable functions that can be invoked by the server or other connected clients.

### Function Registry

Access the function registry through the client:

```typescript
const registry = client.functionRegistry;
```

### Registering Functions

```typescript
import type { FunctionDefinition } from '@ikonai/sdk';

// Define a function
const definition: FunctionDefinition = {
  name: 'greet',
  description: 'Greets a user by name',
  returnType: { kind: 'string' },
  parameters: [
    {
      name: 'name',
      type: { kind: 'string' },
      description: 'The name to greet',
    },
  ],
};

// Register with handler
const unregister = client.functionRegistry.register(
  definition,
  (name: string) => `Hello, ${name}!`
);

// Later: unregister
unregister();
```

### Async Functions

```typescript
const asyncDefinition: FunctionDefinition = {
  name: 'fetchData',
  description: 'Fetches data from an API',
  returnType: { kind: 'string' },
  parameters: [
    { name: 'url', type: { kind: 'string' } },
  ],
};

client.functionRegistry.register(
  asyncDefinition,
  async (url: string) => {
    const response = await fetch(url);
    return response.text();
  }
);
```

### Returning Binary Data

Use `withResultData` to return both a JSON value and binary data:

```typescript
import { withResultData } from '@ikonai/sdk';

const imageDefinition: FunctionDefinition = {
  name: 'captureImage',
  returnType: { kind: 'string' },
  parameters: [],
};

client.functionRegistry.register(
  imageDefinition,
  async () => {
    const imageData = await captureScreenshot();
    return withResultData('image/png', imageData);
  }
);
```

### Remote Function Calling

Call functions registered by other connected clients:

```typescript
import { FunctionCallError } from '@ikonai/sdk';

// Call a remote function by name
const result = await client.functionRegistry.call<string>('remoteGreet', ['World']);

// List all remote functions
const remoteFuncs = client.functionRegistry.getRemoteFunctions();
console.log(`Remote functions: ${client.functionRegistry.remoteSize}`);

// Get a specific remote function
const func = client.functionRegistry.getRemoteFunction('remoteGreet');

// Handle remote call errors
try {
  await client.functionRegistry.call('riskyOperation');
} catch (error) {
  if (error instanceof FunctionCallError) {
    console.error(`Remote error: ${error.remoteErrorType}`);
    console.error(`Stack trace: ${error.remoteStackTrace}`);
  }
}
```

### Value Descriptors

Function parameters and return types use `ValueDescriptor`:

| Kind | Description | Example |
|------|-------------|---------|
| `boolean` | Boolean value | `{ kind: 'boolean' }` |
| `number` | Numeric value | `{ kind: 'number' }` |
| `string` | String value | `{ kind: 'string' }` |
| `array` | Array of elements | `{ kind: 'array', element: { kind: 'string' } }` |
| `dictionary` | Key-value map | `{ kind: 'dictionary', keyType: 'string', value: { kind: 'number' } }` |

All descriptors support an optional `nullable` property.

## Media Pipelines

The SDK provides built-in audio and video playback/capture pipelines.

### Accessing Media

```typescript
// Audio and video are enabled by default
const audio = client.media.audio;
const video = client.media.video;

// Media capture (browser only)
const capture = client.mediaCapture;
```

### Configuration

```typescript
const client = new IkonClient({
  // ... authentication config ...
  audio: {
    performance: { preferWebCodecs: true },
    background: { allowOnDesktop: true, allowOnMobile: false },
    diagnostics: { enabled: true, statusIntervalMs: 1000 },
  },
  video: {
    performance: { preferWebCodecs: true },
  },
  webRtc: {
    enabled: true,  // Enable WebRTC for audio/video transport
  },
  mediaSession: {
    title: 'My App Audio',
    artist: 'Ikon AI',
  },
});
```

Media pipelines automatically process audio and video protocol messages.

### WebRTC

The SDK supports WebRTC for audio and video transport. Enable it in the configuration:

```typescript
const client = new IkonClient({
  // ... authentication config ...
  webRtc: { enabled: true },
});

// Check if WebRTC is active (false if both audio and video are disabled)
console.log(client.isWebRtcEnabled);

// Access video streams keyed by track index
const streams: Map<number, MediaStream> = client.webRtcVideoStreams;

// Look up a video stream by app-level stream ID
const stream = client.getWebRtcVideoStreamByStreamId('my-stream-id');

// Listen for track map changes from the server
client.onWebRtcTrackMapChanged = (info) => {
  console.log(`Track ${info.kind}:${info.trackIndex} active=${info.active}`);
};
```

## UI State Management (sdk-ui)

The `@ikonai/sdk-ui` library provides framework-agnostic UI state management for rendering Ikon UI updates.

### IkonUiCore

The core class handles protocol messages and maintains UI state:

```typescript
import { IkonUiCore } from '@ikonai/sdk-ui';

const uiCore = new IkonUiCore({
  client,
  threading: {
    uiWorker: 'auto',       // 'auto' | 'disabled'
    flushIntervalMs: 16,
    maxLatencyMs: 50,
  },
});

// Subscribe to UI updates
const unsubscribe = uiCore.subscribeToUiUpdates((streamId, update) => {
  console.log(`UI update for stream: ${streamId}`);
  // update.snapshot contains the parsed UI tree
});

// Subscribe to style changes
uiCore.subscribeToUiStyles((style) => {
  console.log(`Style updated: ${style.styleId}`);
});

// Get current styles
const styles = uiCore.getUiStyles();

// Cleanup
uiCore.dispose();
```

### UiStore

Access the UI store for stream snapshots:

```typescript
// Get all stream snapshots
const snapshots = uiCore.uiStore.getSnapshots();

// Get specific stream
const snapshot = uiCore.uiStore.getSnapshot(streamId);
```

### Custom UI Renderers

To build custom UI renderers for frameworks other than React, use the exported types and utilities:

```typescript
import {
  UiStore,
  UiStreamStore,
  parseUiUpdate,
  HandlerCache,
  type UiNode,
  type UiNodeProps,
  type ParsedUiUpdate,
} from '@ikonai/sdk-ui';

// UiNode represents a UI element
interface UiNode {
  id: string;
  type: string;
  props: UiNodeProps;
  children: readonly UiNode[];
  styleIds: readonly string[];
}

// HandlerCache provides stable event handler references
const cache = new HandlerCache();
const handler = cache.getHandler('node-id', 'action-id', (actionId, payload) => {
  client.sendActionCall(actionId, JSON.stringify(payload));
});
```

The `sdk-ui` library is designed to be framework-agnostic. For React integration, see `@ikonai/sdk-react-ui`.

## Advanced Configuration

### Timeouts

```typescript
const client = new IkonClient({
  // ... authentication config ...
  timeouts: {
    slowConnectionThresholdMs: 5000,   // Default: 5000
    connectionTimeoutMs: 60000,        // Default: 60000 (60 seconds)
    keepaliveTimeoutMs: 15000,         // Default: 15000
    reconnectBackoffMs: 2000,          // Default: 2000
    maxReconnectAttempts: 2,           // Default: 2
  },
});
```

### Protocol Options

```typescript
import { Opcode } from '@ikonai/sdk';

const client = new IkonClient({
  local: {
    host: 'localhost',
    httpsPort: 8443,
    // Filter which message types to receive/send
    opcodeGroupsFromServer: Opcode.GROUP_ALL,
    opcodeGroupsToServer: Opcode.GROUP_ALL,
  },
});
```

### Client Identification

```typescript
const client = new IkonClient({
  apiKey: {
    apiKey: '...',
    spaceId: '...',
    externalUserId: 'user-123',
    // Client identification
    deviceId: 'unique-device-id',
    productId: 'my-app',
    versionId: '1.0.0',
    installId: 'install-xyz',
    locale: 'en-US',
    description: 'My Application',
    parameters: {
      custom_param: 'value',
    },
  },
});
```

### Debug Mode

Enable debug mode by adding `?ikon-debug=true` to the URL, or programmatically:

```typescript
import { initializeDebugMode, isDebugModeEnabled } from '@ikonai/sdk';

// Initialize based on URL parameter (?ikon-debug=true)
initializeDebugMode();

// Check if debug mode is active
if (isDebugModeEnabled()) {
  console.log('Debug mode is enabled');
}
```

### Browser Functions

By default, the SDK auto-registers browser convenience functions (getTheme, setTheme, getLocation, etc.) when running in a browser. Disable this if needed:

```typescript
const client = new IkonClient({
  // ... authentication config ...
  disableBrowserFunctions: true,
});
```

## Logging

Configure SDK logging:

```typescript
import { setLogLevel, setLogSink, LogLevel, createLogger, subscribeToLogEvents } from '@ikonai/sdk';

// Set minimum log level for console output
setLogLevel(LogLevel.DEBUG);  // DEBUG, INFO, WARN, ERROR, NONE

// Set a custom log sink for all messages
setLogSink((entry) => {
  // Forward to your logging service
  myLogger.log(entry.levelName, entry.component, entry.message);
});

// Create a component-specific logger
const logger = createLogger('MyComponent');
logger.info('Starting up');  // [MyComponent] Starting up

// Subscribe to log events (for forwarding to analytics or backend)
const unsubscribeLogs = subscribeToLogEvents(
  (entry) => {
    console.log(`[${entry.levelName}] ${entry.component}: ${entry.message}`);
  },
  { minLevel: LogLevel.WARN }  // Default: WARN and ERROR
);

// Later: unsubscribe
unsubscribeLogs();
```

## Error Types

The SDK provides typed errors for different failure scenarios:

| Error Type | Description |
|------------|-------------|
| `ConnectionError` | Base class for all connection-related errors |
| `AuthenticationError` | Authentication failed (invalid credentials, unauthorized) |
| `TransportError` | Transport-level failure (WebSocket error) |
| `KeepaliveTimeoutError` | No keepalive received within timeout period |
| `MaxRetriesExceededError` | Maximum reconnection attempts exhausted |
| `ProvisioningTimeoutError` | Cloud channel provisioning timed out |
| `ChannelNotFoundError` | Channel with specified key not found |
| `SpaceNotFoundError` | Space not found for given domain |
| `NoChannelsError` | No channels available in the space |
| `AccessDeniedError` | Server denied access (e.g., domain allowlist blocks email domain) |

```typescript
import { AuthenticationError, MaxRetriesExceededError } from '@ikonai/sdk';

const client = new IkonClient({
  // ...
  onError: (error) => {
    if (error instanceof AuthenticationError) {
      console.error('Authentication failed:', error.message);
    } else if (error instanceof MaxRetriesExceededError) {
      console.error('Connection lost, max retries exceeded');
    }
  },
});
```

## API Reference

### Core Types

| Type | Description |
|------|-------------|
| `IkonClient` | Main client class for connecting to Ikon servers |
| `IkonClientConfig` | Configuration for the client |
| `ConnectionState` | Union type: `idle`, `waitingForExternalConnectUrl`, `connecting`, `connectingSlow`, `connected`, `reconnecting`, `offline`, `offlineError` |
| `ProtocolMessage` | Raw protocol message (Uint8Array) |
| `GlobalState` | Server state received after connection |

### Configuration Types

| Type | Description |
|------|-------------|
| `LocalConfig` | Configuration for local server development |
| `ApiKeyConfig` | Configuration for API key authentication |
| `SessionTokenConfig` | Configuration for session token authentication |
| `TimeoutConfig` | Timeout settings |
| `AudioConfig` | Audio playback configuration |
| `VideoConfig` | Video playback configuration |
| `WebRtcConfig` | WebRTC configuration for audio/video transport |
| `MediaSessionConfig` | OS-level media controls metadata |
| `BackendType` | String union: `production`, `development` |

### Function Types

| Type | Description |
|------|-------------|
| `FunctionRegistry` | Central registry for function registration |
| `FunctionDefinition` | Function metadata (name, parameters, return type) |
| `FunctionHandler` | Handler callback type |
| `ValueDescriptor` | Type descriptor for parameters/returns |
| `FunctionResultWithData` | Result type with binary data attachment |
| `RemoteFunction` | Remote function metadata (name, parameters, client session) |
| `FunctionCallError` | Error from remote function call with `remoteErrorType` and `remoteStackTrace` |

### UI Types (sdk-ui)

| Type | Description |
|------|-------------|
| `IkonUiCore` | Core class for UI state management |
| `UiStore` | Multi-stream UI state store |
| `UiStreamStore` | Single-stream UI state store |
| `UiNode` | UI element node |
| `ParsedUiUpdate` | Parsed UI update from protocol |
| `HandlerCache` | Stable event handler memoization |

### Media Types

| Type | Description |
|------|-------------|
| `IkonMedia` | Combined audio/video playback wrapper |
| `IkonAudioPlayback` | Audio playback pipeline |
| `IkonVideoPlayback` | Video playback pipeline |
| `IkonMediaCapture` | Combined capture wrapper (browser only) |
| `IkonAudioCapture` | Audio capture pipeline |
| `IkonVideoCapture` | Video capture pipeline |
| `IkonImageCapture` | Image capture pipeline |

### Error Types

| Type | Description |
|------|-------------|
| `ConnectionError` | Base connection error |
| `AuthenticationError` | Authentication failure |
| `TransportError` | Transport-level failure |
| `KeepaliveTimeoutError` | Keepalive timeout |
| `MaxRetriesExceededError` | Max retries exceeded |
| `ProvisioningTimeoutError` | Provisioning timeout |
| `ChannelNotFoundError` | Channel not found |
| `SpaceNotFoundError` | Space not found |
| `NoChannelsError` | No channels available |
| `AccessDeniedError` | Server denied access (e.g., domain allowlist) |
| `FunctionCallError` | Remote function call failure with error type and stack trace |

### Utility Functions

| Function | Description |
|----------|-------------|
| `isConnecting(state)` | Returns true if waitingForExternalConnectUrl, connecting, connectingSlow, or reconnecting |
| `isConnected(state)` | Returns true if connected |
| `isOffline(state)` | Returns true if idle, offline, or offlineError |
| `isError(state)` | Returns true if offlineError |
| `readOpcode(message)` | Extract opcode from protocol message |
| `readProtocolMessageHeaders(message)` | Extract headers from protocol message |
| `isWebTransportSupported()` | Check WebTransport browser support |
| `getOpcodeName(opcode)` | Get human-readable opcode name |
| `subscribeToLogEvents(listener, options?)` | Subscribe to SDK log events for forwarding |
| `initializeDebugMode()` | Initialize debug mode from URL parameter |
| `isDebugModeEnabled()` | Check if debug mode is active |

## License

This SDK is licensed under the Ikon AI SDK License. See `LICENSE` for details.

## Support

For issues and feature requests, contact Ikon support or open an issue on GitHub.
