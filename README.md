# ComQuest

A vanilla Arma 3 multiplayer scenario on Altis: a CSAT network of field HQs grows across the island by air insertion, ground reinforcement and expansion. Players (NATO, Altis International Airport) win by destroying every HQ. Inspired by Invade & Annex.

**Vanilla only:** no CBA, no ACE, no server mod. Players download the mission when they join.

Design doc: https://claude.ai/artifact/8r2XjQb2o8Q39gik4yp7MW

## Layout

```
ComQuest.Altis/
  description.ext        respawn, garbage collector, CfgFunctions
  mission.sqm            16 NATO slots at the airport (text, not binarized)
  initServer.sqf         server start: base, vehicles, director
  initPlayerLocal.sqf    client start
  onPlayerRespawn.sqf    restores the saved loadout
  cfg/settings.sqf       every tunable number
  functions/core/        settings, log, director loop
  functions/players/     base, vehicle respawn, pilot seats, player setup
```

## Install for testing

Copy `ComQuest.Altis` into `Documents\Arma 3 - Other Profiles\<profile>\mpmissions\`, then in Arma: Editor → Altis → open `ComQuest`, or host a LAN server and pick it.

Logs: every line starts with `[CQ]` in `%LOCALAPPDATA%\Arma 3\*.rpt`.

## Milestones

1. [x] Skeleton: mission, settings, logging, director, airport base, 3 respawning unarmed vehicles, arsenal, slots
2. [ ] One HQ by hand: site search + composition + garrison
3. [ ] HQ lifecycle: states, commander, engineer-only radio/depot, destruction
4. [ ] Air insertion: scripted Taru slingload
5. [ ] Waves + expansion, 200 AI cap
6. [ ] Comms network + ammo economy
7. [ ] Squad management UI
8. [ ] Polish + balance
