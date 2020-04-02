#!/bin/bash

# This script generates and submit issues to FINOS GitHub repositories,
# reading the output of generate-repo-validation.sh
# 
# First, it runs an org-wide search for all open issues that match 
# the title ISSUE_TITLE.
# 
# For all repositories with quality checks to report, which don't have an 
# existing open issue, the script will generate and submit one.

if [ -z $ISSUE_TITLE ]; then
  ISSUE_TITLE="[FINOS_PROJECT_BLUEPRINT] - Fixes to apply"
fi
export ISSUE_TITLE=$ISSUE_TITLE

# TODO - remove this when the feature is completely rolled out
enabled_repos="
  contrib-toolbox,open-developer-platform,metadata-tool,bot-github-chatops,SymphonyElectron,electron-builder,electron-utils,electron-spellchecker,node-ffi,ScreenSnippet,ScreenSnippet2,SwiftSearch,electron-dl,ScreenShareIndicatorFrame,node-auto-launch"

# TODO - add Symphony Eletron repos


# Generate list of repos that already have an issue created with $ISSUE_TITLE
rm -rf /tmp/existing-issues.txt
curl -s -G "https://api.github.com/search/issues" --data-urlencode "q='$ISSUE_TITLE' in:title org:finos state:open"  -H "Accept: application/vnd.github.preview" | jq '.items[] | (.repository_url/"/" | (.[-2] + "/" + .[-1]))' | tr -d '"' | sort | uniq > /tmp/existing-issues.txt

# Each validation item is parsed and, unless there's already an open issue with the same title, it will create a new one, using the "message" field as issue text.
cat metadata-tool/finos-repo-validation.json | jq -r '.[]| [.org, .["repo-name"]] | @tsv' |
  while IFS=$'\t' read -r ORG REPO; do
    if [ -n "$ORG" ] && [ -n "$REPO" ]; then
      if echo "$enabled_repos" | grep -q ",$REPO,"
      then
        export ORG=$ORG
        export REPO=$REPO
        ISSUE_EXIST=`cat /tmp/existing-issues.txt | grep "$ORG/$REPO"`
        if [ -z "$ISSUE_EXIST" ]; then
            PAYLOAD=`cat finos-repo-validation.json | jq -r '.[] | select(.org == env.ORG and .["repo-name"] == env.REPO) | { "title": env.ISSUE_TITLE, "body": .message, "labels":["quality checks"] }'`
            echo "Creating issue for repo $ORG/$REPO"
            curl -v -u admin:$GITHUB_TOKEN -d "$PAYLOAD" https://api.github.com/repos/$ORG/$REPO/issues
        fi
      else
        echo "Skipping $ORG/$REPO as it's not an enabled repo"
      fi
    fi
  done
