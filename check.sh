#!/usr/bin/env bash
# Seagram health check: site, redirects, mail routing, MTA-STS, TLS and domain expiry. Prints one line per failure.
set -u
MAIN=seagram.do
ALIASES="seagramindustrialcorporation.com seagramindustrial.com seagramindustriacorporation.com"
fail=0
bad(){ echo "FAIL: $*"; fail=1; }
# days from now until a date string (portable: GNU and BSD date differ)
days(){ python3 -c 'import sys,email.utils as e,datetime as d
v=sys.argv[1].strip()
try: t=d.datetime.fromisoformat(v.replace("Z","+00:00"))
except ValueError: t=e.parsedate_to_datetime(v.replace(" GMT"," +0000"))
print((t-d.datetime.now(d.timezone.utc)).days)' "$1" 2>/dev/null || echo -1; }

code=$(curl -s --doh-url https://1.1.1.1/dns-query -o /dev/null -m 20 -w '%{http_code}' https://$MAIN/es); [ "$code" = 200 ] || bad "https://$MAIN/es returned $code"

# Google rejects every sitemap URL on another host ("URL not allowed"): this happened once while NEXT_PUBLIC_SITE_URL
# was unset and the sitemap listed seagram-industrial.vercel.app
off=$(curl -s --doh-url https://1.1.1.1/dns-query -m 20 https://$MAIN/sitemap.xml | grep -oE '<loc>https?://[^/<]+' | grep -vc "<loc>https://$MAIN")
[ "$off" = 0 ] || bad "$off sitemap URLs are not on https://$MAIN"
curl -s --doh-url https://1.1.1.1/dns-query -m 20 https://$MAIN/es | grep -q "rel=\"canonical\" href=\"https://$MAIN/es\"" || bad "home canonical is not https://$MAIN/es"

# the admin panel lives on admin.seagram.do; the old vercel.app name must keep forwarding there
code=$(curl -s --doh-url https://1.1.1.1/dns-query -o /dev/null -m 20 -w '%{http_code}' https://admin.$MAIN/login); [ "$code" = 200 ] || bad "https://admin.$MAIN/login returned $code"
r=$(curl -s --doh-url https://1.1.1.1/dns-query -o /dev/null -m 20 -w '%{http_code} %{redirect_url}' https://admin-seagram-industrial.vercel.app/login)
[ "$r" = "308 https://admin.$MAIN/login" ] || bad "old admin host redirect is '$r'"

for d in $ALIASES; do for h in $d www.$d; do
  r=$(curl -s --doh-url https://1.1.1.1/dns-query -o /dev/null -m 20 -w '%{http_code} %{redirect_url}' "https://$h/x")
  [ "$r" = "308 https://$MAIN/x" ] || bad "$h redirect is '$r'"
done; done

for d in $MAIN $ALIASES; do
  dig +short MX $d @1.1.1.1 | grep -q 'mx.zoho.com' || bad "$d MX does not point to Zoho"
  curl -s --doh-url https://1.1.1.1/dns-query -m 20 https://mta-sts.$d/.well-known/mta-sts.txt | grep -q 'mode: enforce' || bad "$d MTA-STS policy not served"
done

end=$(echo | openssl s_client -connect $MAIN:443 -servername $MAIN 2>/dev/null | openssl x509 -noout -enddate | cut -d= -f2)
[ -n "$end" ] && [ $(days "$end") -gt 14 ] || bad "$MAIN TLS certificate expires soon ($end)"

for d in $ALIASES; do
  exp=$(curl -s --doh-url https://1.1.1.1/dns-query -m 20 https://rdap.verisign.com/com/v1/domain/$d | jq -r '.events[]|select(.eventAction=="expiration").eventDate')
  [ -n "$exp" ] && [ $(days "$exp") -gt 45 ] || bad "$d registration expires $exp, renew at GoDaddy"
done
# seagram.do has NO auto-renew at NIC.DO: payment is manual
exp=$(whois $MAIN | grep -i 'Registry Expiry Date' | head -1 | awk '{print $NF}')
[ -n "$exp" ] && [ $(days "$exp") -gt 45 ] || bad "$MAIN registration expires '$exp', pay the renewal at midominio.do (NIC.DO)"

[ $fail = 0 ] && echo "all checks passed"
exit $fail
