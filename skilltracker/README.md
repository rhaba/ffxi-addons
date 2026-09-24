# skilltracker

Ashita v4 addon that shows a small draggable window with your currently
relevant combat and magic skill levels.

- **Combat skill**: whichever weapon(s) you have equipped (main hand and/or
  ranged), resolved from the actual equipped item - not guessed from your
  job. Fighting bare-handed still shows H2H once it's trained.
- **Defense skills**: Guarding, Evasion, Shield, and Parrying, shown
  whenever they're above 0 for your current job/gear.
- **Magic skills**: any magic skill (Divine, Healing, Enhancing, Enfeebling,
  Elemental, Dark, Summoning, Ninjutsu, Singing, String/Wind Instrument,
  Blue Magic, Geomancy, Handbell) that's above 0 for your current job -
  this naturally matches whatever your job/subjob can actually use, since
  skill levels are tracked per job.
- Skills the game itself reports as capped show a `(MAX)` tag - this comes
  directly from the game's own data, not a hardcoded skill-cap table, so
  it's accurate regardless of level cap/era.

## Install

Copy the `skilltracker` folder into your Ashita `addons` directory, e.g.
`Ashita\addons\skilltracker\skilltracker.lua`, then:
```
/addon load skilltracker
```

## Commands

| Command                          | Description                              |
|-----------------------------------|--------------------------------------------|
| `/skilltracker on` / `off`       | Show/hide the window                      |
| `/skilltracker toggle`           | Toggle visibility                         |
| `/skilltracker combat <on\|off>`  | Hide the window while engaged in combat (default on) |
| `/skilltracker help`             | Show command list                         |

The window is a normal ImGui window - drag it by the title bar to
reposition; its position is remembered automatically between sessions. You
can also close it with the window's own close button, equivalent to
`/skilltracker off`.

## Notes

- Skill data refreshes once per second, not every frame.
- The window auto-hides while dead/at the character-select screen (no
  active character to read).
