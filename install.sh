#!/usr/bin/env bash
set -euo pipefail

# ── Color support ──────────────────────────────────────────────────────────────
if [ -t 1 ] && command -v tput &>/dev/null && tput colors &>/dev/null 2>&1 \
   && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
  RED=$(tput setaf 1); GREEN=$(tput setaf 2); YELLOW=$(tput setaf 3)
  BLUE=$(tput setaf 4); CYAN=$(tput setaf 6); BOLD=$(tput bold); RESET=$(tput sgr0)
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; BOLD=''; RESET=''
fi

info()    { printf "%s%s%s\n" "$CYAN"   "$*" "$RESET"; }
success() { printf "%s✓ %s%s\n" "$GREEN"  "$*" "$RESET"; }
warn()    { printf "%s⚠  %s%s\n" "$YELLOW" "$*" "$RESET"; }
err()     { printf "%s✗ %s%s\n" "$RED"   "$*" "$RESET" >&2; exit 1; }
step()    { printf "\n%s%s── %s%s\n" "$BOLD" "$BLUE" "$*" "$RESET"; }
ask()     { printf "%s%s%s " "$BOLD" "$*" "$RESET"; }

generate_secret() {
  if command -v openssl &>/dev/null; then
    openssl rand -hex 32
  else
    LC_ALL=C tr -dc 'a-f0-9' </dev/urandom 2>/dev/null | head -c 64
  fi
}

trap 'printf "\n%sInterrupted. Exiting.%s\n" "$YELLOW" "$RESET"; exit 1' INT TERM

# ── Prerequisites ──────────────────────────────────────────────────────────────
check_prereqs() {
  step "Checking prerequisites"
  local ok=1
  for cmd in docker curl; do
    if command -v "$cmd" &>/dev/null; then success "$cmd found"
    else warn "$cmd not found"; ok=0; fi
  done
  if docker compose version &>/dev/null 2>&1; then success "docker compose (v2) found"
  else warn "docker compose v2 not found"; ok=0; fi
  [ $ok -eq 0 ] && err "Install missing prerequisites and re-run."
}

# ── Step 1: Basic config ───────────────────────────────────────────────────────
configure_basic() {
  step "Step 1/7: Basic Configuration"

  ask "Domain or IP address [localhost]:"
  read -r OIKOS_HOST; OIKOS_HOST="${OIKOS_HOST:-localhost}"

  ask "Port [3000]:"
  read -r OIKOS_PORT; OIKOS_PORT="${OIKOS_PORT:-3000}"

  local sys_tz="UTC"
  if [ -f /etc/timezone ]; then
    sys_tz=$(cat /etc/timezone)
  elif command -v timedatectl &>/dev/null; then
    sys_tz=$(timedatectl show --property=Timezone --value 2>/dev/null || echo "UTC")
  elif [ -L /etc/localtime ]; then
    sys_tz=$(readlink /etc/localtime 2>/dev/null | sed 's|.*zoneinfo/||' || echo "UTC")
  fi

  ask "Timezone [$sys_tz]:"
  read -r OIKOS_TZ; OIKOS_TZ="${OIKOS_TZ:-$sys_tz}"
}

# ── Step 2: Secrets ────────────────────────────────────────────────────────────
configure_secrets() {
  step "Step 2/7: Security Keys"
  info "Auto-generation is recommended. Store the resulting .env file safely.\n"

  for varname in SESSION_SECRET DB_ENCRYPTION_KEY; do
    printf "\n  %s%s:%s\n" "$BOLD" "$varname" "$RESET"
    ask "  [G]enerate automatically / [M]anual entry [G]:"
    read -r choice
    if [ "${choice,,}" = "m" ]; then
      ask "  Enter value:"
      local val; read -rs val; printf "\n"
      eval "$varname='$val'"
    else
      local generated; generated=$(generate_secret)
      eval "$varname='$generated'"
      success "  Generated"
    fi
  done
}

# ── Step 3: Weather ────────────────────────────────────────────────────────────
configure_weather() {
  step "Step 3/7: Weather Widget (optional)"
  OPENWEATHER_API_KEY=''; OPENWEATHER_CITY='Berlin'
  OPENWEATHER_UNITS='metric'; OPENWEATHER_LANG='de'

  ask "Enable weather widget? [y/N]:"
  read -r want_weather
  if [ "${want_weather,,}" = "y" ]; then
    info "  Get a free API key at: https://openweathermap.org/api"
    ask "  API key:"; read -r OPENWEATHER_API_KEY
    ask "  City [Berlin]:"; read -r city; OPENWEATHER_CITY="${city:-Berlin}"
    ask "  Units (metric/imperial) [metric]:"; read -r units; OPENWEATHER_UNITS="${units:-metric}"
  fi
}

