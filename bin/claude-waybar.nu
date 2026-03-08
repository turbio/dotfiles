# Claude Code waybar status - shows API usage with pacing indicators

def main [] {
  let creds_path = $"($env.HOME)/.claude/.credentials.json"
  let projects_dir = $"($env.HOME)/.claude/projects"
  let pidfile = "/tmp/claude-waybar.pid"
  let poll_interval = 30sec
  let idle_timeout = 5min

  # Kill previous instance to prevent accumulation on waybar reload
  if ($pidfile | path exists) {
    let old_pid = try { open $pidfile | str trim | into int } catch { 0 }
    if $old_pid > 0 { try { kill $old_pid } }
  }
  $"($nu.pid)" | save -f $pidfile

  mut last_activity = date now

  # Initial fetch if credentials exist
  if ($creds_path | path exists) {
    fetch_and_output $creds_path
    $last_activity = (date now)
  }

  loop {
    # Wait for file changes with timeout
    let wait_time = if ((date now) - $last_activity) < $idle_timeout {
      # Active mode: short timeout for polling
      $poll_interval
    } else {
      # Idle mode: output empty to hide, wait longer on inotify
      print ""
      60sec
    }

    let activity = watch_for_activity $projects_dir $wait_time

    if $activity or (((date now) - $last_activity) < $idle_timeout) {
      if $activity {
        $last_activity = (date now)
      }

      if ($creds_path | path exists) {
        fetch_and_output $creds_path
      }
    }
  }
}

def watch_for_activity [dir: string, timeout: duration]: nothing -> bool {
  if not ($dir | path exists) {
    sleep $timeout
    return false
  }

  let timeout_secs = ($timeout | into int) // 1_000_000_000

  # Use inotifywait with timeout
  let result = do {
    ^inotifywait -q -t $timeout_secs -r -e modify -e create --include '\.jsonl$' $dir
  } | complete

  $result.exit_code == 0
}

def fetch_and_output [creds_path: string] {
  let creds = try { open $creds_path } catch { return }
  let oauth = $creds | get -o claudeAiOauth | default {}

  let token = $oauth | get -o accessToken | default ""
  if ($token | is-empty) {
    return
  }

  let expires = $oauth | get -o expiresAt | default 0
  let now_ms = (date now | into int) // 1_000_000

  # Refresh token if expiring within 5 minutes
  let token = if $expires < ($now_ms + 300_000) {
    let refresh = $oauth | get -o refreshToken | default ""
    if ($refresh | is-empty) {
      $token
    } else {
      try {
        let resp = (http post "https://console.anthropic.com/v1/oauth/token"
          --content-type "application/x-www-form-urlencoded"
          $"grant_type=refresh_token&client_id=9d1c250a-e61b-44d9-88ed-5944d1962f5e&refresh_token=($refresh)")

        let new_access = $resp | get -o access_token | default ""
        if not ($new_access | is-empty) {
          let new_refresh = $resp | get -o refresh_token | default $refresh
          let expires_in = $resp | get -o expires_in | default 0

          $creds
          | upsert claudeAiOauth.accessToken $new_access
          | upsert claudeAiOauth.refreshToken $new_refresh
          | upsert claudeAiOauth.expiresAt ($now_ms + ($expires_in * 1000))
          | save -f $creds_path

          $new_access
        } else {
          $token
        }
      } catch {
        $token
      }
    }
  } else {
    $token
  }

  # Fetch usage
  let resp = try {
    http get "https://api.anthropic.com/api/oauth/usage" --headers [
      Authorization $"Bearer ($token)"
      anthropic-beta "oauth-2025-04-20"
    ]
  } catch {
    return
  }

  let five_hour = $resp | get -o five_hour | default {}
  let seven_day = $resp | get -o seven_day | default {}

  let s_pct = $five_hour | get -o utilization | default 0 | math round
  let w_pct = $seven_day | get -o utilization | default 0 | math round

  let s_resets = $five_hour | get -o resets_at | default (date now | format date "%Y-%m-%dT%H:%M:%S%z")
  let w_resets = $seven_day | get -o resets_at | default (date now | format date "%Y-%m-%dT%H:%M:%S%z")

  let sp = pacing $s_pct $s_resets 18000
  let wp = pacing $w_pct $w_resets 604800

  let class = if ($wp.dev >= 25) or ($w_pct >= 90) {
    "critical"
  } else if ($wp.dev >= 10) or ($w_pct >= 75) {
    "warning"
  } else {
    ""
  }

  {
    text: $"($s_pct)% ($sp.icon) ⧖($sp.elapsed)% (countdown $s_resets)"
    tooltip: $"Weekly: ($w_pct)% ($wp.icon) ⧖($wp.elapsed)% \(resets (countdown $w_resets)\)"
    class: $class
  } | to json -r | print
}

def countdown [reset_time: string]: nothing -> string {
  let reset = try { $reset_time | into datetime } catch { date now }
  let secs = ($reset - (date now)) | into int | $in // 1_000_000_000

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

def pacing [pct: int, reset_time: string, window_s: int]: nothing -> record<icon: string, dev: int, elapsed: int> {
  let reset = try { $reset_time | into datetime } catch { date now }
  let left = ($reset - (date now)) | into int | $in // 1_000_000_000

  let elapsed_pct = if $window_s > 0 {
    ((($window_s - $left) / $window_s) * 100) | math round
  } else {
    0
  }

  let pace = if $elapsed_pct > 0 { $pct / $elapsed_pct } else { 0.0 }

  let result = if $pace > 1.05 {
    { icon: "↑", dev: ((($pace - 1) * 100) | math round) }
  } else if $pace < 0.95 {
    { icon: "↓", dev: (((1 - $pace) * 100) | math round | $in * -1) }
  } else {
    { icon: "→", dev: 0 }
  }

  $result | insert elapsed $elapsed_pct
}
