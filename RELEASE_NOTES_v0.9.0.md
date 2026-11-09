First tagged build of **ComQuest.Altis**, a vanilla Arma 3 co-op scenario (only CBA needed) for up to 26 players. Not fully play-tested yet.

**Install:** unzip `ComQuest.Altis.zip` into `Documents\Arma 3 - Other Profiles\<profile>\mpmissions\` and host it from the multiplayer menu.

### Enemy
- A CSAT carrier inserts by helicopter and paradrop. The first HQ is a beachhead.
- HQs secure a 1 km perimeter, then build in 4 stages: command post, sandbags, depot + radio, helipad + AA + HMG tower.
- Built HQs split and found new ones, up to 8 alive at once. Two squads of armed locals join each finished HQ.
- Logistics: air resupply to the main HQ and HEMTT convoys to the others.
- Every minute the infantry is rebalanced across HQs.
- Vehicles roam between HQs. Helicopters fly patrols. Medic and engineer support teams keep the network running.
- On contact: help from squads within 700 m, a red flare for heavy support, and every child HQ sends troops back if the first HQ is attacked.

### Win and lose
- An HQ falls when its commander is dead or captured and every installation is destroyed.
- Capturing a commander puts his whole network on the map.
- Victory: every HQ destroyed. Defeat: Colonel Harlan is killed.

### Players
- 26 identical lobby slots. Squads and classes are chosen in game (U menu), with 11 classes and per-class limits.
- Class changes only inside the HQ compound.
- Squad invites, with an accept/decline window.
- STATS tab: per-player statistics, class filter, sortable ranking.
- Vehicle shop: squad leaders spend squad combat points on 7 armed vehicles.
- Radio direction finder (0–100 % signal from the closest built HQ).
- Three radio voices (CROSSROAD, MAGPIE, INTERCEPT) that never give a location.

### Base
- Walled HQ compound with four squad equipment boxes (arsenal).
- Four vehicle rows, sorted small to large and parked at right angles to the row, 19 vehicles in total, all respawning.
- A crate dispenser and a loadout zone at the end of each row.
- Two repair depots facing the runway, and AA/HMG defence positions.

Settings: `cfg/settings.sqf` and `cfg/story.sqf`. Showcase page: https://stereographik.github.io/COMQUEST/
