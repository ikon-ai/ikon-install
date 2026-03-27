# Custom Map Component Guide

This guide shows how to add an interactive map component to an Ikon AI App using Leaflet. The pattern covers creating a custom frontend React component, a C# extension method to drive it, and bidirectional communication between the two.

## Architecture Overview

```
C# App (cloud)                          Frontend (browser)
 |                                        |
 |  view.MyMap(markers, onClick...)       |
 |  --> serializes data to JSON           |
 |  --> creates action IDs for callbacks  |
 |  --> calls view.AddNode("my-map", ...) |
 |                                        |
 |  ---- props sent as UI diff -------->  |
 |                                        |  MyMapRenderer reads props
 |                                        |  MyMapInner renders Leaflet map
 |                                        |  User clicks/drags on map
 |                                        |
 |  <--- dispatchAction(actionId, data)   |
 |                                        |
 |  C# callback fires with typed data    |
```

- **Data flows C# -> Frontend** as JSON-serialized props via `view.AddNode`
- **Events flow Frontend -> C#** via `dispatchAction(actionId, payload)` where `actionId` was created by `view.CreateAction<T>`
- The C# app declares the UI shape reactively; any change to `Reactive<T>` values triggers a re-render

## Step 1: Frontend Component

### Install Leaflet

In your app's `frontend-node/` directory:

```bash
npm install leaflet
npm install -D @types/leaflet
```

### Create the component

Create `frontend-node/src/lib/my-map/components/my-map.tsx`:

