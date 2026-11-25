# Privacy: what Outrider keeps and what can leave your PC

**Nothing leaves your PC by itself.** The only things that can go out are:
- addon messages (guild, party, raid or whisper) for sharing features you switched on;
- text you copy yourself (exports).

There is no network code in the addon.

| Feature | Kept on this PC | Can leave the PC | How |
|---|---|---|---|
| Outcome recorder | Session events, money in and out, quests, levels, travel times | Only when you copy *Export my records* | Off by default; Start fresh archives first |
| Chronicle | Milestones (levels, zones, quests) | Only when you copy its export | Kinds you hide aren't recorded |
| Sharing (rares, gathering, kit cards) | Received sightings and cards | Your sightings and cards, to guild or party | Off by default |
| Group plan | Group members' messages, in memory only | Your goals, plan picks, ready, level and role, to your party | Off by default; Stop sharing asks the others to forget you |
| World observation export | Your discoveries and sightings | Only the rows you preview and export: ids, map, rounded coordinates, layer, build, method. Never names, account, realm (unless ticked), chat, gold, bags or walking trail | Off by default; the export needs the preview's token |
| Troubleshooter | Nothing new | *Copy the list*, with your name replaced and no realm or gold | Your copy |
| Mentor bundles and plan references | What you accepted, with its source, license and build | Only what you export | Data only; nothing runs |

Collected data is never deleted or redacted by Outrider. Data that is replaced is archived first (`docs/quality/data_preservation_audit.json` lists every saved dataset).
