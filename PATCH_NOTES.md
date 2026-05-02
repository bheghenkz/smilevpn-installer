# SmileVPN Full Installer Fix

Main fixes:
- Xray scripts sync `/etc/xray/config.json` to `/usr/local/etc/xray/config.json` before restart.
- Create scripts remove existing same username before insert, preventing duplicate-user and not-valid-user errors.
- Removed broken quota byte calculation; IP limit remains.
- OpenClash URLs changed from invalid `:81` to `https://${DOMAIN}/...`.
- YAML indentation fixed for Trojan, VLESS, VMess, SS, TrojanGo, Reality.
- `install.sh` installs `jq` and tests Xray config before starting.
