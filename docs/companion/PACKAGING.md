# Companion packaging plan (OI08-10)

The companion is Python using the **standard library only**: there are no dependencies to pin. This is a plan; no installer has been built or published.

| Topic | Plan |
|---|---|
| Install | A zip with `companion/` and a `Setup.cmd` that checks for Python 3.10 or newer and copies `config.example.json` to `config.json` with `"enabled": false`. No admin rights. |
| Startup | Never registered to start with Windows. The MCP client starts it when asked. |
| Offline | The default. No network unless a provider is configured, and a cloud provider also needs `cloudConsent`. |
| Updates | Manual: download a new zip. The companion checks its own version against the addon's in the snapshot and says when they differ. It never downloads. |
| Settings backup | `config.json` and `policy.json` are copied to `companion/backups/<stamp>/` before an update overwrites the folder. |
| Rollback | Unzip the previous version and restore that backup. |
| Uninstall | Delete the `companion/` folder. Keys stay in Windows Credential Manager under `Outrider/` until removed with `keys delete`, and the uninstall note says so. Nothing in WoW is touched. |
| Signing | Unsigned. Windows SmartScreen may warn, and the README says so. |
| Clean machine trial | Pending, on a Windows machine without the repo (owner). |