```tsx
import { memo, useEffect, useRef } from 'react';
import {
  type IkonUiComponentResolver,
  type UiComponentRendererProps,
  useUiNode,
} from '@ikonai/sdk-react-ui';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';

// --- Data interfaces (mirror the C# data classes) ---

interface MapPin {
  id: string;
  lat: number;
  lon: number;
  label?: string;
  color?: string;
}

interface AreaOverlay {
  id: string;
  lat: number;
  lon: number;
  radiusMeters: number;
  color: string;
  fillOpacity: number;
  label?: string;
}

// --- Props interface ---

type MyMapProps = {
  pins?: string;          // JSON array of MapPin
  areas?: string;         // JSON array of AreaOverlay
  center?: string;        // JSON [lat, lon]
  zoom?: number;
  className?: string;
  onPinClickId?: string;  // Action ID for pin click callback
  onMapClickId?: string;  // Action ID for map click callback
  dispatchAction?: (actionId: string, payload: unknown) => void;
};

// --- Parsing helpers ---

function parsePins(str: string | undefined): MapPin[] {
  if (!str) return [];
  try {
    const parsed = JSON.parse(str);
    return Array.isArray(parsed) ? parsed.filter(
      (p): p is MapPin => typeof p?.id === 'string' && typeof p?.lat === 'number'
    ) : [];
  } catch { return []; }
}

function parseAreas(str: string | undefined): AreaOverlay[] {
  if (!str) return [];
  try {
    const parsed = JSON.parse(str);
    return Array.isArray(parsed) ? parsed.filter(
      (a): a is AreaOverlay => typeof a?.id === 'string' && typeof a?.lat === 'number'
    ) : [];
  } catch { return []; }
}

function parseCenter(str: string | undefined): [number, number] | undefined {
  if (!str) return undefined;
  try {
    const parsed = JSON.parse(str);
    if (Array.isArray(parsed) && parsed.length >= 2) return [parsed[0], parsed[1]];
  } catch { /* ignore */ }
  return undefined;
}

// --- Prop extraction helpers ---

function toStringValue(value: unknown): string | undefined {
  if (typeof value === 'string') {
    const trimmed = value.trim();
    return trimmed.length > 0 ? trimmed : undefined;
  }
  return undefined;
}

function toFiniteNumber(value: unknown): number | undefined {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  if (typeof value === 'string') {
    const n = Number(value.trim());
    return Number.isFinite(n) ? n : undefined;
  }
  return undefined;
}

// --- Inner map component (memoized) ---

const MyMapInner = memo(function MyMapInner(props: MyMapProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<L.Map | null>(null);
  const pinsLayerRef = useRef<L.LayerGroup | null>(null);
  const areasLayerRef = useRef<L.LayerGroup | null>(null);
  const initialCenterRef = useRef<[number, number] | null>(null);

  // Initialize map (runs once)
  useEffect(() => {
    if (!containerRef.current || mapRef.current) return;

    if (initialCenterRef.current === null) {
      initialCenterRef.current = parseCenter(props.center) || [51.505, -0.09];
    }

    const map = L.map(containerRef.current, {
      center: initialCenterRef.current,
      zoom: props.zoom ?? 13,
      attributionControl: false,
    });

    L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', {
      subdomains: 'abcd',
      maxZoom: 19,
    }).addTo(map);

    const pinsLayer = L.layerGroup().addTo(map);
    const areasLayer = L.layerGroup().addTo(map);

    mapRef.current = map;
    pinsLayerRef.current = pinsLayer;
    areasLayerRef.current = areasLayer;

    return () => {
      map.remove();
      mapRef.current = null;
      pinsLayerRef.current = null;
      areasLayerRef.current = null;
    };
  }, []);

  // Map click handler
  useEffect(() => {
    const map = mapRef.current;
    if (!map || !props.onMapClickId || !props.dispatchAction) return;

    const handler = (e: L.LeafletMouseEvent) => {
      props.dispatchAction!(props.onMapClickId!, {
        lat: e.latlng.lat,
        lon: e.latlng.lng,
      });
    };
    map.on('click', handler);
    return () => { map.off('click', handler); };
  }, [props.onMapClickId, props.dispatchAction]);

  // Update pins
  useEffect(() => {
    if (!pinsLayerRef.current) return;
    pinsLayerRef.current.clearLayers();

    for (const pin of parsePins(props.pins)) {
      const marker = L.circleMarker([pin.lat, pin.lon], {
        radius: 8,
        color: pin.color || '#3388ff',
        fillColor: pin.color || '#3388ff',
        fillOpacity: 0.8,
      });

      if (pin.label) {
        marker.bindTooltip(pin.label, { permanent: false, direction: 'top' });
      }

      if (props.onPinClickId && props.dispatchAction) {
        marker.on('click', () => {
          props.dispatchAction!(props.onPinClickId!, {
            id: pin.id,
            lat: pin.lat,
            lon: pin.lon,
          });
        });
      }

      marker.addTo(pinsLayerRef.current!);
    }
  }, [props.pins, props.onPinClickId, props.dispatchAction]);

  // Update area overlays
  useEffect(() => {
    if (!areasLayerRef.current) return;
    areasLayerRef.current.clearLayers();

    for (const area of parseAreas(props.areas)) {
      const circle = L.circle([area.lat, area.lon], {
        radius: area.radiusMeters,
        color: area.color,
        fillColor: area.color,
        fillOpacity: area.fillOpacity,
        weight: 2,
      });

      if (area.label) {
        circle.bindTooltip(area.label, {
          permanent: true,
          direction: 'center',
        });
      }

      circle.addTo(areasLayerRef.current!);
    }
  }, [props.areas]);

  return (
    <div
      ref={containerRef}
      className={props.className}
      style={{ width: '100%', height: '100%', background: '#1a1a2e' }}
    />
  );
}, (prev, next) => {
  // Custom memo comparison — intentionally excludes center/zoom
  // to prevent re-renders from resetting the user's pan/zoom state
  return (
    prev.pins === next.pins &&
    prev.areas === next.areas &&
    prev.className === next.className &&
    prev.onPinClickId === next.onPinClickId &&
    prev.onMapClickId === next.onMapClickId &&
    prev.dispatchAction === next.dispatchAction
  );
});

// --- Renderer: bridges Ikon UI node props to React component ---

const MyMapRenderer = memo(function MyMapRenderer({
  nodeId,
  context,
  className,
}: UiComponentRendererProps & { initialNode?: unknown }) {
  const node = useUiNode(context.store, nodeId);
  if (!node) return null;

  const combinedClassName = [
    ...node.styleIds,
    className,
  ].filter(Boolean).join(' ') || undefined;

  return (
    <MyMapInner
      pins={toStringValue(node.props['pins'])}
      areas={toStringValue(node.props['areas'])}
      center={toStringValue(node.props['center'])}
      zoom={toFiniteNumber(node.props['zoom'])}
      className={combinedClassName}
      onPinClickId={toStringValue(node.props['onPinClickId'])}
      onMapClickId={toStringValue(node.props['onMapClickId'])}
      dispatchAction={context.dispatchAction}
    />
  );
});

// --- Resolver: tells the Ikon UI system which node type this handles ---

export function createMyMapResolver(): IkonUiComponentResolver {
  return (initialNode) => {
    if (initialNode.type !== 'my-map') return undefined;
    return MyMapRenderer;
  };
}
```

