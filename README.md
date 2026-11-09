# ComQuest

### [▶ View the mission showcase](https://stereographik.github.io/COMQUEST/)

A co-op Arma 3 scenario on Altis for up to 26 players, inspired by Invade & Annex. A CSAT carrier inserts troops by air, and a network of enemy HQs grows across the island. Each HQ builds, resupplies, redeploys and founds the next one. Players find the HQs with a radio direction finder and destroy every one of them before Colonel Harlan, the friendly commander, is killed.

**Requirements:** Arma 3 base game + CBA. No other mods, no DLC.

## Features

- **Self-running enemy network.** Beachhead insertion, 4-stage HQ construction, splitting into new HQs (up to 8 alive), air and truck logistics, infantry rebalanced every minute, roaming vehicles, helicopter patrols, medic and engineer support teams, armed locals.
- **Escalation on contact.** Nearby squads join in, a red flare brings heavy support, and attacking the first HQ pulls troops back from every HQ it founded.
- **Squads and classes in game.** 26 identical lobby slots. In the U menu you create, join or leave squads, invite players, and pick from 11 classes with per-class limits (class changes inside the HQ compound only).
- **Stats and vehicle shop.** Per-player statistics with a sortable, class-filtered ranking. Squad leaders spend squad combat points on 7 armed vehicles.
- **Built base.** Walled HQ compound, 4 vehicle rows parked smallest to largest, crate dispensers with loadout zones, repair depots, AA/HMG defences. All base vehicles respawn.
- **Radio and intel.** CROSSROAD, MAGPIE and INTERCEPT messages never give a location. A signal meter (0–100 %) points to the closest built HQ.

## Install

Copy `ComQuest.Altis` into `Documents\Arma 3 - Other Profiles\<profile>\mpmissions\`, then host a multiplayer game and pick **ComQuest**.

## Configure

- `ComQuest.Altis/cfg/settings.sqf`: every tunable number (timings, limits, classes, base layout, shop prices).
- `ComQuest.Altis/cfg/story.sqf`: all radio lines.

Logs: every line starts with `[CQ]` in `%LOCALAPPDATA%\Arma 3\*.rpt`.

## Layout

```
ComQuest.Altis/
  description.ext          mission header, CfgFunctions
  mission.sqm              26 Rifleman slots
  initServer.sqf           base, vehicles, director tasks
  initPlayerLocal.sqf      client start (squads, signal meter, stats)
  cfg/                     settings.sqf, story.sqf
  functions/core/          settings, log, director, radio cards
  functions/hq/            HQ build, garrison, contact, balance, roaming
  functions/spawn/         carrier, insertion, paradrops, colonists, support teams
  functions/logistics/     ammo flights, convoys, rearm
  functions/air/           helicopter fleet, patrols
  functions/players/       base, vehicles, crates, squads, classes, stats, shop
docs/index.html            showcase page (GitHub Pages)
```
