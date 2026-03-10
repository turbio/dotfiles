# Claude Code waybar status - reads local JSONL data like claude-code-monitor

def log [msg: string] {
  $"[(date now | format date '%H:%M:%S')] ($msg)" | print -e
}

def main [] {
  let projects_dir = $"($env.HOME)/.claude/projects"
  let creds_path = $"($env.HOME)/.claude/.credentials.json"
  let pidfile = "/tmp/claude-waybar.pid"
  let min_interval = 20sec
  let idle_timeout = 5min

  log "starting claude-waybar"

  if ($pidfile | path exists) {
    let old_pid = try { open $pidfile | str trim | into int } catch { 0 }
    if $old_pid > 0 {
      log $"killing old instance pid=($old_pid)"
      try { kill $old_pid }
    }
  }
  $"($nu.pid)" | save -f $pidfile
  log $"pid=($nu.pid)"

  let plan = detect_plan $creds_path
  log $"plan=($plan.name) limit=($plan.tokens)tok $($plan.cost)"

  mut last_activity = date now
  mut last_fetch = "1970-01-01T00:00:00+00:00" | into datetime

  if ($projects_dir | path exists) {
    log "initial compute"
    compute_and_output $projects_dir $plan
    $last_fetch = (date now)
  } else {
    log $"no projects dir: ($projects_dir)"
  }

  loop {
    let wait_time = if ((date now) - $last_activity) < $idle_timeout {
      30sec
    } else {
      log "idle"
      print ""
      60sec
    }

    let activity = watch_for_activity $projects_dir $wait_time
    log $"activity=($activity) idle=(((date now) - $last_activity) | into string)"

    if $activity or (((date now) - $last_activity) < $idle_timeout) {
      if $activity { $last_activity = (date now) }

      let since = (date now) - $last_fetch
      if $since < $min_interval {
        let since_str = $since | into string
        log $"throttled ($since_str) since last"
      } else {
        log "computing usage"
        compute_and_output $projects_dir $plan
        $last_fetch = (date now)
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
  let result = do {
    ^inotifywait -q -t $timeout_secs -r -e modify -e create --include '\.jsonl$' $dir
  } | complete
  $result.exit_code == 0
}

def detect_plan [creds_path: string] {
  let fallback = { name: "pro", tokens: 19000, cost: 18.0, messages: 250 }
  if not ($creds_path | path exists) { return $fallback }
  let oauth = try { open $creds_path } catch { return $fallback }
    | get -i claudeAiOauth | default {}
  let sub = $oauth | get -i subscriptionType | default "" | str downcase
  let tier = $oauth | get -i rateLimitTier | default "" | str downcase

  if ("max_20" in $sub) or ("max_20" in $tier) or ("max20" in $sub) or ("max20" in $tier) {
    { name: "max20", tokens: 220000, cost: 140.0, messages: 2000 }
  } else if ("max_5" in $sub) or ("max_5" in $tier) or ("max5" in $sub) or ("max5" in $tier) {
    { name: "max5", tokens: 88000, cost: 35.0, messages: 1000 }
  } else {
    $fallback
  }
}

def compute_and_output [projects_dir: string, plan] {
  let entries = read_entries $projects_dir
  log $"($entries | length) entries"

  if ($entries | is-empty) {
    log "no entries"
    return
  }

  let now = date now
  let session = find_active_session $entries $now

  if ($session.entries | is-empty) {
    log "no active session"
    return
  }

  let s_output = $session.entries | get output_tokens | math sum
  let s_cost = $session.entries | get cost | math sum
  let s_msgs = $session.entries | length

  let tok_pct = (($s_output / $plan.tokens) * 100) | math round
  let cost_pct = (($s_cost / $plan.cost) * 100) | math round

  # Pacing
  let elapsed_s = ($now - $session.start) | into int | $in // 1_000_000_000
  let elapsed_pct = (($elapsed_s / 18000) * 100) | math round
  let pace = if $elapsed_pct > 0 { $tok_pct / $elapsed_pct } else { 0.0 }
  let icon = if $pace > 1.05 { "↑" } else if $pace < 0.95 { "↓" } else { "→" }

  let remaining = $session.end - $now
  let remaining_str = fmt_duration $remaining

  # Weekly cost
  let week_ago = $now - 7day
  let weekly = $entries | where timestamp > $week_ago
  let w_cost = if ($weekly | is-empty) { 0.0 } else { $weekly | get cost | math sum }

  let class = if $tok_pct >= 90 or $cost_pct >= 90 {
    "critical"
  } else if $tok_pct >= 75 or $cost_pct >= 75 {
    "warning"
  } else {
    ""
  }

  let cost_str = $s_cost | math round --precision 2
  let w_cost_str = $w_cost | math round --precision 2

  let output = {
    text: $"($tok_pct)% ($icon) ⧖($elapsed_pct)% ($remaining_str)"
    tooltip: $"Session: $($cost_str)/$($plan.cost) ($s_output)out_tok ($s_msgs)msg\n7d: $($w_cost_str)\nPlan: ($plan.name)"
    class: $class
  }
  log $"($tok_pct)% $($cost_str) ($remaining_str)"
  $output | to json -r | print
}

def read_entries [projects_dir: string] {
  let cutoff = (date now) - 8day
  let files = glob $"($projects_dir)/**/*.jsonl"
  if ($files | is-empty) { return [] }

  mut all = []
  for file in $files {
    let file_lines = try { open $file --raw | lines } catch { continue }
    for line in $file_lines {
      let trimmed = $line | str trim
      if ($trimmed | is-empty) { continue }
      let data = try { $trimmed | from json } catch { continue }
      let entry = parse_entry $data $cutoff
      if $entry != null {
        $all = ($all | append [$entry])
      }
    }
  }

  if ($all | is-empty) { return [] }

  # Deduplicate by message_id:request_id
  let with_key = $all | where dedup_key != ""
  let without_key = $all | where dedup_key == ""
  let deduped = if ($with_key | is-empty) { [] } else {
    $with_key | sort-by dedup_key | uniq-by dedup_key
  }

  $deduped | append $without_key | sort-by timestamp
}

def parse_entry [data, cutoff: datetime] {
  let ts = try {
    $data.timestamp | into datetime
  } catch {
    try {
      # Unix timestamp in seconds
      $data.timestamp * 1_000_000_000 | into int | into datetime
    } catch { null }
  }

  if $ts == null or $ts < $cutoff {
    return null
  }

  let usage = extract_usage $data
  if $usage.input_tokens == 0 and $usage.output_tokens == 0 {
    return null
  }

  let model = extract_model $data
  let cost = calc_cost $model $usage

  let msg_id = $data | get -i message_id
    | default ($data | get -i message | default {} | get -i id | default "")
  let req_id = $data | get -i request_id
    | default ($data | get -i requestId | default "")
  let dedup_key = if ($msg_id | is-not-empty) and ($req_id | is-not-empty) {
    $"($msg_id):($req_id)"
  } else {
    ""
  }

  {
    timestamp: $ts
    input_tokens: $usage.input_tokens
    output_tokens: $usage.output_tokens
    total_tokens: ($usage.input_tokens + $usage.output_tokens)
    cost: $cost
    model: $model
    dedup_key: $dedup_key
  }
}

def extract_usage [data] {
  let msg_usage = $data | get -i message | default {} | get -i usage | default {}
  let top_usage = $data | get -i usage | default {}
  let is_assistant = ($data | get -i type | default "") == "assistant"

  let sources = if $is_assistant {
    [$msg_usage $top_usage $data]
  } else {
    [$top_usage $msg_usage $data]
  }

  mut found = false
  mut in_tok = 0
  mut out_tok = 0
  mut cc_tok = 0
  mut cr_tok = 0

  for src in $sources {
    if $found { break }
    let input = $src | get -i input_tokens
      | default ($src | get -i inputTokens | default ($src | get -i prompt_tokens | default 0))
    let output = $src | get -i output_tokens
      | default ($src | get -i outputTokens | default ($src | get -i completion_tokens | default 0))

    if ($input | into int | $in > 0) or ($output | into int | $in > 0) {
      $in_tok = ($input | into int)
      $out_tok = ($output | into int)
      $cc_tok = ($src | get -i cache_creation_input_tokens
        | default ($src | get -i cache_creation_tokens
          | default ($src | get -i cacheCreationInputTokens | default 0)) | into int)
      $cr_tok = ($src | get -i cache_read_input_tokens
        | default ($src | get -i cache_read_tokens
          | default ($src | get -i cacheReadInputTokens | default 0)) | into int)
      $found = true
    }
  }

  { input_tokens: $in_tok, output_tokens: $out_tok, cache_creation: $cc_tok, cache_read: $cr_tok }
}

def extract_model [data] {
  let m = $data | get -i message | default {} | get -i model | default ""
  if ($m | is-not-empty) { return $m }
  let m = $data | get -i model | default ""
  if ($m | is-not-empty) { return $m }
  let m = $data | get -i usage | default {} | get -i model | default ""
  if ($m | is-not-empty) { return $m }
  "unknown"
}

def calc_cost [model: string, usage] {
  let m = $model | str downcase
  # Prices per million tokens: [input, output, cache_create, cache_read]
  let p = if "opus" in $m {
    [15.0, 75.0, 18.75, 1.5]
  } else if "haiku" in $m {
    [0.25, 1.25, 0.3, 0.03]
  } else {
    # Sonnet (default)
    [3.0, 15.0, 3.75, 0.3]
  }

  let ci = $usage.input_tokens / 1_000_000.0 * ($p | get 0)
  let co = $usage.output_tokens / 1_000_000.0 * ($p | get 1)
  let ccc = $usage.cache_creation / 1_000_000.0 * ($p | get 2)
  let ccr = $usage.cache_read / 1_000_000.0 * ($p | get 3)
  $ci + $co + $ccc + $ccr
}

def find_active_session [entries, now: datetime] {
  let sorted = $entries | sort-by timestamp
  let epoch = "1970-01-01T00:00:00+00:00" | into datetime

  # Track block boundaries as scalars to avoid nushell type issues with mut records
  mut b_start = $epoch
  mut b_end = $epoch
  mut b_first_idx = 0
  mut b_count = 0
  mut has_block = false

  mut last_start = $epoch
  mut last_end = $epoch
  mut last_first_idx = 0
  mut last_count = 0

  mut prev_ts = $epoch
  mut idx = 0

  for entry in $sorted {
    let ts = $entry.timestamp
    let new_block = if not $has_block {
      true
    } else if $ts >= $b_end {
      true
    } else if (($ts - $prev_ts) | into int) >= 18_000_000_000_000 {
      true
    } else {
      false
    }

    if $new_block {
      if $has_block {
        $last_start = $b_start
        $last_end = $b_end
        $last_first_idx = $b_first_idx
        $last_count = $b_count
      }
      let hour = $ts | format date "%Y-%m-%dT%H:00:00%z" | into datetime
      $b_start = $hour
      $b_end = ($hour + 5hr)
      $b_first_idx = $idx
      $b_count = 1
      $has_block = true
    } else {
      $b_count = $b_count + 1
    }
    $prev_ts = $ts
    $idx = $idx + 1
  }

  # Finalize last block
  if $has_block {
    $last_start = $b_start
    $last_end = $b_end
    $last_first_idx = $b_first_idx
    $last_count = $b_count
  }

  if $last_end > $now {
    let block_entries = $sorted | skip $last_first_idx | first $last_count
    { start: $last_start, end: $last_end, entries: $block_entries }
  } else {
    { start: $now, end: $now, entries: [] }
  }
}

def fmt_duration [d: duration] {
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