# ── Step 4: Calendar ───────────────────────────────────────────────────────────
configure_calendar() {
  step "Step 4/7: Calendar Sync (optional)"
  GOOGLE_CLIENT_ID=''; GOOGLE_CLIENT_SECRET=''; GOOGLE_REDIRECT_URI=''
  APPLE_USERNAME=''; APPLE_APP_SPECIFIC_PASSWORD=''

  ask "Enable Google Calendar sync? [y/N]:"
  read -r want_google
  if [ "${want_google,,}" = "y" ]; then
    info "  Create OAuth credentials at: https://console.cloud.google.com"
    info "  Redirect URI: http://${OIKOS_HOST}:${OIKOS_PORT}/api/v1/calendar/google/callback"
    ask "  Client ID:"; read -r GOOGLE_CLIENT_ID
    ask "  Client Secret:"; read -rs GOOGLE_CLIENT_SECRET; printf "\n"
    GOOGLE_REDIRECT_URI="http://${OIKOS_HOST}:${OIKOS_PORT}/api/v1/calendar/google/callback"
  fi

  ask "Enable Apple/iCloud CalDAV sync? [y/N]:"
  read -r want_apple
  if [ "${want_apple,,}" = "y" ]; then
    info "  Create an app-specific password at: https://appleid.apple.com"
    ask "  Apple ID (email):"; read -r APPLE_USERNAME
    ask "  App-specific password:"; read -rs APPLE_APP_SPECIFIC_PASSWORD; printf "\n"
  fi
}

# ── Step 5: Review ─────────────────────────────────────────────────────────────
review_and_confirm() {
  step "Step 5/7: Review"
  printf "\n"
  printf "  Host           %s%s%s\n"  "$CYAN"   "$OIKOS_HOST"  "$RESET"
  printf "  Port           %s%s%s\n"  "$CYAN"   "$OIKOS_PORT"  "$RESET"
  printf "  Timezone       %s%s%s\n"  "$CYAN"   "$OIKOS_TZ"    "$RESET"
  printf "  SESSION_SECRET %s***%s\n" "$YELLOW" "$RESET"
  printf "  DB_ENCRYPT_KEY %s***%s\n" "$YELLOW" "$RESET"
  [ -n "$OPENWEATHER_API_KEY" ] && printf "  Weather        %s%s (key set)%s\n" "$GREEN" "$OPENWEATHER_CITY" "$RESET"
  [ -n "$GOOGLE_CLIENT_ID" ]   && printf "  Google Cal     %senabled%s\n"        "$GREEN" "$RESET"
  [ -n "$APPLE_USERNAME" ]     && printf "  Apple CalDAV   %s%s%s\n"             "$GREEN" "$APPLE_USERNAME" "$RESET"
  printf "\n"
  ask "Proceed? [Y/n]:"
  read -r confirm
  [ "${confirm,,}" = "n" ] && { info "Aborted."; exit 0; }
}

# ── Step 6: Docker ─────────────────────────────────────────────────────────────
write_env_and_start() {
  step "Step 6/7: Starting Docker Container"

  cat > .env << ENVEOF
# Generated by Oikos installer
SESSION_SECRET=${SESSION_SECRET}
DB_ENCRYPTION_KEY=${DB_ENCRYPTION_KEY}
OPENWEATHER_API_KEY=${OPENWEATHER_API_KEY}
OPENWEATHER_CITY=${OPENWEATHER_CITY}
OPENWEATHER_UNITS=${OPENWEATHER_UNITS}
OPENWEATHER_LANG=${OPENWEATHER_LANG}
GOOGLE_CLIENT_ID=${GOOGLE_CLIENT_ID}
GOOGLE_CLIENT_SECRET=${GOOGLE_CLIENT_SECRET}
GOOGLE_REDIRECT_URI=${GOOGLE_REDIRECT_URI}
APPLE_USERNAME=${APPLE_USERNAME}
APPLE_APP_SPECIFIC_PASSWORD=${APPLE_APP_SPECIFIC_PASSWORD}
SYNC_INTERVAL_MINUTES=15
TZ=${OIKOS_TZ}
OIKOS_HTTP_PORT=${OIKOS_PORT}
ENVEOF

  success ".env written"

  if ! docker compose up -d; then
    warn "Docker failed to start. Recent logs:"
    docker compose logs --tail 50
    exit 1
  fi

  printf "  Waiting for container to be ready"
  local elapsed=0
  while [ $elapsed -lt 120 ]; do
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" \
      "http://localhost:${OIKOS_PORT}/health" 2>/dev/null || echo "000")
    if [ "$http_code" = "200" ]; then
      printf "\n"; success "Container is healthy"; return 0
    fi
    printf "."; sleep 2; elapsed=$((elapsed + 2))
  done

  printf "\n"
  warn "Timeout waiting for container. Logs:"
  docker compose logs --tail 50
  exit 1
}

