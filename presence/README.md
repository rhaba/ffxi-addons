# presence

Ashita v4 addon that shows your FFXI job and zone as your **Discord Rich
Presence** status - the "Playing ..." line that appears under your name in
Discord. It does not post any messages to any channel; it only updates your
own local Discord client's status, the same mechanism games use natively.

It talks directly to your locally running Discord desktop client over its
IPC (named pipe) protocol using LuaJIT's FFI - no external helper process,
no bot, no webhook.

**Requires the Discord desktop client to be running on the same PC as
FFXI.** Rich Presence is a local-client feature; it will not work against
Discord in a browser or on another machine.

## Set up a Discord Client ID (one-time, free)

Rich Presence requires a Discord "Application" purely to get a Client ID -
you do not create a bot, add it to a server, or invite it anywhere.

1. Go to <https://discord.com/developers/applications> and log in.
2. Click **New Application**, give it a name (e.g. "FFXI Presence") - this
   name is what Discord shows next to your status.
3. On the **General Information** page, copy the **Application ID**. That's
   your Client ID.
4. (Optional) Under **Rich Presence > Art Assets**, upload an image (e.g.
   `branding/phoenix_presence_logo.png` in this addon's folder) and note the
   asset key you give it - then run `/presence icon <key> [hover text]`
   in-game to use it as your large icon.

## Install

1. Copy the `presence` folder into your Ashita `addons` directory, e.g.:
   `Ashita\addons\presence\presence.lua`
2. In-game (or in `scripts/default.txt`), load it:
   ```
   /addon load presence
   ```
3. Set your Client ID:
   ```
   /presence clientid 123456789012345678
   ```
4. Verify it works:
   ```
   /presence test
   ```
   Check your own Discord profile - you should see "Playing FFXI Presence"
   (or whatever you named the application) with your job and zone.

Settings are saved automatically to
`Ashita\config\addons\presence\settings.lua`.

## Commands

| Command                          | Description                                    |
|-----------------------------------|-------------------------------------------------|
| `/presence clientid <id>`        | Set the Discord application Client ID          |
| `/presence on` / `off`           | Enable/disable Rich Presence updates           |
| `/presence job <on\|off>`         | Show job/subjob in the details line (default on) |
| `/presence zone <on\|off>`        | Show current zone in the state line (default on) |
| `/presence icon <key> [text]`    | Set the large image asset key (and optional hover text) |
| `/presence icon clear`           | Remove the large image asset                   |
| `/presence test`                 | Force an immediate presence update             |
| `/presence status`               | Show current settings/connection state         |
| `/presence help`                 | Show command list                              |

## How it works

Each render frame (throttled to once every `poll_interval` seconds, default
2) the addon checks your own party slot (`party:GetMemberIsActive(0)`),
job/subjob, and zone:

- **Login** (character-select -> in world): opens the local Discord IPC
  connection, sends the handshake, and sets your activity with an elapsed
  timer starting from that moment.
- **Job, subjob, or zone change**: updates the details/state text on the
  existing connection.
- **Logout** (in world -> character-select): clears your activity so
  Discord stops showing "Playing ...".
- **Addon unload / `/addon unload presence`**: clears the activity and
  closes the pipe.

If Discord isn't running (or hasn't been given a Client ID yet), updates are
marked "pending" and retried automatically, at most once every 15 seconds,
so it recovers on its own once Discord is available.

## Notes / caveats

- Only your own character (party index 0) is tracked - this shows one
  character's presence, not a party/alliance monitor.
- The IPC write is effectively instant (a local named pipe, not a network
  call), so there's no noticeable hitch like there would be with an HTTP
  request.
- If you run multiple FFXI characters at once, each Ashita instance connects
  to Discord independently; only the most recently updated one will be
  visible, since Discord shows one Rich Presence per application per user.
