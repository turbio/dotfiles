#!/usr/bin/env nu

# Pulls Claude usage from the Anthropic account-global usage API instead of
# parsing local ~/.claude/projects/*.jsonl. This means usage is reflected
# regardless of which machine Claude actually runs on (e.g. over SSH on a
# remote box). Polls adaptively: fast right after a change, backing off as
# things go quiet, and hides the waybar item entirely after >1h of no change.

const CLIENT_ID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
const USAGE_URL = "https://api.anthropic.com/api/oauth/usage"
const TOKEN_URL = "https://platform.claude.com/v1/oauth/token"

def log [msg: string] {
  $"[(date now | format date '%H:%M:%S')] ($msg)" | print -e
}

def main [] {
  let creds_path = $"($env.HOME)/.claude/.credentials.json"
  let pidfile = "/tmp/claude-waybar.pid"

  log "starting claude-waybar (api mode)"

  if ($pidfile | path exists) {
    let old_pid = try { open $pidfile | str trim | into int } catch { 0 }
    if $old_pid > 0 and $old_pid != $nu.pid {
      log $"killing old instance pid=($old_pid)"
      try { kill $old_pid }
    }
  }
  $"($nu.pid)" | save -f $pidfile
  log $"pid=($nu.pid)"

  # last_change tracks the last time usage actually moved. We start "now" so
  # the item shows and polls fast on startup.
  mut last_change = (date now)
  mut prev_sig = ""
  # Consecutive auth/fetch failures. Used to back off so a rate-limited token
  # endpoint (429) isn't hammered every loop, which only prolongs the limit.
  mut fails = 0

  loop {
    let usage = get_usage $creds_path

    if $usage == null {
      $fails = $fails + 1
      let backoff = backoff_interval $fails
      log $"no usage (auth/fetch failed), backoff ($backoff | into string)"
      print '{"text": ""}'
      sleep $backoff
      continue
    }
    $fails = 0

    let now = (date now)
    let sig = usage_sig $usage
    if $sig != $prev_sig {
      if $prev_sig != "" { log "change detected" }
      $last_change = $now
      $prev_sig = $sig
    }

    let idle = $now - $last_change
    if $idle > 1hr {
      log $"idle ($idle | into string), hiding"
      print '{"text": ""}'
    } else {
      render $usage $now | print
    }

    let wait = pick_interval $idle
    log $"sleep ($wait | into string)"
    sleep $wait
  }
}

# Poll faster the more recent the last change was; hidden state polls slowly
# but still often enough to notice activity resuming.
def pick_interval [idle: duration]: nothing -> duration {
  if $idle > 1hr {
    10min
  } else if $idle < 2min {
    20sec
  } else if $idle < 10min {
    1min
  } else if $idle < 30min {
    3min
  } else {
    5min
  }
}

# Exponential backoff after consecutive failures, capped. Keeps us off a
# rate-limited (429) token/usage endpoint instead of retrying every 2min.
def backoff_interval [fails: int]: nothing -> duration {
  if $fails <= 1 {
    2min
  } else if $fails == 2 {
    5min
  } else if $fails == 3 {
    10min
  } else {
    20min
  }
}

# A fingerprint of the usage numbers we care about, used to detect change.
def usage_sig [u]: nothing -> string {
  [
    ($u | get -i five_hour | default {} | get -i utilization | default 0)
    ($u | get -i seven_day | default {} | get -i utilization | default 0)
    ($u | get -i seven_day_opus | default {} | get -i utilization | default 0)
    ($u | get -i seven_day_sonnet | default {} | get -i utilization | default 0)
    ($u | get -i spend | default {} | get -i used | default {} | get -i amount_minor | default 0)
  ] | each {|x| $x | into string } | str join "|"
}

# Fetch usage, refreshing the OAuth token on demand (proactively when expired,
# reactively on a 401). Returns the parsed usage record or null.
def get_usage [creds_path: string]: nothing -> any {
  let token = ensure_token $creds_path
  if $token == null { return null }

  let r = fetch_usage $token
  if $r.code == 200 {
    return (try { $r.body | from json } catch { null })
  }
  if $r.code == 401 {
    log "401, forcing refresh"
    let t2 = refresh_and_save $creds_path
    if $t2 == null { return null }
    let r2 = fetch_usage $t2
    if $r2.code == 200 {
      return (try { $r2.body | from json } catch { null })
    }
    log $"fetch failed after refresh code=($r2.code)"
    return null
  }
  log $"fetch failed code=($r.code)"
  null
}

def fetch_usage [token: string]: nothing -> record {
  let out = (do {
    ^curl -s -m 10 -w "\n%{http_code}" -H $"Authorization: Bearer ($token)" -H "Content-Type: application/json" $USAGE_URL
  } | complete)
  let lines = $out.stdout | lines
  if ($lines | is-empty) { return { code: 0, body: "" } }
  let code = try { $lines | last | str trim | into int } catch { 0 }
  let body = $lines | drop 1 | str join "\n"
  { code: $code, body: $body }
}

# Returns a usable access token, refreshing first if the stored one is expired
# (or about to be). null if we have no credentials at all.
def ensure_token [creds_path: string]: nothing -> any {
  let creds = try { open $creds_path } catch { return null }
  let oauth = $creds | get -i claudeAiOauth | default {}
  let token = $oauth | get -i accessToken | default ""
  if ($token | is-empty) { return null }

  let expires = $oauth | get -i expiresAt | default 0
  let now_ms = (date now | into int) // 1_000_000
  if $expires > ($now_ms + 60000) {
    return $token
  }
  log "token expired, refreshing"
  refresh_and_save $creds_path
}

