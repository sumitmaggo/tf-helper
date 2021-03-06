#!/bin/sh

## -------------------------------------------------------------------
##
## Copyright (c) 2018 HashiCorp. All Rights Reserved.
##
## This file is provided to you under the Mozilla Public License
## Version 2.0 (the "License"); you may not use this file
## except in compliance with the License.  You may obtain
## a copy of the License at
##
##   https://www.mozilla.org/en-US/MPL/2.0/
##
## Unless required by applicable law or agreed to in writing,
## software distributed under the License is distributed on an
## "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
## KIND, either express or implied.  See the License for the
## specific language governing permissions and limitations
## under the License.
##
## -------------------------------------------------------------------

##
## Helper functions
##

make_new_ssh_payload () {

# $1 attribute contents

cat > "$payload" <<EOF
{
"data" : {
  "attributes": {
    $1
  },
  "type": "ssh-keys"
}
}
EOF

echodebug "Payload contents:"
cat "$payload" 1>&3
}

tfh_ssh_update () (
  ssh_name="$1"
  ssh_id="$2"
  ssh_new_name="$3"
  ssh_file="$4"

  if [ -z $ssh_name$ssh_id$ssh_new_name$ssh_file ]; then
    exec $0 ssh update help
    return 1
  fi

  payload="$TMPDIR/tfe-new-payload-$(junonia_randomish_int)"
  attr_obj=

  if [ -n "$ssh_new_name" ]; then
    [ "$attr_obj" ] && attr_obj="$attr_obj,"
    attr_obj="$attr_obj \"name\": \"$ssh_new_name\""
  elif [ -n "$ssh_file" ]; then
    if [ ! -f "$ssh_file" ]; then
      echoerr "File not found: $ssh_file"
      return 1
    else
      ssh_key="$(escape_value "$(cat "$ssh_file")")"
      [ "$attr_obj" ] && attr_obj="$attr_obj,"
      attr_obj="$attr_obj \"value\": \"$ssh_key\""
    fi
  else
    echoerr "One of -ssh-new-name or -ssh-file is required"
    return 1
  fi

  # Ensure all of org, etc, are set. Workspace is not required.
  if ! check_required org token address; then
    return 1
  fi

  if [ -z "$ssh_name" ] && [ -z "$ssh_id" ]; then
    echoerr "One of -ssh-name or -ssh-id is required"
    return 1
  fi

  if [ -n "$ssh_name" ] && [ -n "$ssh_id" ]; then
    echoerr "Only one of -ssh-name or -ssh-id should be specified"
    return 1
  fi

  if [ -n "$ssh_name" ]; then
    # Use the show command to check for and retrieve the ID of the key
    # in the case of being passed a name.
    . "$JUNONIA_PATH/lib/tfh/cmd/tfh_ssh_show.sh"

    # Pass the command line arguments to show and get back a key (or error)
    if ! ssh_show="$(tfh_ssh_show "$ssh_name")"; then
      # The show command will have printed error messages.
      return 1
    fi

    # Really, if it's empty then tfh_ssh_show should have exited non-zero
    if [ -z "$ssh_show" ]; then
      echoerr "SSH key not found"
      return 1
    fi

    ssh_id="$(echo "$ssh_show" | cut -d ' ' -f 2)"
  else
    # To simplify error reporting later, we'll print ssh_show, but if
    # we were given an ID set ssh_show to the ID as it will be empty.
    ssh_show="$ssh_id"
  fi

  # This shouldn't happen...
  if [ -z "$ssh_id" ]; then
    echoerr "SSH key not found"
    return 1
  fi

  if ! make_new_ssh_payload "$attr_obj"; then
    echoerr "Error generating payload file for SSH key update"
    return 1
  fi

  echodebug "API request for update SSH key:"
  url="$address/api/v2/ssh-keys/$ssh_id"
  if ! update_resp="$(tfh_api_call --request PATCH -d @"$payload" "$url")"; then
    echoerr "Error updating SSH key $ssh_show"
    return 1
  fi

  cleanup "$payload"

  echo "Updated SSH key $ssh_name"
)
