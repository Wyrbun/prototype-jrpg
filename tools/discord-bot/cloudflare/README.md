# Discord bot on Cloudflare Workers

Same `/ask` bot as the PC version, but it runs on Cloudflare, so it answers
even when your PC is off. It reads the docs from GitHub (main branch): push
doc changes and it knows them within 5 minutes. Everything is done in the
browser, nothing to install.

Cost: Cloudflare's free plan is plenty (100,000 requests a day). You only
pay for Claude API usage.

## 1. Discord application

If you haven't yet: at <https://discord.com/developers/applications> →
**New Application**. From **General Information**, note the
**Application ID** and **Public Key**. From the **Bot** tab, click
**Reset Token** and copy the token.

## 2. Create the Worker

1. Sign up at <https://dash.cloudflare.com> (free).
2. **Workers & Pages** → **Create** → start from **Hello World**, name it
   e.g. `jrpg-bot`, and **Deploy**.
3. **Edit code**, delete what's there, paste all of `worker.js`, **Deploy**.
4. Opening the Worker's address (`https://jrpg-bot.<you>.workers.dev`) should
   say "Prototype JRPG bot is running."

## 3. Settings

In the Worker: **Settings** → **Variables and Secrets** → **Add**:

| Name | Type | Value |
|---|---|---|
| `DISCORD_PUBLIC_KEY` | Text | Public Key from step 1 |
| `DISCORD_APPLICATION_ID` | Text | Application ID from step 1 |
| `GUILD_ID` | Text | Your server's ID (Developer Mode → right-click server → Copy Server ID) |
| `DISCORD_TOKEN` | Secret | Bot token from step 1 |
| `ANTHROPIC_API_KEY` | Secret | From console.anthropic.com → API Keys |

Optional: `COOLDOWN_SECONDS` (30), `DAILY_LIMIT` (200), `ASK_CHANNEL_ID`
(only answer in that channel), `CLAUDE_MODEL` (claude-haiku-5-5).

**Recommended, limits storage:** **Storage & Databases** → **KV** → create a
namespace (e.g. `jrpg-bot-limits`), then in the Worker → **Settings** →
**Bindings** → **Add** → **KV namespace**, variable name `LIMITS`. Without
it the cooldown and daily limit still work, but less reliably.

## 4. Connect Discord

1. Discord app → **General Information** → **Interactions Endpoint URL**:
   paste the Worker's address and **Save Changes**. Discord checks it, and
   the Worker signs up the `/ask` command on your server at the same time.
2. **OAuth2** → **URL Generator**: tick `applications.commands` and `bot`
   (View Channels, Send Messages). Open the link and add the bot to your
   server.
3. Type `/ask` in your server.

If saving the URL fails, check that `DISCORD_PUBLIC_KEY` is set and the
Worker is deployed. To see what the bot is doing: Worker → **Logs**.

## Changing it

What it knows (`DOCS`) and how it answers (`INSTRUCTIONS`) are at the top of
`worker.js`. Edit there, paste again into the Worker's editor, **Deploy**.
If you change the `/ask` command itself, save the Interactions Endpoint URL
again in Discord to re-register it.