# Refresh the OAuth token and write the new credentials back to disk (matching
# the schema Claude Code itself writes), so the local token stays valid even
# when Claude is only ever run on remote machines. Returns the new access token.
def refresh_and_save [creds_path: string]: nothing -> any {
  let creds = try { open $creds_path } catch { return null }
  let oauth = $creds | get -i claudeAiOauth | default {}
  let refresh = $oauth | get -i refreshToken | default ""
  if ($refresh | is-empty) { log "no refresh token"; return null }
  let scopes = $oauth | get -i scopes | default []

  let body = {
    grant_type: "refresh_token"
    refresh_token: $refresh
    client_id: $CLIENT_ID
    scope: ($scopes | str join " ")
  } | to json -r

  let out = (do {
    ^curl -s -m 30 -w "\n%{http_code}" -X POST -H "Content-Type: application/json" -d $body $TOKEN_URL
  } | complete)
  let lines = $out.stdout | lines
  let code = try { $lines | last | str trim | into int } catch { 0 }
  if $code != 200 {
    log $"refresh failed code=($code)"
    return null
  }

  let resp = try { ($lines | drop 1 | str join "\n") | from json } catch { return null }
  let new_access = $resp | get -i access_token | default ""
  if ($new_access | is-empty) { log "refresh: no access_token in response"; return null }
  let new_refresh = $resp | get -i refresh_token | default $refresh
  let expires_in = $resp | get -i expires_in | default 0
  let now_ms = (date now | into int) // 1_000_000
  let new_expires = $now_ms + ($expires_in * 1000)

  let new_oauth = $oauth | merge {
    accessToken: $new_access
    refreshToken: $new_refresh
    expiresAt: $new_expires
  }
  let updated = $creds | upsert claudeAiOauth $new_oauth

  # Write atomically with restricted perms so the token isn't briefly world-readable.
  let tmp = $"($creds_path).waybar.tmp"
  $updated | to json | save -f $tmp
  ^chmod 600 $tmp
  ^mv -f $tmp $creds_path
  log "token refreshed"
  $new_access
}

def render [u, now: datetime]: nothing -> string {
  let five = $u | get -i five_hour | default {}
  let five_pct = ($five | get -i utilization | default 0) | math round
  let five_reset = $five | get -i resets_at

  # Pacing within the rolling 5h window: are we burning quota faster or slower
  # than a steady rate would predict?
  let pace_icon = if $five_reset != null {
    let reset = $five_reset | into datetime
    let start = $reset - 5hr
    let elapsed_pct = ((($now - $start) | into int) / (5hr | into int)) * 100
    let pace = if $elapsed_pct > 0 { $five_pct / $elapsed_pct } else { 0.0 }
    if $pace > 1.05 { "↑" } else if $pace < 0.95 { "↓" } else { "→" }
  } else { "→" }

  let remaining_str = if $five_reset != null {
    fmt_duration (($five_reset | into datetime) - $now)
  } else { "" }

  let seven = $u | get -i seven_day | default {}
  let seven_pct = ($seven | get -i utilization | default 0) | math round
  let seven_reset = $seven | get -i resets_at
  let seven_remaining = if $seven_reset != null {
    fmt_duration (($seven_reset | into datetime) - $now)
  } else { "" }

  let text = $"($five_pct)% ($pace_icon) ⧖($remaining_str) · ($seven_pct)%w"

  let class = if $five_pct >= 90 or $seven_pct >= 90 {
    "critical"
  } else if $five_pct >= 75 or $seven_pct >= 75 {
    "warning"
  } else {
    ""
  }

  let opus = $u | get -i seven_day_opus
  let sonnet = $u | get -i seven_day_sonnet
  let opus_line = if $opus != null {
    $"\nOpus 7d: (($opus | get -i utilization | default 0) | math round)%"
  } else { "" }
  let sonnet_line = if $sonnet != null {
    $"\nSonnet 7d: (($sonnet | get -i utilization | default 0) | math round)%"
  } else { "" }

  let spend = $u | get -i spend | default {}
  let spend_line = if ($spend | get -i enabled | default false) {
    let used = (($spend | get -i used | default {} | get -i amount_minor | default 0) / 100) | math round --precision 2
    let limit = (($spend | get -i limit | default {} | get -i amount_minor | default 0) / 100) | math round --precision 2
    $"\nExtra: $($used)/$($limit)"
  } else { "" }

  let tooltip = $"Session 5h: ($five_pct)% · resets ($remaining_str)\nWeekly: ($seven_pct)% · resets ($seven_remaining)($opus_line)($sonnet_line)($spend_line)"

  { text: $text, tooltip: $tooltip, class: $class } | to json -r
}

def fmt_duration [d: duration]: nothing -> string {
  let secs = $d | into int | $in // 1_000_000_000
  if $secs <= 0 {
    "now"
  } else if $secs >= 86400 {
    let days = $secs // 86400
    let hours = ($secs mod 86400) // 3600
    $"($days)d($hours)h"
  } else {
    let hours = $secs // 3600
    let mins = ($secs mod 3600) // 60
    let mins_str = if $mins < 10 { $"0($mins)" } else { $mins | into string }
    $"($hours)h($mins_str)m"
  }
}
