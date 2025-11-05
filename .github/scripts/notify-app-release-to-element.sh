#!/bin/bash

# helper functions
log_error() {
  echo -e "\e[31m$1\e[0m"
}

log_info() {
  echo -e "\e[37m$1\e[0m"
}

log_success() {
  echo -e "\e[32m$1\e[0m"
}

update_repo_variable(){
    variable_name=$1
    
    if [[ -z "$variable_name" ]]; then
        log_error "update_repo_variable requires variable_name parameters"
        return 1
    fi

    new_value=$nextcloud_latest_release_tag;
    
    log_info "Updating variable '$variable_name' to value '$new_value'..."
    
    variable_update_response=$(curl -s -o /dev/null -w "%{http_code}" -X PATCH \
        -H "Authorization: token $TOKEN_GITHUB" \
        -H "Content-Type: application/json" \
        -d '{"value": "'"$new_value"'"}' \
        "https://api.github.com/repos/nabim777/actions-hero/actions/variables/$variable_name")

    # Check if the update was successful
    if [[ ${variable_update_response} == 204 ]]; then
      log_success "✅ Variable '$variable_name' updated successfully"
    else
      log_error "❌ Failed to update variable '$variable_name'"
      log_error "Response status code: $variable_update_response"
      exit 1
    fi
}

get_latest_release_tag(){
  repo_name=$1
  releases_json=$(curl -s -H "Authorization: token $TOKEN_GITHUB" "https://api.github.com/repos/nextcloud/$repo_name/releases")

  # extract the latest stable release tag by ignoring pre-releases
  nextcloud_latest_release_tag=$(echo "$releases_json" | jq -r '.[] | select(.prerelease == false) | .tag_name' | head -n 1)

  # Remove leading 'v' if present
  nextcloud_latest_release_tag=${nextcloud_latest_release_tag#v}

  # Check if the tag is empty or null
  if [[ -z "$nextcloud_latest_release_tag" || "$nextcloud_latest_release_tag" == "null" ]]; then
      log_error "Failed to fetch Nextcloud latest release tag. Tag is empty or null."
      exit 1
  fi
}


log_info "Fetching latest Nextcloud release tag....."


# ELEMENT_CHAT_URL=https://matrix.openproject.org
# ELEMENT_ROOM_ID=wNGZBbAPrhCiGXtQYp:openproject.org
# REPO_OWNER= nextcloud
# RUN_ID=123456789
# LATEST_SUPPORTED_NC_VERSION=31


# nextcloud_latest_release_tag=$(curl -s -H "Authorization: token $TOKEN_GITHUB" \
# "https://api.github.com/repos/nextcloud/server/releases" | jq -r '.[] | select(.prerelease == false) | .tag_name' | head -n 1)


get_latest_release_tag "server"



# major_version=$(echo "$nextcloud_latest_release_tag" | sed -E 's/^v([0-9]+)\..*/\1/')

# log_info "Latest release tag: $major_version"

if dpkg --compare-versions "$nextcloud_latest_release_tag" gt "$LATEST_SUPPORTED_NC_VERSION"; then
    log_info "New Nextcloud release detected: $nextcloud_latest_release_tag"
    send_message_to_room_response=$(curl -s -XPOST "$ELEMENT_CHAT_URL/_matrix/client/r0/rooms/%21$ELEMENT_ROOM_ID/send/m.room.message?access_token=$NIGHTLY_CI_USER_TOKEN" \
                                    -d '
                                        {
                                        "msgtype": "m.text",
                                        "body": "",
                                        "format": "org.matrix.custom.html",
                                        "formatted_body": "<h3>🔔 New Nextcloud '$nextcloud_latest_release_tag' Release Alert!</h3><br><Run id = '$RUN_ID'>"
                                        }
                                    '
                                    )
     # Check if the message was sent successfully
    if echo "$send_message_to_room_response" | grep -q '"event_id"'; then
        log_success "✅ Message sent successfully to Element room!"
        update_repo_variable "LATEST_SUPPORTED_NC_VERSION"
    else
        log_error "❌ Failed to send message to Element room."
        log_error "Response: $send_message_to_room_response"
        exit 1
    fi
else
    log_info "No new Nextcloud release. Latest stable version is still: $LATEST_SUPPORTED_NC_VERSION"
    exit 0
fi