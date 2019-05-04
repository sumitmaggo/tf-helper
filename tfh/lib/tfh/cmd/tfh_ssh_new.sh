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

# $1 new ssh key name
# $2 new ssh key

cat > "$payload" <<EOF
{
  "data": {
    "type": "ssh-keys",
    "attributes": {
      "name": "$1",
      "value": "$2"
    }
  }
}
EOF

echodebug "[DEBUG] Payload contents:"
cat "$payload" 1>&3
}

tfh_ssh_new () (
    payload="$TMPDIR/tfe-new-payload-$(random_enough)"
    ssh_name=
    ssh_key=

    # Ensure all of org, etc, are set. Workspace is not required.
    if ! check_required org tfh_token address; then
        return 1
    fi

    # Parse options

    while [ -n "$1" ]; do
        # If this is a common option it has already been parsed. Skip it and
        # its value.
        if is_common_opt "$1"; then
            shift
            shift
            continue
        fi

        case "$1" in
            -ssh-name)
                ssh_name="$(assign_arg "$1" "$2")"
                ;;
            -ssh-file)
                ssh_file="$(assign_arg "$1" "$2")"
                ;;
            *)
                echoerr "Unknown option: $1"
                return 1
                ;;
        esac

        # Shift the parameter and argument
        [ -n "$1" ] && shift
        [ -n "$1" ] && shift
    done

    if [ ! -f "$ssh_file" ]; then
        echoerr "File not found: $ssh_file"
        return 1
    else
        ssh_key="$(escape_value "$(cat "$ssh_file")")"
    fi

    if ! make_new_ssh_payload "$ssh_name" "$ssh_key"; then
        echoerr "Error generating payload file for SSH key creation"
        return 1
    fi

    echodebug "[DEBUG] API request for new SSH key:"
    url="$address/api/v2/organizations/$org/ssh-keys"
    if ! new_resp="$(tfh_api_call -d @"$payload" "$url")"; then
        echoerr "Error creating SSH key $ssh_name"
        return 1
    fi

    cleanup "$payload"

    echo "Created new SSH key $ssh_name"
)