Key points:
- `MyMapInner` is `memo`-ized with a custom comparator to avoid resetting pan/zoom
- Each data layer (pins, areas) has its own `useRef<L.LayerGroup>` and `useEffect`
- Events go back to C# via `props.dispatchAction(actionId, payload)`
- The `MyMapRenderer` bridges the generic Ikon UI node system to the typed React component

### Create the module registration

Create `frontend-node/src/lib/my-map/my-map-module.ts`:

```typescript
import { type IkonUiComponentResolver, type IkonUiModuleLoader, type IkonUiRegistry } from '@ikonai/sdk-react-ui';
import { createMyMapResolver } from './components/my-map';

export const IKON_UI_MY_MAP_MODULE = 'my-map';

export function createMyMapResolvers(): IkonUiComponentResolver[] {
  return [createMyMapResolver()];
}

export const loadMyMapModule: IkonUiModuleLoader = () => createMyMapResolvers();

export function registerMyMapModule(registry: IkonUiRegistry): void {
  registry.registerModule(IKON_UI_MY_MAP_MODULE, loadMyMapModule);
}
```

Create `frontend-node/src/lib/my-map/index.ts`:

```typescript
export { registerMyMapModule } from './my-map-module';
```

### Register in app.tsx

In your `frontend-node/src/app.tsx`, import and add the module:

```tsx
import { registerMyMapModule } from './lib/my-map';

// In the useIkonApp call:
const app = useIkonApp({
  modules: [registerStandardUiModule, registerLucideIconsModule, registerMyMapModule],
});
```

## Step 2: C# Data Classes + Extension Method

Create a file in your C# app (e.g. `MyMapExtensions.cs`):

