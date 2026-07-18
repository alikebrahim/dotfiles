#!/usr/bin/env bash
# Switch AwesomeWM to workspace N (synced across all screens)
echo "local s=screen.primary;s.tags[${1}]:view_only()" | awesome-client
