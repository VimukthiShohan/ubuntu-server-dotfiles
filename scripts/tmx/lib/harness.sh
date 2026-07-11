# lib/harness.sh — Harness resolution: validate, config, interactive, command mapping
# Sourced by main.sh. Expects: TMX_DIR (set by main.sh before sourcing)

typeset -A HARNESS_COMMANDS=()
typeset -a ALLOWED_HARNESSES=()

# ---------------------------------------------------------------------------
# Registry
# ---------------------------------------------------------------------------

# Load harness registry from config/harnesses.conf.
# Populates ALLOWED_HARNESSES (array) and HARNESS_COMMANDS (associative array).
load_harness_registry() {
  local conf="$TMX_DIR/config/harnesses.conf"
  if [[ ! -f "$conf" ]]; then
    echo "Error: harness registry not found: $conf" >&2
    return 1
  fi

  local line name cmd
  while IFS='|' read -r name cmd; do
    [[ "$name" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$name" ]] && continue
    name="${name## }"; name="${name%% }"
    cmd="${cmd## }"; cmd="${cmd%% }"
    HARNESS_COMMANDS[$name]="$cmd"
    ALLOWED_HARNESSES+=("$name")
  done < "$conf"

  if [[ ${#ALLOWED_HARNESSES[@]} -eq 0 ]]; then
    echo "Error: no harnesses defined in $conf" >&2
    return 1
  fi
}

# Get the launch command for a harness name.
# $PORT must be set in the calling scope for expansion.
get_harness_command() {
  local name="$1"
  local cmd_template="${HARNESS_COMMANDS[$name]}"

  if [[ -z "$cmd_template" ]]; then
    print_error "No command mapping for harness: $name"
    return 1
  fi

  # Expand $PORT in the template via string replacement
  echo "${cmd_template//\$PORT/$PORT}"
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

print_error() {
  echo "Error: $1" >&2
}

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

validate_harnesses() {
  local -a harnesses=("$@")
  local -a seen=()
  local allowed_str="${ALLOWED_HARNESSES[*]}"

  if [[ ${#harnesses[@]} -lt 1 || ${#harnesses[@]} -gt 3 ]]; then
    print_error "Must specify 1–3 harnesses, got ${#harnesses[@]}. Allowed: $allowed_str"
    return 1
  fi

  for h in "${harnesses[@]}"; do
    if [[ " ${seen[@]} " == *" $h "* ]]; then
      print_error "Duplicate harness: $h. Each harness can only appear once."
      return 1
    fi
    seen+=("$h")

    local found=0
    for a in "${ALLOWED_HARNESSES[@]}"; do
      if [[ "$a" == "$h" ]]; then
        found=1
        break
      fi
    done

    if [[ $found -eq 0 ]]; then
      print_error "Unknown harness: '$h'. Allowed: $allowed_str"
      return 1
    fi
  done

  for h in "${harnesses[@]}"; do
    echo "$h"
  done
}

# ---------------------------------------------------------------------------
# Config file reader
# ---------------------------------------------------------------------------

# Read harness list from .ai-harnesses.json in the current directory.
read_harness_config() {
  local config_file=".ai-harnesses.json"
  if [[ ! -f "$config_file" ]]; then
    print_error "Config file '$config_file' not found."
    return 1
  fi

  local -a harnesses
  local json_content
  json_content=$(cat "$config_file")

  if ! echo "$json_content" | jq -e 'type == "array"' &>/dev/null; then
    print_error "Config file must contain a JSON array."
    return 1
  fi

  local count
  count=$(echo "$json_content" | jq 'length')
  if [[ $count -lt 1 || $count -gt 3 ]]; then
    print_error "Config must specify 1–3 harnesses, got $count."
    return 1
  fi

  local i
  for ((i=0; i<count; i++)); do
    local h=$(echo "$json_content" | jq -r ".[$i]")
    if [[ "$h" == "null" ]]; then
      print_error "Config array element $i is not a string."
      return 1
    fi
    harnesses+=("$h")
  done

  validate_harnesses "${harnesses[@]}"
}

# ---------------------------------------------------------------------------
# Interactive prompt
# ---------------------------------------------------------------------------

# Interactively select harnesses via gum TUI.
interactive_harness_prompt() {
  if ! command -v gum &>/dev/null; then
    print_error "Interactive mode requires 'gum'. Install it via nix: nix-shell -p gum"
    return 1
  fi

  local count=$(gum choose --header "How many AI harnesses?" --selected "2" "1" "2" "3")
  local -a selected=()

  for ((i=1; i<=count; i++)); do
    local label=""
    case "$count" in
      1) label="Select harness:" ;;
      2)
        case "$i" in
          1) label="Left pane:" ;;
          2) label="Right pane:" ;;
        esac
        ;;
      3)
        case "$i" in
          1) label="Main (left) pane:" ;;
          2) label="Top-right pane:" ;;
          3) label="Bottom-right pane:" ;;
        esac
        ;;
    esac

    local -a choices=()
    for a in "${ALLOWED_HARNESSES[@]}"; do
      local disabled=0
      for s in "${selected[@]}"; do
        [[ "$a" == "$s" ]] && { disabled=1; break; }
      done
      [[ $disabled -eq 0 ]] && choices+=("$a")
    done

    local default="${choices[1]}"
    local choice=$(printf '%s\n' "${choices[@]}" | gum choose --header "$label" --selected "$default")
    selected+=("$choice")
  done

  validate_harnesses "${selected[@]}"
}

# ---------------------------------------------------------------------------
# Main resolver
# ---------------------------------------------------------------------------

# Resolve AI harnesses: CLI args → .ai-harnesses.json → interactive prompt.
# Outputs space-separated harness names.
resolve_harnesses() {
  local -a args=("$@")
  local -a harnesses=()
  local -a filtered=()

  if [[ ${#args[@]} -gt 0 ]]; then
    harnesses=("${(@f)$(validate_harnesses "${args[@]}")}")
  elif [[ -f ".ai-harnesses.json" ]]; then
    harnesses=("${(@f)$(read_harness_config)}")
  else
    harnesses=("${(@f)$(interactive_harness_prompt)}")
  fi

  # Drop empty lines so pane indexes map 1:1 to harnesses
  local h
  for h in "${harnesses[@]}"; do
    [[ -n "$h" ]] && filtered+=("$h")
  done

  if [[ ${#filtered[@]} -lt 1 || ${#filtered[@]} -gt 3 ]]; then
    echo "Error: Expected 1-3 AI harnesses, got ${#filtered[@]}." >&2
    return 1
  fi

  echo "${filtered[@]}"
}
