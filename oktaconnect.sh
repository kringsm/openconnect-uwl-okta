#!/usr/bin/env bash
. conf.sh # domains and credentials

response=$(curl -s -H 'Accept: application/json' -H 'Content-Type: application/json' -d '{"username": "'"$user"'","password": "'"$pass"'","options": {"multiOptionalFactorEnroll": false,"warnBeforePasswordExpired": false}}' 'https://'"$okta_domain"'/api/v1/authn')

state=$(echo "$response" | jq -r '.stateToken')
verify=$(echo "$response" | jq -r '._embedded.factors[0]._links.verify.href')
otp=$(oathtool --totp -b "$totp_secret")

session_token=$(curl -s -H 'Accept: application/json' -H 'Content-Type: application/json' -d '{"stateToken": "'"$state"'","passCode": "'"$otp"'"}' "$verify" | jq -r '.sessionToken // empty ')
okta_cookies=$(curl -s -c - -o /dev/null 'https://'"$okta_domain"'/login/sessionCookieRedirect?token='"$session_token"'&redirectUrl') # bad but idk any other way

if [[ -z "$session_token" ]]; then
  echo 'failed to create okta session'
  exit 1
fi
echo 'okta session created successfully'

saml_req_uri=$(curl -s -w '%{redirect_url}' 'https://'"$anyconnect_domain"'/+CSCOE+/saml/sp/login?tgname='"$anyconnect_group" | cut -d '/' -f4-)
saml_req_url='https://'"$okta_domain"'/'"$saml_req_uri"

appform=$(curl -s -b <(echo "$okta_cookies") "$saml_req_url" | pup 'form#appForm')
saml_resp_url=$(echo "$appform" | pup 'form#appForm attr{action}')
saml_resp=$(echo "$appform" | pup 'form#appForm input[name="SAMLResponse"] attr{value}' | jq -Rr @uri)

curl -s -b <(echo "$okta_cookies") -X DELETE 'https://'"$okta_domain"'/api/v1/sessions/me'
echo 'okta session terminated (no longer needed)'

cisco_idiocy=$(curl -s -H 'Content-Type: application/x-www-form-urlencoded' -d 'SAMLResponse='"$saml_resp"'&RelayState=' "$saml_resp_url")
real_saml_resp_uri=$(echo "$cisco_idiocy" | pup 'form#samlform attr{action}')
csrf_token=$(echo "$cisco_idiocy" | pup 'form#samlform input[name="csrf_token"] attr{value}')

anyconnect_cookie=$(curl -s -c - -o /dev/null -H 'Content-Type: application/x-www-form-urlencoded' -H 'Cookie: webvpnlogin=1; CSRFtoken='"$csrf_token" -d 'csrf_token='"$csrf_token"'&group_list='"$anyconnect_group"'&username=&password=&SAMLResponse='"$saml_resp"'&ctx=' 'https://'"$anyconnect_domain""$real_saml_resp_uri" | awk '/\twebvpn\t/{print $7}')

screen sudo openconnect 'https://'"$anyconnect_domain" --useragent 'AnyConnect' -C "$anyconnect_cookie"
