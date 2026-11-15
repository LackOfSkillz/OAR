# Transport feasibility (AI05-01): getting answers into the game

Spec section 9 and phase AI-05. Written 2026-11-15. **No experiment has been
run.** The spec requires Gary's explicit approval before any risky experiment,
and prefers shipping without a bridge to using a questionable workaround.

## What the game allows (from docs/PROBE_RESULTS.md and FOREVER_CONSTRAINTS.md)
- Lua has no network access and cannot run programs.
- SavedVariables are read once at login and written at logout or reload.
- New files in the AddOns folder are only seen after a full client restart; a
  load-on-demand addon can be loaded once per session.
- Hard rule 2: only `tools/deploy.ps1` writes into `Interface\AddOns\Outrider`;
  the game folder is otherwise read-only to our tools.
- Hard rule 1: nothing sends input to the client.

## Options

| Option | How it would work | Works on Forever? | Risk | Verdict |
|---|---|---|---|---|
| **A. Clipboard codes (built)** | /ride ask shows a code, Ctrl+C; companion or Claude answers; Paste advice, Ctrl+V | Yes (built, specs, contract fixtures) | Low: plain text Gary copies himself; the clipboard can be read by other programs while it holds the code (no names in it) | **Keep. Release 1.** |
| **B. Desktop companion window** | A small window (standard-library Tk) watching for a snapshot code on the clipboard when Gary clicks "Read", showing the question, asking the model, and copying the answer back | Yes, outside the game | Low: same data path as A, fewer steps; needs packaging and an uninstall | **Build next (no approval issue: it never touches the game).** |
| C1. Screen-rendered request + screen capture | The addon draws an encoded block on screen; the companion captures the game window and decodes it | Unknown; capture works on most setups | **High.** Reading the game's screen pixels is how many bots work; Blizzard's anti-cheat and policy may treat it as automation even though no input is sent. Also fragile (scaling, overlays, windowed mode) | Not recommended. Needs Gary's approval and a policy review before even a prototype. |
| C2. Rewritten load-on-demand reply addon | The companion rewrites a small reply addon's data file; the addon loads it with LoadAddOn on Gary's click | Partly: an addon can load only once per session, so one answer per login | **High.** Breaks hard rule 2 (writing into AddOns while the game runs), and changing addon files at runtime looks like tampering | Not recommended. Would need a change to the hard rules. |
| C3. Audio or other side channels | Signals through sounds or resources | No supported path | High and fragile | Rejected. |

## Recommendation
- Keep A as the only in-game route.
- Build B (desktop window) as the comfort upgrade: it removes the
  command-line step without touching the game. (Done in this sprint as a
  minimal window; see the companion README.)
- Do not start C1 or C2. If Gary still wants "no alt-tab", the first step is
  a written policy question to Blizzard about screen capture by an
  out-of-game helper, not code.

## Gate AI-G5
Not passed and not attempted. AI05-02 to AI05-06 are blocked on Gary's
approval and a policy review.
