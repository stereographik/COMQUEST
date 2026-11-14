/*
    cfg\guide.sqf  (loaded on every machine by CQ_fnc_settings)
    The player guide: shown in the map's briefing ("Player guide") and in the tablet's GUIDE tab.
    CQ_guide: [chapter title, [paragraph, ...]]. Paragraphs are plain text; <br/> is allowed.
    Server admins may edit it freely.
*/
CQ_guide = [
    ["1. First five minutes", [
        "Press U to open the menu. Join a squad (or create one) in SQUADS: the squad leader decides where you go.",
        "Walk into the keep, the walled compound in the middle of Camp Harlan, and pick your class in the CLASS tab. Each class has a player limit.",
        "Gear up at your squad's arsenal box in the keep: magazines are open to everyone, launchers, medikits, toolkits and scopes depend on your class.",
        "Your squad leader takes the squad's vehicles at the motor pool (or buys one at the shop); a Falcon pilot can fly you anywhere.",
        "The enemy arrives by sea: a CSAT carrier parks off the coast and starts landing troops inland about five minutes after the start. Find them before they dig in."
    ]],
    ["2. Squads and classes", [
        "Squads: up to 8 players each, any number of squads. The squad leader invites players, takes the squad's depot vehicles, spends the squad's combat points in the vehicle shop, and can lock a vehicle as the squad's respawn point.",
        "Squad vehicles belong to the squad: only its members can get in. Leave the squad and you lose access at once; disband it and its vehicles are removed one minute later.",
        "Classes: Rifleman, Squad Leader, Medic, Grenadier, Autorifleman, Light Anti-Tank, Heavy Anti-Tank, Anti-Air, Engineer, Sniper, Pilot. You change class only inside the keep.",
        "Pilots join FALCON, the transport squad of every squad. Only pilots can sit at the controls of an aircraft (pilot and co-pilot seats); anyone can ride in the back.",
        "Medics heal fully. Engineers repair, defuse, hack radio towers twice as fast and carry two sandbag walls.",
        "Stats: the STATS tab ranks every player by score, kills, vehicles, objectives, heals and more, filtered by class."
    ]],
    ["3. The base: Camp Harlan", [
        "Camp Harlan sits on the AAC airfield, behind H-barriers and a concrete inner wall with low view windows. Two ways in: the entry control point on the west wall (loop road) and the runway gate on the taxiway side.",
        "The keep: command post with Colonel Harlan, medical post, four squad bays with their arsenal boxes, the muster point. Classes are changed here.",
        "Motor pool (south): four free vehicle depots. Only squad leaders take ground vehicles: two in a row, then a cooldown; a squad has at most two out. The vehicle shop pad is next to the entry control point.",
        "Aviation apron (along the taxiway): four helipads with pilot terminals, for Falcon pilots only: one aircraft each, no cooldown. The CH-49 Mohawk hooks and carries any vehicle up to 12 t (Hook vehicle / Release cargo, or it lets go by itself once the load rests on the ground).",
        "Every depot pad and helipad is also a repair point. Autofill: park on a depot pad, scroll and pick Autofill for my squad to load the magazines and rockets your squad actually uses (40 s cooldown).",
        "A depot vehicle left empty for 10 minutes with nobody near goes back in stock. Enemy vehicles cannot be used.",
        "Squad respawn vehicle: a squad leader can lock a ground vehicle as the squad's spawn point. It never despawns and pitches a camp (camo net, tent, campfire) while it carries the spawn.",
        "Sandbags: an Engineer places two short walls anywhere outside the base (ghost preview, Q/E to rotate, 6 s to build). Hold the action on your own wall for 2 s to take it down, or recall them from the base.",
        "Weapons are safe within 800 m of the base: the trigger does nothing. When enemies come inside that ring, the base goes weapons free until it is clear again."
    ]],
    ["4. The enemy network", [
        "The carrier inserts a first HQ inland. A build truck carries the builders from site to site; kill it and construction freezes until the carrier sends another.",
        "Six stages: AA pits, HMG tower, radio tower, supply depot, fuel tanker, then the command building. A strong HQ splits and founds the next one.",
        "Sub-objectives count in the Operation tab as they fall. An AA pit is neutralised as soon as its crew is dead.",
        "An HQ falls when its commander is dead or captured AND its radio tower is hacked (it becomes our relay) or destroyed. Its depot and tanker blow up a minute later and its survivors fall back to the next HQ.",
        "Supply runs by air and HEMTT convoys. Cut the convoys and the network starves.",
        "Medic and engineer teams in Marids keep the network alive. Snipers watch the approaches of each root HQ."
    ]],
    ["5. Intel and the data link", [
        "No markers: enemy positions never appear on the map by themselves. MAGPIE's drones, a captured commander or a decrypted crate put them there.",
        "Data link: a drone only reports while it is chained back to the base through overlapping ranges (base 5 km, relays 4 km, the relay Hunter 2.5 km, any friendly vehicle 1 km, drones 1 km). Links are drawn on the map.",
        "WASP holds the edge of the link toward the carrier. Dormant Darters all over the island wake when an enemy comes near.",
        "An HQ's objectives only appear once a drone has seen them and the intel reached the base.",
        "The enemy fights back: a sabotage team may hunt WASP, and a lost link to WASP or the relay vehicle is bridged by free Darters after two minutes.",
        "Threat compass: with a radio, inside the link's coverage, the panel at the top of the screen points to the closest enemy a drone sees (type, bearing, distance). Out of coverage it goes dark."
    ]],
    ["6. Events", [
        "Corridor outpost: on the high ground between the carrier and the first HQ, with mortar, AA, HMG towers and a jammer that keeps it off the map. Take it and the first HQ's resupply comes late.",
        "Transport crash: an enemy transport goes down with a communications crate. A hidden clock starts on contact. Reach the crate to decrypt the network's secrets.",
        "Hostage rescue: a radio technician held in a marked village house. Download his firmware, carry him to the waiting Ghost Hawk, fly him home: the Darters see further for 20 minutes.",
        "Every side event and how it ended is listed in the Operation tab (Side events)."
    ]],
    ["7. Controls", [
        "U: menu (squads, class, stats, shop, guide, rules). End: earplugs (also on the scroll menu).",
        "Most actions are holds or scroll-menu entries: hack a tower, download firmware, carry the technician, autofill, place or dismantle sandbags, hook and release cargo.",
        "The map's briefing panel holds the operation's progress, this guide, the server rules and the radio log."
    ]]
];
