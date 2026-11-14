# Discord bot

Two versions of the same `/ask` bot:

- **Cloudflare (recommended):** always on, free hosting. See
  [`cloudflare/README.md`](cloudflare/README.md).
- **PC:** runs on your PC while `start_bot.bat` is open. The rest of this
  page is about this version.

Use one or the other, not both at once: once the Discord app has an
Interactions Endpoint URL (Cloudflare), `/ask` goes there and the PC version
stops receiving it.

## PC version

Answers `/ask` questions about the game in Discord, using Claude and the
game's docs in this repo (README, release notes, battle design, enemy roster,
changelog). It reads the docs from this folder, so after you pull or edit them
it answers with the new version, no restart needed. It runs on your PC and
only answers while `start_bot.bat` is open.

## One-time setup

1. **Python 3.10+.** Check with `py --version` in a terminal. If it's missing,
   install it from python.org (tick "Add python.exe to PATH").
2. **Discord application.**
   - Go to <https://discord.com/developers/applications> → **New Application**.
   - **Bot** tab → **Reset Token** → copy the token. No privileged intents
     are needed.
   - **OAuth2** tab → **URL Generator**: tick `bot` and
     `applications.commands`; under Bot Permissions tick **View Channels**
     and **Send Messages**. Open the generated URL and add the bot to your
     server.
3. **Anthropic API key.** At <https://console.anthropic.com>, create a key
   under **API Keys** and add some credit. Set a monthly spend limit under
   **Limits** too.
4. **Keys file.** Copy `.env.example` to `.env` in this folder and fill in
   `DISCORD_TOKEN`, `GUILD_ID` and `ANTHROPIC_API_KEY`. `.env` is ignored by
   git, so your keys never get committed.

## Running it

Double-click `start_bot.bat`. The first run sets up its own Python
environment (a minute or so); after that it starts in a few seconds. Leave
the window open; close it to stop the bot. Each question and its token
usage show in the window.

## Settings (in `.env`)

| Setting | Default | What it does |
|---|---|---|
| `CLAUDE_MODEL` | `claude-haiku-5-5` | The Claude model that answers |
| `COOLDOWN_SECONDS` | 30 | How long each person waits between questions |
| `DAILY_LIMIT` | 200 | Questions answered per day, for everyone together |
| `ASK_CHANNEL_ID` | (any) | Only answer in this channel |

What it knows and how it answers (e.g. it gives hints for hidden Arts before
full recipes) is in `bot.py`: `DOCS` and `INSTRUCTIONS`.