```csharp
using System.Runtime.CompilerServices;
using System.Text.Json;
using System.Text.Json.Serialization;
using Ikon.Parallax;

// --- Data classes (serialized to JSON for the frontend) ---

public class MapPin
{
    [JsonPropertyName("id")] public string Id { get; set; } = "";
    [JsonPropertyName("lat")] public double Lat { get; set; }
    [JsonPropertyName("lon")] public double Lon { get; set; }
    [JsonPropertyName("label")] public string? Label { get; set; }
    [JsonPropertyName("color")] public string? Color { get; set; }
}

public class AreaOverlay
{
    [JsonPropertyName("id")] public string Id { get; set; } = "";
    [JsonPropertyName("lat")] public double Lat { get; set; }
    [JsonPropertyName("lon")] public double Lon { get; set; }
    [JsonPropertyName("radiusMeters")] public float RadiusMeters { get; set; }
    [JsonPropertyName("color")] public string Color { get; set; } = "#3388ff";
    [JsonPropertyName("fillOpacity")] public float FillOpacity { get; set; } = 0.15f;
    [JsonPropertyName("label")] public string? Label { get; set; }
}

// --- Event data classes (deserialized from frontend dispatches) ---

public class PinClickData
{
    [JsonPropertyName("id")] public string Id { get; set; } = "";
    [JsonPropertyName("lat")] public double Lat { get; set; }
    [JsonPropertyName("lon")] public double Lon { get; set; }
}

public class MapClickData
{
    [JsonPropertyName("lat")] public double Lat { get; set; }
    [JsonPropertyName("lon")] public double Lon { get; set; }
}

// --- Node type constant ---

internal static class MyMapNodeTypes
{
    public const string MyMap = "my-map";
}

// --- Extension method ---

public static class MyMapExtensions
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
    };

    public static void MyMap(
        this UIView view,
        List<MapPin>? pins = null,
        List<AreaOverlay>? areas = null,
        double? centerLat = null,
        double? centerLon = null,
        int? zoom = null,
        Func<PinClickData, Task>? onPinClick = null,
        Func<MapClickData, Task>? onMapClick = null,
        string[]? style = null,
        string? styleId = null,
        string? key = null,
        [CallerFilePath] string file = "",
        [CallerLineNumber] int line = 0)
    {
        // Serialize data to JSON
        string? pinsJson = pins != null ? JsonSerializer.Serialize(pins, JsonOptions) : null;
        string? areasJson = areas != null ? JsonSerializer.Serialize(areas, JsonOptions) : null;
        string? centerJson = centerLat.HasValue && centerLon.HasValue
            ? JsonSerializer.Serialize(new[] { centerLat.Value, centerLon.Value })
            : null;

        // Create action IDs for callbacks
        string? onPinClickId = null;
        string? onMapClickId = null;

        if (onPinClick != null)
        {
            onPinClickId = view.CreateAction<PinClickData>(args => onPinClick(args.Value));
        }

        if (onMapClick != null)
        {
            onMapClickId = view.CreateAction<MapClickData>(args => onMapClick(args.Value));
        }

        // Register the UI node with all props
        view.AddNode(
            MyMapNodeTypes.MyMap,
            new Dictionary<string, object?>
            {
                ["pins"] = pinsJson,
                ["areas"] = areasJson,
                ["center"] = centerJson,
                ["zoom"] = zoom,
                ["onPinClickId"] = onPinClickId,
                ["onMapClickId"] = onMapClickId,
            },
            key: key,
            style: style,
            styleId: styleId,
            file: file,
            line: line);
    }
}
```

### How it works

1. **Data classes** use `[JsonPropertyName]` to control the JSON key names — these must match the TypeScript interfaces exactly
2. **`view.CreateAction<T>(callback)`** registers a typed callback and returns an action ID string. When the frontend calls `dispatchAction(actionId, payload)`, the payload is deserialized as `T` and the callback fires
3. **`view.AddNode(nodeType, props)`** emits a UI node. The `nodeType` string (`"my-map"`) must match the resolver check in the frontend. Props are a `Dictionary<string, object?>` — null values are omitted from the diff

## Step 3: Using the Map in Your App

```csharp
[App]
public class MyApp(IApp<SessionIdentity, ClientParameters> host)
{
    private UI UI { get; } = new(host, new Theme());

    private readonly Reactive<List<MapPin>> _pins = new([]);
    private readonly Reactive<string?> _selectedPinId = new(null);
    private readonly Reactive<string?> _lastClickInfo = new(null);

    public async Task Main()
    {
        // Seed some example pins
        _pins.Value.Add(new MapPin { Id = "hq", Lat = 51.505, Lon = -0.09, Label = "HQ", Color = "#00ff88" });
        _pins.Value.Add(new MapPin { Id = "depot", Lat = 51.51, Lon = -0.08, Label = "Depot", Color = "#ff6600" });

        UI.Root([Page.Default], content: view =>
        {
            view.Column(["flex-1"], content: view =>
            {
                view.Row(["flex-1"], content: view =>
                {
                    // The map takes up most of the space
                    view.MyMap(
                        pins: _pins.Value,
                        areas:
                        [
                            new AreaOverlay
                            {
                                Id = "zone1",
                                Lat = 51.505, Lon = -0.09,
                                RadiusMeters = 500,
                                Color = "#33D17A",
                                FillOpacity = 0.1f,
                                Label = "Safe Zone"
                            }
                        ],
                        centerLat: 51.505,
                        centerLon: -0.09,
                        zoom: 14,
                        onPinClick: async data =>
                        {
                            _selectedPinId.Value = data.Id;
                            _lastClickInfo.Value = $"Pin: {data.Id} at ({data.Lat:F4}, {data.Lon:F4})";
                        },
                        onMapClick: async data =>
                        {
                            _lastClickInfo.Value = $"Map click: ({data.Lat:F4}, {data.Lon:F4})";
                        },
                        style: ["flex-1"]);

                    // Side panel
                    view.Column(["w-64 p-4 border-l border-gray-700 bg-gray-900"], content: view =>
                    {
                        view.Text(["text-sm font-bold text-gray-300"], "MAP INFO");

                        if (_lastClickInfo.Value != null)
                        {
                            view.Text(["text-xs text-gray-400 mt-2"], _lastClickInfo.Value);
                        }

                        if (_selectedPinId.Value != null)
                        {
                            view.Text(["text-xs text-green-400 mt-2"], $"Selected: {_selectedPinId.Value}");
                        }
                    });
                });
            });
        });
    }
}
```

