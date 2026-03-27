# A Creator Discovery Crawler in a Single File

Finding the right social media creators for a marketing campaign is usually a manual grind. Someone opens a search engine, types keywords, scrolls through profiles, copies URLs into a spreadsheet, visits each one to check follower counts and bio relevance, then emails the team a CSV. The ambitious version involves a scraping cluster, a job queue, a database, a separate AI service for scoring, a proxy rotation layer, and a dashboard to view results. That is a lot of infrastructure for what amounts to: search, scrape, rank, export.

This post looks at an influencer discovery tool built as a single Ikon AI app -- about two thousand lines in one file, no database, no job queue, no separate frontend. You describe your product in plain language, the tool finds TikTok creators who match, scores each one with written reasoning, enriches them with cross-platform data, and presents the results in a sortable, filterable interface with export to JSON and Mailchimp CSV. Multiple users can watch the crawl progress in real time.

## What you experience

You type a description of your product and the kind of creator you are looking for -- something like "cozy roguelite adventure game with a wizard cat and antique shop." The system generates optimized search keywords from your description, covering phrasings you might not think of: "cozy roguelite," "wizard cat game," "indie RPG," "antique shop sim," "wholesome gaming."

Then the crawl begins. You watch it happen in real time through a color-coded event log styled like a terminal: blue entries for search activity, purple for profile scraping, cyan for AI analysis, green for successes, yellow for warnings. Each entry has a millisecond timestamp. When the scraper hits a verification wall, you see it immediately in yellow. When the AI finds a business email during enrichment, it appears in green.

As profiles move through the pipeline, placeholder cards appear in the results the moment a URL is discovered, fill in with scraped data when the profile loads, and gain AI scores and enrichment data as they arrive. The whole crawl can take several minutes, and the live feedback keeps you informed throughout.

## Multiuser for free

There is no multiuser code in this application. When the scraper finds a new profile, every connected user's results update. When the AI finishes scoring a batch, every user sees the scores appear. The shared crawl state -- running status, profiles found, profiles scraped, event log, result cards -- propagates to everyone automatically.

Per-user state does exist where it makes sense. Each person can independently navigate between tabs, select different profiles, apply their own filters, and choose their own sort order. One user can be viewing the search configuration while another browses results sorted by follower count. The shared crawl and the individual navigation coexist without any synchronization code.

## AI keyword generation from natural language

You do not need to think in search engine terms. The system takes your plain language product description and uses AI to generate twelve to eighteen optimized keyword pairs. Each pair is two to three words designed for effective search: different phrasings of the same concept, related terms, synonyms, adjacent topics. The AI generates more keywords rather than fewer to maximize coverage.

This matters because the quality of a creator search depends heavily on keyword diversity. A human might think of five keyword combinations. The AI produces a broader net, catching creators who describe their niche in unexpected ways.

## Three-stage parallel pipeline

The core architecture is three concurrent stages connected by queues, all running simultaneously:

**Stage one: Discovery.** The system searches TikTok's native user search by driving a headless browser through each keyword, scrolling to load more results, and extracting profile links. Then it runs the same keywords through web search engines as a supplementary source. Each source finds creators the other misses -- native search returns people who match TikTok's own relevance algorithm, while web search catches creators whose profiles are indexed externally but might not rank well in TikTok's internal search.

Every discovered URL is normalized and deduplicated. The tool tracks "query hits" -- how many different keyword searches returned the same profile. A creator who appears in six out of twelve keyword searches is likely more relevant than one who appeared in just one. The most-matched profiles get processed first.

**Stage two: Scraping.** As URLs are discovered, the system loads each profile page, extracts email addresses, pulls follower counts, and gathers bio information. This happens concurrently with discovery -- while new keywords are still being searched, profiles from earlier keywords are already being scraped.

**Stage three: Enrichment.** As profiles are scraped, they are batched and sent to an AI for scoring, then enriched with web search results for cross-platform presence.

All three stages run at the same time with natural flow control. If the scraper falls behind, the discoverer pauses until there is room. The only tuning parameter is the queue size.

