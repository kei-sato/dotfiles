#!/bin/bash

#####################################################################
# FYI: get channel id
# curl -d token=xoxp-2595960153-2595960157-5109083225-433c35 -d sort=timestamp -d sort_dir=asc -d query=task -d count=5 https://slack.com/api/groups.list | jq .
#####################################################################

TMP_TS=/tmp/ts
TMP_RESULT=/tmp/result

SLACK_TOKEN=${SLACK_TOKEN:-xoxp-2595960153-2595960157-5109083225-433c35}
SLACK_CHANNEL=${SLACK_CHANNEL:-G02HJSPPN}

API_GROUP_HISTORY=https://slack.com/api/groups.history
API_DELETE=https://slack.com/api/chat.delete

die_with_help() {
  echo "usage: $0 --from <unix time> --to <unix time>"
  exit 1
}

if [ -z "$1" ]; then die_with_help; fi

while [[ $# > 1 ]]; do
  key="$1"
  case $key in
    --from)
      _FROM=$2
      shift
      ;;
    --to)
      _TO=$2
      shift
      ;;
    --count)
      _COUNT=$2
      shift
      ;;
  esac
  shift
done

_COUNT=${_COUNT:-100}
_FROM=${_FROM:-$(date -v -1H +%s)}
_TO=${_TO:-$(date +%s)}

# get web api
curl -d token=$SLACK_TOKEN -d channel=$SLACK_CHANNEL -d oldest=$_FROM -d latest=$_TO -d count=$_COUNT $API_GROUP_HISTORY > $TMP_RESULT
# get timestamps
cat $TMP_RESULT | jq .messages | grep ts | awk '{print $2}' | sed -e 's/"//g' > $TMP_TS
# delete each messages
while read line; do curl -d token=$SLACK_TOKEN -d channel=$SLACK_CHANNEL -d ts=$line $API_DELETE; done < $TMP_TS
