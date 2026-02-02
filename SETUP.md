# Setup Guide

Complete setup instructions for the News Curator.

## Prerequisites

1. **Ruby 3.2+**
   ```bash
   ruby --version
   ```

2. **API Keys**
   - GNews API: https://gnews.io/ (free tier: 100 requests/day)
   - Anthropic API: https://console.anthropic.com/ (paid)

## Installation Steps

### 1. Clone and Install

```bash
cd /path/to/news_curator
bundle install
```

### 2. Configure API Keys

```bash
cp .env.example .env
```

Edit `.env`:
```bash
GNEWS_API_KEY=your_gnews_key_from_gnews_io
ANTHROPIC_API_KEY=sk-ant-your_key_from_anthropic
DATABASE_PATH=db/news_curator.db
CURATION_HOUR=7
CURATION_MINUTE=0
```

### 3. Initialize Database

```bash
ruby setup.rb
```

Expected output:
```
News Curator Setup
==================================================

1. Checking Ruby version...
   [OK] Ruby 3.4.7

2. Checking bundler...
   [OK] Bundler available

3. Installing gems...
   [OK] Gems installed

...

[OK] Setup Complete!
```

### 4. Test the System

```bash
ruby test_setup.rb
```

This validates:
- Ruby version
- API keys
- Database connection
- GNews API access
- Anthropic API access
- Model loading

### 5. Run First Curation

```bash
./bin/curate --run
```

Expected output:
```
[INFO] Starting daily news curation...
[INFO] Fetched 10 India articles
[INFO] Fetched 10 unique articles
[INFO] Claude is analyzing articles...
[OK] Successfully curated 2 articles!
```

View results:
```bash
./bin/curate --show
```

## Claude Code Integration

### 1. Create MCP Configuration

Create `~/.claude/mcp.json`:

```json
{
  "mcpServers": {
    "news-curator": {
      "command": "ruby",
      "args": ["/ABSOLUTE/PATH/TO/news_curator/mcp_server.rb"],
      "env": {
        "GNEWS_API_KEY": "your_gnews_key",
        "ANTHROPIC_API_KEY": "your_anthropic_key"
      }
    }
  }
}
```

**Critical**: Use the absolute path! Replace `/ABSOLUTE/PATH/TO/` with your actual path.

Find your path:
```bash
cd /path/to/news_curator
pwd
# Copy this output and append /mcp_server.rb
```

### 2. Install Slash Commands

```bash
mkdir -p ~/.claude/commands
cp commands/*.md ~/.claude/commands/
```

Verify:
```bash
ls -la ~/.claude/commands/
# Should show: news.md, pulse.md
```

### 3. Test MCP Server

```bash
ruby mcp_server.rb
```

Expected output:
```
[MCP] News Curator MCP Server starting...
[MCP] Server name: news-curator
[MCP] Available tools: curate_news, news_feedback, news_preferences, news_history
```

Press Ctrl+C to stop.

### 4. Test in Claude Code

```bash
claude
```

Then type:
```
> /news
```

Should display your curated articles!

## Daily Automation

### Start Scheduler

Foreground (for testing):
```bash
ruby scheduler.rb
```

Background (for production):
```bash
nohup ruby scheduler.rb > logs/scheduler.log 2>&1 &
```

### Verify Scheduler is Running

```bash
ps aux | grep scheduler
```

### View Logs

```bash
tail -f logs/scheduler.log
```

### Stop Scheduler

```bash
# Find process ID
ps aux | grep scheduler

# Kill it
kill <PID>
```

## Verification Checklist

- [ ] Ruby 3.2+ installed
- [ ] Bundle install successful
- [ ] .env file configured with API keys
- [ ] Database initialized (db/news_curator.db exists)
- [ ] Test setup passes (ruby test_setup.rb)
- [ ] Manual curation works (./bin/curate --run)
- [ ] Articles viewable (./bin/curate --show)
- [ ] ~/.claude/mcp.json created with absolute path
- [ ] Skills copied to ~/.claude/skills/
- [ ] MCP server starts (ruby mcp_server.rb)
- [ ] /news command works in Claude Code
- [ ] Scheduler runs (ruby scheduler.rb &)

## Troubleshooting

### Ruby Version Too Old

```bash
# Using rbenv
rbenv install 3.4.7
rbenv global 3.4.7

# Using mise (formerly rtx)
mise install ruby@3.4.7
mise global ruby@3.4.7
```

### Bundle Install Fails

```bash
# Update bundler
gem update bundler

# Clean and retry
rm -rf .bundle vendor
bundle install
```

### API Key Errors

**GNews 401 Unauthorized**:
- Verify key at https://gnews.io/
- Check key is correctly copied to .env
- Ensure no extra spaces

**Anthropic 401 Unauthorized**:
- Verify key at https://console.anthropic.com/
- Check you have credits
- Ensure key starts with `sk-ant-`

### Database Errors

Reset database:
```bash
rm -f db/news_curator.db
ruby setup.rb
```

### MCP Server Not Found in Claude Code

1. Check absolute path in mcp.json:
   ```bash
   cat ~/.claude/mcp.json
   # Verify path is absolute, not relative
   ```

2. Test the path:
   ```bash
   ruby $(cat ~/.claude/mcp.json | grep args | cut -d'"' -f4)
   # Should start the server
   ```

3. Restart Claude Code after config changes

### No Articles Returned

1. Check if curation ran:
   ```bash
   sqlite3 db/news_curator.db "SELECT COUNT(*) FROM curated_articles WHERE DATE(curated_at) = DATE('now');"
   ```

2. Run curation manually:
   ```bash
   ./bin/curate --run
   ```

3. Check GNews API quota:
   - Free tier: 100 requests/day
   - Each curation uses 2 requests

## Next Steps

After successful setup:

1. **Use it daily**: Open Claude Code, type `/news`
2. **Provide feedback**: `./bin/curate --feedback <id> --like/--dislike`
3. **Customize preferences**: Edit UserPreference settings
4. **Monitor logs**: `tail -f logs/scheduler.log`
5. **Adjust schedule**: Edit CURATION_HOUR in .env

## Advanced Configuration

### Change Article Count

```ruby
# In Ruby console
require './lib/database'
require './lib/models/user_preference'
Database.setup!
UserPreference.set('articles_per_day', 3)
```

### Add Custom Topics

```ruby
UserPreference.set('topics', [
  'foreign policy',
  'climate diplomacy',
  'trade agreements',
  'maritime security'
])
```

### Add Focus Areas

```ruby
UserPreference.set('focus_areas', [
  'India-US relations',
  'Indo-Pacific strategy',
  'QUAD alliance',
  'Belt and Road Initiative',
  'India-ASEAN relations'
])
```

### Run Multiple Times Per Day

Edit scheduler.rb to add more cron schedules:
```ruby
# 7 AM
scheduler.cron "0 7 * * *" do
  curator.run_daily_curation
end

# 6 PM
scheduler.cron "0 18 * * *" do
  curator.run_daily_curation
end
```

## Support

For issues:
1. Check this guide
2. Check README.md
3. Check logs: `tail -f logs/scheduler.log`
4. Test components individually (see Troubleshooting)

## File Locations Reference

- **Config**: `/path/to/news_curator/.env`
- **Database**: `/path/to/news_curator/db/news_curator.db`
- **Logs**: `/path/to/news_curator/logs/scheduler.log`
- **MCP Config**: `~/.claude/mcp.json` (user home directory)
- **Skills**: `~/.claude/skills/*.skill` (user home directory)
