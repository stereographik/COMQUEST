# ComQuest par stereographik

### [▶ View the mission showcase](https://stereographik.github.io/COMQUEST/)

A co-op Arma 3 scenario on Altis for up to 26 players, inspired by Invade & Annex. A CSAT carrier inserts troops by air, and a network of enemy HQs grows across the island. Each HQ builds, resupplies, redeploys and founds the next one. Players find the HQs with a radio direction finder and destroy every one of them before Colonel Harlan, the friendly commander, is killed.

**Requirements:** Arma 3 base game + CBA. No other mods, no DLC.

## Features

- **Self-running enemy network.** The carrier parks at one of 16 positions (never the same twice in a row), inserts by air and plants HQs inland. Each HQ builds in 6 stages, splits into new HQs, is resupplied by air and truck, and rebalances its infantry every minute. Roaming vehicles, helicopter patrols, medic and engineer support teams, armed locals.
- **Escalation on contact.** Nearby squads join in, a red flare brings heavy support, and attacking the first HQ pulls troops back from every HQ it founded.
- **An HQ falls** when its commander is dead or captured and its radio tower is hacked by an Engineer (it becomes a friendly relay) or destroyed. Depots go down only to demolition charges.
- **Events.** A corridor outpost on the high ground between the carrier and the first HQ (mortar, Titan AA, HMG towers, gunboats, a jammer that keeps it off the map). A random transport crash whose comms crate both sides race for: hidden 10-minute clock, enemy armour paradropped by CH-49, decryption reward.
- **MAGPIE.** Two Sentinel drones plus dormant Darters on a 500 m grid that wake when an enemy comes near. Reports every 2 minutes.
- **Squads and classes in game.** 26 identical lobby slots. In the U menu you create, join or leave squads, invite players, and pick from 11 classes with per-class limits. Best vanilla kit and suppressors for everyone; a role-aware arsenal (launchers, medikits, toolkits, ghillies and so on gated by class, magazines open to all).
- **Stats and vehicle shop.** Per-player statistics with a sortable, class-filtered ranking. Squad leaders spend squad combat points on 7 armed vehicles.
- **Built base.** Walled HQ compound, 4 vehicle rows parked smallest to largest, crate dispensers with loadout zones, repair depots, AA/HMG defences. All base vehicles respawn; a respawn vehicle is locked while it carries the spawn point.
- **Radio and intel.** CROSSROAD, MAGPIE and COMHAT messages never give a location. A signal meter (0–100 %) points to the closest built HQ. Earplugs on the scroll menu and the End key.
- **Admin.** Debug panel (F3 or U menu) docked on the right: teleporters, map visibility, HQ, forces, events, friendly, story and logs.

## Install

Copy `ComQuest.Altis` into `Documents\Arma 3 - Other Profiles\<profile>\mpmissions\`, then host a multiplayer game and pick **ComQuest**.

## Configure

**[Server admin settings guide](https://claude.ai/artifact/VLWo2kk6tQpMBEzHs8UiCm)**: what every setting does, the debug panel, and a checklist before a real game.

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
  functions/air/           helicopter fleet, patrols, MAGPIE drones
  functions/events/        transport crash, corridor outpost
  functions/players/       base, vehicles, crates, squads, classes, stats, shop
docs/index.html            showcase page (GitHub Pages)
```

ComQuest par stereographik
