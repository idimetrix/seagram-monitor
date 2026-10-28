# seagram-monitor

Scheduled health check for seagram.do and its alias domains: site, redirects, Zoho MX, MTA-STS, TLS and domain expiry. A failure opens an `outage` issue; recovery closes it. Run `./check.sh` locally for the same report. While GitHub Actions is unavailable on this account, `monitor.sh` runs every 30 min from a launchd agent (`~/Library/LaunchAgents/com.a1.seagram-monitor.plist`, log `~/Library/Logs/seagram-monitor.log`).
