# lib/detect-serve.sh — Dev server command detection
# Sourced by main.sh. No external dependencies beyond jq (for Node projects).

# Detect the appropriate dev server command for the current project.
# Prints the command string if found, or nothing if no match.
# Priority: justfile → package.json → Makefile
detect_serve_command() {
  if [[ -f "justfile" ]] && grep -q "^dev:" justfile 2>/dev/null; then
    echo "just dev"
  elif [[ -f "package.json" ]] && command -v jq &>/dev/null; then
    if jq -e '.scripts.dev' package.json &>/dev/null; then
      if [[ -f "pnpm-lock.yaml" ]]; then
        echo "pnpm dev"
      elif [[ -f "yarn.lock" ]]; then
          echo "yarn dev"
      else
        echo "npm run dev"
      fi
    fi
  elif [[ -f "Makefile" ]] && grep -q "^dev:" Makefile 2>/dev/null; then
    echo "make dev"
  fi
}
