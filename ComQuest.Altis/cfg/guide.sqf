/*
    cfg\guide.sqf  (loaded on every machine by CQ_fnc_settings)
    The player guide: shown in the map's briefing ("Player guide") and in the tablet's GUIDE tab.
    CQ_guide: [chapter title, [paragraph, ...]]. Paragraphs are plain text; <br/> is allowed.
    Server admins may edit it freely.
*/
CQ_guide = [
    ["1. First five minutes", [
        "Press U to open the menu. Join a squad (or create one) in SQUADS: the squad leader decides where you go.",
        "Walk into the HQ compound at the base and pick your class in the CLASS tab. Each class has a player limit.",
        "Gear up at an arsenal box: magazines are open to everyone, launchers, medikits, toolkits and scopes depend on your class.",
        "Take a vehicle from the rows, or wait for your squad's. Park it on a depot helipad and use Autofill to load the magazines and rockets your squad actually uses.",
        "The enemy arrives by sea: a CSAT carrier parks off the coast and starts landing troops inland. Find them before they dig in."
    ]],
    ["2. Squads and classes", [
        "Squads: up to 26 players, any number of squads. The squad leader invites players, spends the squad's combat points in the vehicle shop, and can lock a vehicle as the squad's respawn point.",
        "Classes: Rifleman, Squad Leader, Medic, Grenadier, Autorifleman, Light Anti-Tank, Heavy Anti-Tank, Anti-Air, Engineer, Sniper, Pilot. You change class only inside the HQ compound. Pilots join FALCON, the transport squad of every squad: they take aircraft from the free depot (no cooldown) and fly the others. Only squad leaders and pilots take depot vehicles.",
        "Medics heal fully. Engineers repair, defuse, hack radio towers twice as fast and carry two sandbag walls. Only pilots fly.",
        "Stats: the STATS tab ranks every player by score, kills, vehicles, objectives, heals and more, filtered by class."
    ]],
    ["3. The base", [
        "Four vehicle rows, smallest to largest, each ending at a repair depot; two more repair depots across the northern runway. Every base vehicle respawns.",
        "Autofill: on a depot helipad (or within 15 m of its repair depot), scroll and pick Autofill for my squad. 40 s cooldown.",
        "Squad respawn vehicle: a squad leader can lock a ground vehicle as the squad's spawn point. It never despawns and pitches a camp (camo net, tent, campfire) while it carries the spawn. Enemy vehicles cannot be used.",
        "Sandbags: an Engineer places two short walls anywhere outside the base (ghost preview, Q/E to rotate, 6 s to build). Recall them from the base to build again.",
        "The base is a weapons-safe zone: no firing inside the perimeter."
    ]],
    ["4. The enemy network", [
        "The carrier inserts a first HQ inland. A build truck carries the builders from site to site; kill it and construction freezes until the carrier sends another.",
        "Six stages: AA pits, HMG tower, radio tower, supply depot, fuel tanker, then the command building. A strong HQ splits and founds the next one.",
        "An HQ falls when its commander is dead or captured AND its radio tower is hacked (it becomes our relay) or destroyed. Its depot and tanker blow up a minute later and its survivors fall back to the next HQ.",
        "Supply runs by air and HEMTT convoys. Cut the convoys and the network starves.",
        "Medic and engineer teams in Marids keep the network alive. Snipers watch the approaches of each root HQ."
    ]],
    ["5. Intel and the data link", [
        "No markers: enemy positions never appear on the map by themselves. MAGPIE's drones, a captured commander or a decrypted crate put them there.",
        "Data link: a drone only reports while it is chained back to the base through overlapping ranges (base 5 km, relays 4 km, the relay Hunter 2.5 km, any friendly vehicle 1 km, drones 1 km). Links are drawn on the map.",
        "WASP holds the edge of the link toward the carrier. Dormant Darters all over the island wake when an enemy comes near.",
        "An HQ's objectives only appear once a drone has seen them and the intel reached the base.",
        "Threat compass: with a radio, inside the link's coverage, the panel at the top of the screen points to the closest enemy a drone sees (type, bearing, distance). Out of coverage it goes dark."
    ]],
    ["6. Events", [
        "Corridor outpost: on the high ground between the carrier and the first HQ, with mortar, AA, HMG towers and a jammer that keeps it off the map. Take it and the first HQ's resupply comes late.",
        "Transport crash: an enemy transport goes down with a communications crate. A hidden clock starts on contact. Reach the crate to decrypt the network's secrets.",
        "Hostage rescue: a radio technician held in a marked village house. Download his firmware, carry him to the waiting Ghost Hawk, fly him home: the Darters see further for 20 minutes."
    ]],
    ["7. Controls", [
        "U: menu (squads, class, stats, shop, guide, rules). End: earplugs (also on the scroll menu).",
        "Most actions are holds or scroll-menu entries: hack a tower, download firmware, carry the technician, autofill, place sandbags.",
        "The map's briefing panel holds the operation's progress, this guide, the server rules and the radio log."
    ]]
];
