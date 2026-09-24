# currencytracker

Ashita v4 addon that shows a small draggable window with:

- Conquest Points for all three nations (your home nation is marked)
- Allied Notes
- Beastmen Seals, Kindred Seals, Kindred Crests, High Kindred Crests,
  Sacred Kindred Crests

## Install

Copy the `currencytracker` folder into your Ashita `addons` directory, e.g.
`Ashita\addons\currencytracker\currencytracker.lua`, then:
```
/addon load currencytracker
```

## Commands

| Command                        | Description               |
|----------------------------------|-----------------------------|
| `/currencytracker on` / `off`  | Show/hide the window      |
| `/currencytracker toggle`      | Toggle visibility         |
| `/currencytracker help`        | Show command list         |

`/curr` works as a shorthand for `/currencytracker`.

## How it works / limitations

These currencies have no dedicated memory-read API in Ashita - the only way
to see them is to read the network packet the server sends for FFXI's
in-game "Currency" menu. This addon listens for that packet and caches the
last values it saw (persisted between sessions), rather than actively
polling, since it isn't clear exactly what triggers the server to send it.

**If the window says "No data yet"**, open your in-game Currency menu once
(the menu that lists Conquest Points/Allied Notes/etc.) - that should
trigger the packet and populate the window. After that, it should update
automatically whenever the game refreshes those values.
