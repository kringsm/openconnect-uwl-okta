Quick and dirty script to automate connecting via openconnect to an anyconnect server with SAML authentication via okta SSO, no error handling, assumes totp is your first or only okta factor, use at your own risk, etc

Only tested with UWL's anyconnect and okta configurations

## Requirements
- bash, cut, awk
- [curl](https://curl.se/) 
- [jq](https://jqlang.github.io/jq/) json parser
- [pup](https://github.com/ericchiang/pup) html parser
- oathtool from [oath-toolkit](https://www.nongnu.org/oath-toolkit/) for totp
- [GNU screen](https://www.gnu.org/software/screen/) (optional just my preferred way to run openconnect)
- [openconnect](https://www.infradead.org/openconnect/) of course

The following variables (set them in conf.sh file, or use env vars, or edit to prompt for them each time, or do something smarter / more secure if you care (I dont)):
```sh
okta_domain
anyconnect_domain
anyconnect_group
user
pass
totp_secret
```
