#!/usr/bin/env bash
# Runs check.sh and mirrors the result into this repo's `outage` issues (GitHub emails the owner on each one).
# Used by the Mac launchd agent com.a1.seagram-monitor while GitHub Actions is unavailable on this account.
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
cd "$(dirname "$0")" || exit 1
git pull -q --ff-only 2>/dev/null
REPO=idimetrix/seagram-monitor
out=$(./check.sh 2>&1); rc=$?
echo "$(date -u +%FT%TZ) rc=$rc $(echo "$out" | tr '\n' ' ')"
open=$(gh issue list -R $REPO --label outage --state open --json number -q '.[0].number')
if [ $rc != 0 ]; then
  # the issue body is the full failure list; repeat runs only comment when the list changes
  if [ -z "$open" ]; then gh issue create -R $REPO --title "Seagram health check failing" --label outage --body "$out" >/dev/null
  elif [ "$(gh issue view "$open" -R $REPO --json comments,body -q '(.comments[-1].body // .body)')" != "$out" ]; then gh issue comment "$open" -R $REPO --body "$out" >/dev/null; fi
elif [ -n "$open" ]; then gh issue close "$open" -R $REPO -c "Recovered, all checks pass." >/dev/null; fi
