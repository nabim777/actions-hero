log_info "Sending report to the element chat...."

send_message_to_room_response=$(curl -s -XPOST "$ELEMENT_CHAT_URL/_matrix/client/r0/rooms/%21$ELEMENT_ROOM_ID/send/m.room.message?access_token=$NIGHTLY_CI_USER_TOKEN" \
                                      -d '
                                          {
                                            "msgtype": "m.text",
                                            "body": "",
                                            "format": "org.matrix.custom.html",
                                            "formatted_body": "Hi I am the Nalem 7 hahahahahaha"
                                          }
                                        '
                                      )
