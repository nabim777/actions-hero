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

log_info "Fetching latest Nextcloud release tag....."


# ELEMENT_CHAT_URL=https://matrix.openproject.org
# ELEMENT_ROOM_ID=wNGZBbAPrhCiGXtQYp:openproject.org
# REPO_OWNER= nextcloud
# RUN_ID=123456789
# LATEST_SUPPORTED_NC_VERSION=31


nextcloud_latest_release_tag=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
"https://api.github.com/repos/nextcloud/server/releases" | jq -r '.[] | select(.prerelease == false) | .tag_name' | head -n 1)


major_version=$(echo "$nextcloud_latest_release_tag" | sed -E 's/^v([0-9]+)\..*/\1/')

log_info "Latest release tag: $major_version"


if [[ "$major_version" -gt "$LATEST_SUPPORTED_NC_VERSION" ]]; then
    log_info "New Nextcloud release detected: $nextcloud_latest_release_tag"
    send_message_to_room_response=$(curl -s -XPOST "$ELEMENT_CHAT_URL/_matrix/client/r0/rooms/%21$ELEMENT_ROOM_ID/send/m.room.message?access_token=$NIGHTLY_CI_USER_TOKEN" \
                                    -d '
                                        {
                                        "msgtype": "m.text",
                                        "body": "",
                                        "format": "org.matrix.custom.html",
                                        "formatted_body": "<h3>🔔 New Nextcloud '$major_version' Release Alert!</h3><br><Run id = '$RUN_ID'>"
                                        }
                                    '
                                    )
else
    log_info "No new Nextcloud release. Latest stable version is still: $LATEST_SUPPORTED_NC_VERSION"
    exit 0
fi