## AI scoring with written reasoning

Here is what the AI receives -- the campaign goal and a batch of profiles to evaluate:

```csharp
var prompt = $"""
    Analyze these TikTok influencer profiles and rank them for a marketing campaign.

    CAMPAIGN TARGET: {criteria}

    PROFILES TO RANK:
    {string.Join("\n", profileSummaries)}

    SCORING:
    - 80-100: Excellent fit for campaign based on bio/content
    - 60-79: Good fit with relevant content
    - 40-59: Moderate fit, some relevance
    - 20-39: Weak fit
    - 1-19: Poor fit
    """;
```

The AI returns a score and written reasoning for each profile -- not just a number, but an explanation you can read, evaluate, and disagree with.

Each batch of scraped profiles is evaluated by AI against your campaign criteria. Every profile gets a numeric score and -- critically -- a written explanation. Not just "85" but something like "This creator specializes in indie game reviews with a focus on cozy and roguelite genres, frequently features Steam demos, and has an engaged comment section asking for game recommendations."

The reasoning is visible in the interface, so you can understand why the AI ranked one creator above another and disagree if the logic is wrong. The scoring adapts to your chosen strategy: "Small Creators + High Fit" instructs the AI to prefer creators under 500K followers and prioritize content relevance, while "Large Creators + High Reach" flips the priority toward audience size.

## Cross-platform enrichment

After scoring, each profile goes through a second AI pass. A web search for the creator's handle pulls results from other platforms. The AI extracts cross-platform social handles (Instagram, YouTube, Twitter/X, Twitch, LinkedIn), additional email addresses, content niches, location hints, a profile summary, and a campaign fit analysis.

This enrichment turns a TikTok-only profile into a more complete picture of each creator's presence and reach across the internet.

## Session persistence and shareable URLs

Sessions are saved to cloud storage automatically every minute during active crawls. Each save captures the complete state -- search query, ranking criteria, region filter, processed keywords, and every influencer card with its score, reasoning, emails, social presence, and thumbnails.

Each save also creates a public URL that can be shared with anyone, no login required. If the browser crashes or the connection drops, the latest state is recoverable. If a colleague needs to see the results, you send them a link.

## Export to JSON and Mailchimp CSV

Two export formats cover different workflows. JSON export writes the full dataset -- every field for every profile -- to a downloadable file. Mailchimp CSV export generates a file with standard Mailchimp headers plus custom fields for score, TikTok handle, follower count, location, content niches, and AI notes. Only profiles with email addresses make it into the CSV, since you need an email to start a Mailchimp campaign. The export button turns into a download link once the file is generated.

## What this would take on a traditional stack

The equivalent system on a conventional stack requires: a scraping service with a headless browser pool and proxy rotation, a job queue to manage the pipeline stages, a database to store profiles and sessions and crawl state, an AI integration service with prompt templates and structured output parsing, a REST API, a frontend application with state management and real-time updates, an export service, and authentication for the sharing feature. That is at minimum five or six services, three or four infrastructure dependencies, and a frontend application -- typically built over weeks, with additional time spent on operational concerns like reconnection handling, stale state, and race conditions.

Here, the entire application is one file. There is no API because there is no client-server boundary to cross. There is no job queue because in-process queues with backpressure do the same work. There is no database because the asset system handles persistence. There is no WebSocket configuration because the framework handles the transport. The operational surface is one deployable unit.

## Takeaway

The interesting thing about this tool is not that it crawls profiles or scores them with AI. Plenty of influencer discovery platforms do that. What is unusual is the ratio of capability to effort. A parallel three-stage pipeline with backpressure, multi-source search with deduplication, AI keyword generation, AI scoring with written reasoning, cross-platform enrichment, session persistence with shareable URLs, two export formats, color-coded real-time logging, and multiuser support -- in about two thousand lines of a single file. Each of those features normally lives in a different service maintained by a different person. Here they are part of one coherent application, connected by queues and shared state instead of network calls and message brokers. That is what collapses when the scraping, AI orchestration, UI, and state management all share a process.