# ── Step 7: Admin account ──────────────────────────────────────────────────────
create_admin() {
  step "Step 7/7: Create Admin Account"

  ask "Username (3-64 chars, letters/numbers/._-):"
  read -r admin_user

  ask "Display name (e.g. 'Jane Smith'):"
  read -r admin_display

  local admin_pass
  while true; do
    ask "Password (min 8 chars):"; read -rs admin_pass; printf "\n"
    ask "Confirm password:"; local admin_confirm; read -rs admin_confirm; printf "\n"
    [ "$admin_pass" = "$admin_confirm" ] && break
    warn "Passwords do not match, try again."
  done

  # Build JSON payload (values must not contain " or \)
  local payload
  payload=$(printf '{"username":"%s","display_name":"%s","password":"%s"}' \
    "$admin_user" "$admin_display" "$admin_pass")

  local response http_code body
  response=$(curl -s -w "\n%{http_code}" \
    -X POST "http://localhost:${OIKOS_PORT}/api/v1/auth/setup" \
    -H "Content-Type: application/json" \
    -d "$payload")
  http_code=$(printf '%s' "$response" | tail -n1)
  body=$(printf '%s' "$response" | head -n-1)

  if [ "$http_code" = "201" ]; then
    success "Admin account created!"
    printf "\n%s%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n" "$BOLD" "$GREEN" "$RESET"
    printf "%s%s  Oikos is ready!%s\n"                   "$BOLD" "$GREEN" "$RESET"
    printf "%s%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n\n" "$BOLD" "$GREEN" "$RESET"
    printf "  Open: %shttp://%s:%s%s\n\n" "$CYAN" "$OIKOS_HOST" "$OIKOS_PORT" "$RESET"
  elif [ "$http_code" = "403" ]; then
    warn "An admin account already exists."
    printf "  Open: %shttp://%s:%s%s\n\n" "$CYAN" "$OIKOS_HOST" "$OIKOS_PORT" "$RESET"
  else
    warn "Failed to create admin (HTTP $http_code): $body"
    printf "  Create manually:\n"
    printf "  curl -X POST http://localhost:%s/api/v1/auth/setup \\\n" "$OIKOS_PORT"
    printf "    -H 'Content-Type: application/json' \\\n"
    printf "    -d '{\"username\":\"admin\",\"display_name\":\"Admin\",\"password\":\"yourpassword\"}'\n\n"
  fi
}

# ── Non-interactive mode (--env-file) ──────────────────────────────────────────
run_noninteractive() {
  local env_file="$1"
  [ -f "$env_file" ] || err "Env file not found: $env_file"
  info "Non-interactive mode: using $env_file"
  cp "$env_file" .env

  OIKOS_PORT=$(grep -E '^PORT=' .env 2>/dev/null | cut -d= -f2- | head -n1)
  OIKOS_PORT="${OIKOS_PORT:-3000}"
  OIKOS_HOST="localhost"

  if ! docker compose up -d; then docker compose logs --tail 50; exit 1; fi

  printf "  Waiting for container"
  local elapsed=0
  while [ $elapsed -lt 120 ]; do
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" \
      "http://localhost:${OIKOS_PORT}/health" 2>/dev/null || echo "000")
    [ "$http_code" = "200" ] && { printf "\n"; success "Ready"; break; }
    printf "."; sleep 2; elapsed=$((elapsed + 2))
  done

  printf "\n%sContainer started.%s Create admin:\n\n" "$GREEN" "$RESET"
  printf "  curl -X POST http://localhost:%s/api/v1/auth/setup \\\n" "$OIKOS_PORT"
  printf "    -H 'Content-Type: application/json' \\\n"
  printf "    -d '{\"username\":\"admin\",\"display_name\":\"Admin\",\"password\":\"yourpassword\"}'\n\n"
}

# ── Main ───────────────────────────────────────────────────────────────────────
main() {
  printf "\n%s%s  ╔══════════════════════════════╗\n" "$BOLD" "$BLUE"
  printf "  ║      Oikos  Installer        ║\n"
  printf "  ╚══════════════════════════════╝%s\n\n" "$RESET"

  if [ "${1:-}" = "--env-file" ]; then
    [ -n "${2:-}" ] || err "Usage: $0 --env-file /path/to/.env"
    run_noninteractive "$2"; exit 0
  fi

  check_prereqs
  configure_basic
  configure_secrets
  configure_weather
  configure_calendar
  review_and_confirm
  write_env_and_start
  create_admin
}

main "$@"
