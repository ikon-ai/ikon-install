# A Live Prediction Markets Dashboard in Under a Thousand Lines

A prediction markets dashboard that crawls a public leaderboard, classifies wallets by trading behavior, gets AI-powered copy-trading recommendations, saves snapshots to the cloud, and serves a filterable, searchable interface to every connected viewer simultaneously. One file. No API routes, no client-side data fetching, no state management library, no real-time infrastructure setup.

This is not a radical departure from how you would build a dashboard. The same pieces exist: data fetching, pagination, data transformation, filtering, AI integration, persistence. What is different is how little ceremony is needed to wire them together.

## What you get

The dashboard pulls wallet data from a public prediction markets leaderboard. It shows each wallet's rank, profit and loss, trading volume, win rate, and return on investment. Each wallet is classified into a trading profile -- Whale, Sniper, Active Trader, or Arbitrage -- based on its behavior patterns. You can filter by profile type, sort by different metrics, search by address or username, and set minimum win rate thresholds.

Click any wallet row and a detail panel opens with the full profile: trading history, performance metrics, classification rationale, and links to external pages.

## Shared by default

Every connected viewer sees the same dashboard, the same data, the same AI analysis -- updated in real time. When one analyst triggers a data refresh, every viewer sees the progress updates, the wallet list populate, and the final count. When someone asks the AI for insights, the response appears for everyone.

There is no broadcast logic in the application. No event channels. No conflict resolution. The platform handles state synchronization automatically. Multiple analysts watching the same dashboard see the same data and the same real-time updates without any additional code.

## Progressive loading -- usable immediately

The dashboard loads in two phases. Phase one pulls the leaderboard quickly: rank, profit/loss, volume, address. The dashboard is immediately usable -- you can browse, filter, and sort.

Phase two runs in the background, fetching detailed activity data for the top wallets and computing win rates from their trading history. As each wallet's details finish loading, the dashboard updates live. You do not wait for everything to finish before you can start working.

On startup, the dashboard also checks for a previously saved snapshot and loads it instantly, so you see data the moment you open the page. You can refresh on demand whenever you want current numbers.

## Wallet classification

Each wallet gets classified into a trading profile based on readable rules:

- **Whale** -- moves over a million in volume. Large position traders.
- **Sniper** -- high return on investment on relatively small positions. High-conviction, early-entry traders.
- **Active Trader** -- diversified across many markets.
- **Arbitrage** -- moderate returns, likely exploiting price differences.

The classification rules are readable enough to be self-documenting:

```csharp
private static string ClassifyTradingProfile(WalletProfile wallet)
{
    if (wallet.Volume > 1_000_000) return "Whale";
    if (wallet.RoiPercent > 50 && wallet.Volume < 100_000) return "Sniper";
    if (wallet.MarketsTraded > 50) return "Active Trader";
    if (wallet.RoiPercent > 20 && wallet.RoiPercent < 50) return "Arbitrage";
    return "Unclassified";
}
```

No machine learning, no training data — just clear thresholds that produce useful buckets for filtering and analysis.

Each profile also gets a brief signal description, like "High-conviction trader -- mirror early entries in high-volume markets."

## AI-powered analysis

The dashboard has an AI insights panel. You type a question -- "Which wallets should I mirror this week and why?" -- and the app sends the top filtered wallets along with your question to an AI model. The AI receives real numbers -- profit/loss, volume, win rate -- and returns specific, actionable output: a short summary, three to five trade ideas based on top traders' patterns, and three wallet addresses worth monitoring.

The AI is configured to be grounded and conservative -- it produces consistent, data-driven recommendations rather than creative speculation.

## Filtering, sorting, and search

The dashboard offers several ways to slice the data: time period (all time, month, week, day), sort order (profit/loss, volume, win rate), profile type filter, minimum win rate threshold, and free-text search across addresses and usernames.

Every filter updates the view instantly. Change a dropdown or type a search query, and the list recalculates and re-renders immediately for every connected viewer.

## Cloud persistence

Wallet data saves to the cloud automatically. On startup, the most recent snapshot loads instantly. You can refresh on demand to pull fresh data. The persistence layer is minimal -- save after a crawl, load on startup. No database schema, no migrations, no configuration.

## What the traditional stack looks like

The traditional version of this dashboard is a well-understood pattern. A React frontend. A backend with API endpoints for crawling, filtering, and AI calls. A state management library on the client. Data fetching with loading states and error handling. If you want real-time updates, add WebSocket or server-sent event infrastructure. If you want multiple people to see the same data, add a publish/subscribe layer. If you want persistence, add a database with migrations.

None of those pieces are hard individually. The interesting observation is not that Ikon replaces them with something radically different, but that it makes most of them unnecessary. There are no API routes because the server renders the interface directly. There is no client-side state management because state lives on the server. There is no real-time setup because the platform handles it. There is no serialization boundary to maintain because the same language defines the data, the logic, and the interface.

The data fetching calls look the same as they would anywhere. The filtering logic looks the same. The AI prompt construction looks the same. What vanishes is the glue: the fetch calls, the loading indicators, the error boundaries, the state synchronization, the reconnection logic, the drift between client and server types.

## Takeaway

A prediction markets dashboard is not a novel application. Crawl data, classify it, show it in a filterable list, let an AI analyze it. What is worth noting is the gap between the conceptual simplicity of that description and the actual implementation effort on a traditional stack. API endpoints, client state management, real-time infrastructure, deployment of separate services -- these are not hard problems, but they are cumulative overhead that compounds with every feature.

Here, the entire application is a single file under a thousand lines. The crawl logic, the classification, the filtering, the AI integration, the persistence, the expandable detail views, the multiuser support -- all in one place, in one language, with no infrastructure to configure. None of these capabilities are unique. What is unusual is having all of them available with so little ceremony.
