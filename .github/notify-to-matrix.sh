#!/bin/bash
# SPDX-FileCopyrightText: 2023-2024 Jankari Tech Pvt. Ltd.
# SPDX-License-Identifier: AGPL-3.0-or-later

set -euo pipefail  # Exit on error, undefined variables, and pipe failures

# Configuration
ELEMENT_ROOM_ID=wNGZBbAPrhCiGXtQYp:openproject.org

# Helper functions
log_error() {
  echo -e "\e[31m[ERROR] $1\e[0m" >&2
}

log_info() {
  echo -e "\e[37m[INFO] $1\e[0m"
}

log_success() {
  echo -e "\e[32m[SUCCESS] $1\e[0m"
}

# Validate required environment variables
validate_environment() {
  local required_vars=("GITHUB_TOKEN" "ELEMENT_CHAT_URL" "NIGHTLY_CI_USER_TOKEN" "REPO_NAMES")
  local missing_vars=()
  
  for var in "${required_vars[@]}"; do
    if [[ -z "${!var:-}" ]]; then
      missing_vars+=("$var")
    fi
  done
  
  if [[ ${#missing_vars[@]} -gt 0 ]]; then
    log_error "Missing required environment variables: ${missing_vars[*]}"
    exit 1
  fi
}

is_latest_release_tag() {
  log_info "Checking for new $REPO_NAME release..."
  
  # Set repository owner based on repo name
  if [[ $REPO_NAME = "oidc" ]]; then
    REPO_OWNER=H2CK
  else
    REPO_OWNER=nextcloud
  fi
  
  # Use yesterday's date for checking releases
  yesterday_date=$(date -d "yesterday" +%F)
  log_info "Looking for releases created on: $yesterday_date"

  # Create temporary file with better naming
  temp_file="/tmp/releases_${REPO_NAME}_$(date +%s).json"
  
  # Fetch releases from GitHub API
  releases_api_status_code=$(curl -s -w "%{http_code}" \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases" \
    -o "$temp_file")

  # Check if API call was successful
  if [[ "$releases_api_status_code" -ne 200 ]]; then
    log_error "❌ Failed to get \"$REPO_NAME\" release info with status code $releases_api_status_code"
    if [[ -f "$temp_file" ]]; then
      log_error "$(cat "$temp_file")"
      rm -f "$temp_file"
    fi
    exit 1
  fi

  # Parse releases created yesterday
  latest_release_tags=$(jq -r --arg date "$yesterday_date" '.[] 
    | select(.created_at | startswith($date)) 
    | .tag_name' "$temp_file")

  # Clean up temporary file
  rm -f "$temp_file"

  # Check if any releases were found
  if [[ -z "$latest_release_tags" || "$latest_release_tags" == "null" ]]; then
      log_info "No new \"$REPO_NAME\" release found for date $yesterday_date."
      return 1 # false
  fi

  # Count how many versions are in the release list
  version_count=$(echo "$latest_release_tags" | grep -c '^[^[:space:]]*$')
  multiple_prefix=""

  if [[ $version_count -gt 1 ]]; then
      log_info "Multiple $REPO_NAME releases found: $version_count versions."
      # Join multiple releases into a single line, separated by comma + space
      latest_release_tags=$(echo "$latest_release_tags" | paste -sd', ')
      multiple_prefix="Multiple "
  fi

  log_info "On date $yesterday_date, found new release tag(s): $latest_release_tags"
  
  # Export variables for use in send_message_to_room function
  export latest_release_tags
  export multiple_prefix
  
  return 0 # true
}

send_message_to_room() {
  local message_body="🔔 ${multiple_prefix}${REPO_NAME} Release Alert! : ${latest_release_tags}"
  
  log_info "Sending message to Element room..."
  
  # Prepare JSON payload with proper escaping
  local json_payload
  json_payload=$(jq -n \
    --arg msgtype "m.text" \
    --arg body "" \
    --arg format "org.matrix.custom.html" \
    --arg formatted_body "<h3>$message_body</h3>" \
    '{
      msgtype: $msgtype,
      body: $body,
      format: $format,
      formatted_body: $formatted_body
    }')

  # Send message to Element room
  local response_code
  response_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "$ELEMENT_CHAT_URL/_matrix/client/r0/rooms/%21$ELEMENT_ROOM_ID/send/m.room.message?access_token=$NIGHTLY_CI_USER_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$json_payload")

  # Check if the message was sent successfully
  if [[ ${response_code} == 200 ]]; then
      log_success "✅ Message sent successfully to Element room!"
  else
      log_error "❌ Failed to send message to Element room."
      log_error "Response code: $response_code"
      exit 1
  fi
}

# Main execution
main() {
  validate_environment
  
  log_info "Starting release notification check for repositories: $REPO_NAMES"
  
  for REPO_NAME in $REPO_NAMES; do
    log_info "Processing repository: $REPO_NAME"
    
    if is_latest_release_tag; then
      send_message_to_room
    fi
    
    log_info "$(printf '%.0s-' {1..60})"
  done
  
  log_success "Release notification check completed!"
}

# Run main function
main "$@"