## Adding Interactive Features

### Draggable markers

To make markers draggable, follow this pattern:

**Frontend** — create the Leaflet marker with `draggable: true`, dispatch on `dragend`:

```tsx
const marker = L.marker([pin.lat, pin.lon], { icon, draggable: true });

marker.on('dragend', () => {
  const pos = marker.getLatLng();
  props.dispatchAction!(props.onPinDragId!, {
    id: pin.id,
    lat: pos.lat,
    lon: pos.lng,
  });
});

// Prevent map click from firing when interacting with the marker
marker.on('click', (e: L.LeafletMouseEvent) => {
  L.DomEvent.stopPropagation(e);
});
```

**C#** — add the corresponding data class, parameter, and action wiring:

```csharp
public class PinDragData
{
    [JsonPropertyName("id")] public string Id { get; set; } = "";
    [JsonPropertyName("lat")] public double Lat { get; set; }
    [JsonPropertyName("lon")] public double Lon { get; set; }
}

// In the extension method, add a parameter:
Func<PinDragData, Task>? onPinDrag = null,

// Wire it:
if (onPinDrag != null)
{
    onPinDragId = view.CreateAction<PinDragData>(args => onPinDrag(args.Value));
}

// Pass in the node props:
["onPinDragId"] = onPinDragId,
```

### Adding new props

Every time you add a new prop:

1. Add the prop to the TypeScript `Props` type
2. Add it to the custom `memo` comparator
3. Extract it in the `Renderer` component via `toStringValue(node.props['myProp'])`
4. Pass it through to the `Inner` component
5. Add the corresponding C# parameter, serialization, and dictionary entry

### Polygon and rectangle overlays

For polygon shapes, pass vertices as `number[][]` (array of `[lat, lon]` pairs):

```tsx
// Frontend
if (area.vertices && area.vertices.length >= 3) {
  const latLngs = area.vertices.map(v => [v[0], v[1]] as [number, number]);
  shape = L.polygon(latLngs, shapeOptions);
}
```

```csharp
// C# data class
[JsonPropertyName("vertices")] public List<double[]>? Vertices { get; set; }

// Building vertex data from GeoPoints
Vertices = points.Select(p => new double[] { p.Latitude, p.Longitude }).ToList()
```

## File Structure Summary

```
your-app/
  app/YourApp/
    MyMapExtensions.cs       # Data classes + UIView extension
    YourApp.cs               # Uses view.MyMap(...)
  frontend-node/
    src/
      lib/my-map/
        components/
          my-map.tsx          # React component with Leaflet
        my-map-module.ts      # Module registration
        index.ts              # Re-export
      app.tsx                 # Registers the module
    package.json              # Has leaflet dependency
```

## Checklist

- [ ] Node type string matches: C# `MyMapNodeTypes.MyMap` == frontend resolver check (`initialNode.type !== 'my-map'`)
- [ ] JSON property names match: C# `[JsonPropertyName("lat")]` == TypeScript interface `lat: number`
- [ ] Action ID prop names match: C# dictionary key `["onMapClickId"]` == frontend `node.props['onMapClickId']` == inner prop `onMapClickId`
- [ ] Every new prop is added to: TypeScript type, memo comparator, renderer extraction, and inner component
- [ ] `leaflet` and `@types/leaflet` are in `package.json`
- [ ] `import 'leaflet/dist/leaflet.css'` is included in the component
- [ ] Module is registered in `app.tsx` via `useIkonApp({ modules: [...] })`
