/*
    cfg\settings.sqf
    Every tunable number of ComQuest lives here.
    Loaded on every machine (server and clients) before init, by CQ_fnc_settings.
*/

CQ_debug = false;                        // test settings (short stages, debug labels); the host starts with all logs in chat. Debug panel: host + logged-in admins only, always
CQ_playerView = true;                    // final player view by default: no debug chat, cards or markers (toggle in the debug panel)
CQ_debugCards = false;                   // debug phase messages as orange cards too (story lines use the cards)
// log lines starting with one of these words go to "Show all friendly logs", every other one to "Show all enemy logs"
CQ_logFriendlyRx = "(MAGPIE|Sentinel|Squads?|Base|Depot|Vehicle|Respawn|Shop|Score|Player|Muster|Grass|Friendly|Billboard|Redeploy|Repair|Runway|Supply crate|Auto-fill|Heatmap|Intro|Safe|Range|Kit|Story|STORY|Weather|Start).*";

// --- Director -------------------------------------------------------------
CQ_logVerbose = false;                   // true: also log every drone route / ring / Tigris lock (chatty .rpt)
CQ_tickSeconds = 5;                      // one server tick every 5 s

// --- Player base (Altis International Airport) -----------------------------
CQ_basePos = [14267, 16099, 0];         // base compound centre (HQ zone drawn on the map)
CQ_baseRadius = 300;                     // base zone drawn on the map
CQ_safeZoneRadius = 800;                 // weapons-safe perimeter: players cannot fire inside it...
CQ_safeZoneHold = 30;                    // ...unless an enemy is inside (and for 30 s after the last one left)
CQ_baseNoSpawnRadius = 2500;             // no enemy site closer than this (milestone 2)

CQ_baseDir = 38;                         // compound front and vehicle rows compass direction
// --- Vehicle depot quotas: free vehicles requested at the depots (repair stations) --
// [classname, role (only lays out the vehicle zone rows), max out at the same time]
CQ_baseVehicles = [
    ["B_MRAP_01_F",               "hunter",     4],   // Hunter, unarmed
    ["I_MRAP_03_F",               "strider",    4],   // Strider, unarmed
    ["B_G_Offroad_01_armed_F",    "pickup",     4],   // Offroad HMG
    ["B_Truck_01_transport_F",    "hemtt",      2],   // HEMTT troop transport
    ["B_Heli_Light_01_F",         "littlebird", 6],   // MH-6 Little Bird
    ["B_Heli_Transport_01_F",     "ghosthawk",  4]    // UH-80 Ghost Hawk (one line per class: the quota is read from the first match)
];
CQ_baseVehPadding = 25;                  // metres between base vehicles (fallback search)
// Base layout (CQ_fnc_baseSetup), from the zones drawn on the map:
//   HQ compound at CQ_basePos facing CQ_baseDir; 4 parallel vehicle rows in the vehicle zone
//   (start point next to the HQ, running along CQ_baseDir); a crate dispenser + loadout zone
//   at the far end of each row; 2 repair stations east of the vehicle zone
CQ_billboardFlip = false;                // true if the base billboard (front wall, right of the gate) shows its back to the courtyard
CQ_compoundSize = [80, 60];              // inner compound width x depth (m)
CQ_grassCut = true;                      // false: no grass cutting at all (test switch)
CQ_grassCutRadius = 100;                 // no grass this far around the base centre (m)...
CQ_grassCutSpacing = 10;                 // ...normal-size clutter cutters this far apart (lower it if grass shows between them)
CQ_rayStarts = [[14255, 16151, 0], [14282, 16143, 0], [14304, 16130, 0], [14330, 16116, 0]];
CQ_dispensers = [[14293, 16200, 0], [14310, 16189, 0], [14339, 16175, 0], [14364, 16166, 0]];   // pushed further out if a row is longer
CQ_repairSpots = [[14409, 16135, 0], [14380, 16102, 0]];
CQ_dispenserCrates = 2;                  // ready-filled crates per dispenser
CQ_raySpacing = 5;                       // safety gap between two vehicles (on top of their own size)
CQ_repairDepotRot = 0;                   // turn the repair depot model if its open side is not toward the runway (e.g. 180)
CQ_repairRadius = 12;                    // repair station service radius (repair, refuel, rearm)
// Base parking area: the zone marked on the map (SW end of the runway, next to the camp).
// An area marker named cq_park_area placed in Eden overrides it.
CQ_parkArea = [[14193, 16226, 0], [14480, 16194, 0], [14158, 15889, 0]];   // [x, y, 0]: inPolygon needs 3 numbers per point
CQ_parkGrid = 25;                        // base parking grid: one vehicle per cell, cells 25 m apart
CQ_parkClear = 10;                       // a cell needs no object / rock / building / tree within this
CQ_parkMaxGradient = 0.1;                // ...and flat ground
CQ_parkSearch = 450;                     // grid searched this far around the park point behind the camp
CQ_vehAbandonDelay = 900;                // depot vehicle empty and still this long, no player within 200 m: back in stock (15 min)
CQ_opNotifyGap = 20;                     // "Objectives updated, check map": at most one notification every 20 s
CQ_rspCredits = 10;                      // squad respawn vehicle: teleports a vehicle gives before it stops being a respawn point
CQ_rspBaseRange = 150;                   // ...teleports leave from within this of the base muster point
CQ_earplugLevel = 0.08;                  // earplugs (End key / scroll menu): game sound volume while they are in
CQ_depotMaxPerSquad = 2;                 // depot vehicles out at the same time per squad
CQ_depotCooldown = [["light", 120], ["truck", 180], ["air", 300]];   // s before the same player can request again, by type taken
CQ_depotRange = 10;                      // metres from the depot furniture to use it
CQ_depotReturnRange = 30;                // a vehicle this close to a depot (or its pad) can be returned
CQ_depotPadGap = 24;                     // depot helipad distance behind the repair point (away from the runway)

// --- Start time: always at dawn, in the first rays of the rising sun
CQ_startAtDawn = true;
CQ_startAfterSunrise = 6;                // minutes after sunrise (low golden light)

// --- Weather (CQ_fnc_weatherTick). Delays and transitions in real seconds
CQ_wxChangeEvery = [900, 1800];          // a change every 15-30 min
CQ_wxBadChance = 0.10;                   // chance a change brings cloudy or cloudy + rain (else clear <-> partly cloudy)
CQ_wxTransition = [60, 120];             // every transition takes 1-2 min (never under 1 min)
CQ_wxRainMax = 240;                      // a rain never lasts more than 4 min (fade in + hold + fade out)
CQ_wxRainLevel = 0.6;
CQ_wxFogMorning = [0.2, 0.012, 0];       // light morning fog [density, decay, base]
CQ_wxFogGoneHour = 11;                   // in-game hour when the fog has slowly faded out

// --- Enemy origin: a carrier off the coast of Altis ----------------------------
CQ_carrierClass = "Land_Carrier_01_base_F";   // USS Freedom (free Jets platform update)
// >>> TEST OVERRIDE (test branches only, set to false before merging to main) <<<
// carrier at the map's mid-height, first HQ next to Charkia (looked up by name)
CQ_testOverride = false;
CQ_testFirstHqTown = "Charkia";
CQ_testFirstHqPos = [18300, 15300, 0];   // around Charkia: search centre and fallback
// allaroundisland: 16 precomputed carrier sites all around the island (deep water ~2.7 km off the coast,
// away from steep cliffs), each with its paired first HQ site (flat, open, near the shore, 3-5.5 km away).
// Every game picks one at random, never the one of the previous game (remembered in the server profile).
// [[carrier x, y], [first HQ x, y]]
CQ_carrierSites = [
    [[14612, 26312], [14288, 23012]],    // C1  north
    [[17188, 25012], [16188, 21462]],    // C2
    [[20488, 24238], [22662, 21512]],    // C3
    [[23762, 27362], [23912, 23788]],    // C4
    [[28312, 28562], [27862, 25288]],    // C5  north-east tip
    [[27812, 17438], [25388, 19638]],    // C6  east
    [[26538, 13862], [24112, 15688]],    // C7
    [[25012, 11088], [21712, 11362]],    // C8
    [[25988,  7188], [22462,  7162]],    // C9
    [[21838,  2112], [21562,  5962]],    // C10 south-east
    [[16588,  4238], [18762,  6362]],    // C11 south
    [[11662,  3662], [ 9862,  8788]],    // C12
    [[ 4862,  6762], [ 7288, 11338]],    // C13 south-west
    [[ 1512, 15862], [ 4912, 14712]],    // C14 west
    [[ 3962, 25312], [ 8912, 22938]],    // C15 north-west
    [[11162, 25688], [11912, 22588]]     // C16 north
];
CQ_carrierSiteForce = -1;                // >= 0: always this site (index in CQ_carrierSites), for tests
CQ_rootInland = [1500, 4000];            // root insertions land this far inland from a coast point
CQ_firstRootInland = [0, 400];           // the very first one: within 400 m of the site's paired first HQ position
CQ_rootRetryDelay = 180;                 // s: a root insertion that put nobody on the ground is flown again at the same site
CQ_rootCoastSpread = 4000;               // later ones: a coast point up to this far either side of the carrier's line to the island
CQ_childSpread = 70;                     // child HQs head toward the player base, +/- this many degrees
CQ_waveSpread = 60;                      // waves arrive from the carrier side of the HQ, +/- degrees
CQ_assaultRange = 3500;                  // an HQ this close to the player base assaults it instead of colonising
CQ_assaultSweep = 300;                   // assault groups this close to the command post sweep the base (COMBAT, SAD)
CQ_assaultBreach = 70;                   // ...and this close, the infantry storms the command post after Colonel Harlan

// --- Event: enemy transport crash (CQ_fnc_crashTick / crashStart / crashSecure / crashRoam) -----
// A CSAT transport goes down between the base and an enemy HQ: wreck, a crate of enemy comms
// gear and CQ_crashSurvivors guarding it. Their first contact with us starts a hidden
// CQ_crashTimer s countdown (a "securing device" warning under the signal panel); if the crate
// is not secured by then, the carrier paradrops one of CQ_crashDropClasses with a squad, which
// roams around the site for CQ_crashRoam s, then joins the nearest enemy HQ. A player reaching
// the crate secures it (no condition): CQ_crashDecrypt s of decryption = MAGPIE sees everywhere
// and every enemy HQ and radio tower is shown on the map.
// When: the front has not moved (no HQ built, fallen or launched, no relay) for CQ_crashStagnant
// s; at most every CQ_crashCooldown s; plus a CQ_crashEarlyChance chance of one in the first
// CQ_crashEarlyWindow s. Debug panel: Trigger crash / Teleport to crash / Decrypt now.
CQ_crash = true;
CQ_crashStagnant = 1200;                 // s without any front change
CQ_crashCooldown = 2400;                 // s between two crashes (40 min)
CQ_crashEarlyChance = 0.1;               // chance of a crash in the first CQ_crashEarlyWindow s
CQ_crashEarlyWindow = 900;               // s (15 min)
CQ_crashSiteFrac = [0.35, 0.65];         // site between the base (0) and an enemy HQ (1)
CQ_crashPlayerGap = 800;                 // m: never right next to a player
CQ_crashWrecks = ["Land_Wreck_Plane_Transport_01_F", "Land_Wreck_Heli_Attack_02_F", "Land_UWreck_Heli_Attack_02_F"];   // first that exists
CQ_crashCrate = "Box_East_Support_F";
CQ_crashSurvivors = ["O_Soldier_SL_F", "O_Soldier_AR_F", "O_soldier_M_F", "O_Soldier_LAT_F", "O_Soldier_F"];
CQ_crashSkill = 0.75;                    // survivors: sharp
CQ_crashTimer = 600;                     // s after their first contact before the carrier drops help
CQ_crashWarn = 120;                      // s before the drop: CROSSROAD warns
CQ_crashDropClasses = ["I_LT_01_cannon_F", "O_APC_Tracked_02_cannon_F", "O_APC_Wheeled_02_rcws_v2_F", "I_APC_Wheeled_03_cannon_F"];   // Nyx, Kamysh, Marid, Gorgon (DLC ones skipped)
CQ_crashDropSquad = ["O_Soldier_TL_F", "O_Soldier_AR_F", "O_Soldier_LAT_F", "O_Soldier_F"];   // in its cargo seats
CQ_crashRoam = 600;                      // s the dropped vehicle roams around the site
CQ_crashRoamR = [150, 900];              // m: roaming radius, close -> large -> close
CQ_crashDecrypt = 720;                   // s of decryption (12 min)

// --- Corridor outpost (CQ_fnc_outpostBuild / CQ_fnc_outpostTick), first HQ only ----------------
// With the first HQ's insertion the enemy holds the land corridor between the coast (CQ_coastPoint)
// and that HQ: on its highest open spot that best sees the flight corridor (or an Altis military
// post found there), a watchtower, CQ_opAA, CQ_opHMG, a mortar and a barricaded squad; 2 gunboats
// patrol the coast. Out of the AI caps, never reinforced. Its jammer (destroyable) hides it:
// MAGPIE only gets a rough area (black hatched circle, ~CQ_opFuzz m off) and identifies nothing
// within CQ_opJamRadius; the crash crate (reverse engineering, permanent) or the jammer's
// destruction gives the exact position. Its AA shoots MAGPIE: she keeps clear once it is spotted.
// The mortar only fires on players its tower watcher sees (delay + spread). When the outpost falls
// (no man left), flights to that HQ come the long way round and its resupply is CQ_opSupplyDelay s later.
CQ_outpost = true;
CQ_opHqGap = 150;                        // m kept from the HQ site
CQ_opFlat = 5;                           // m of height difference allowed over the 40 x 40 m footprint
CQ_opReuse = ["Land_Cargo_Patrol_V1_F", "Land_Cargo_Patrol_V2_F", "Land_Cargo_Patrol_V3_F", "Land_Cargo_Tower_V1_F", "Land_Cargo_Tower_V2_F", "Land_Cargo_Tower_V3_F", "Land_BagBunker_Tower_F"];   // existing posts reused when on the corridor
CQ_opTower = "Land_Cargo_Patrol_V1_F";
CQ_opJammer = ["Land_TTowerSmall_2_F", "Land_TTowerSmall_1_F"];   // first that exists
CQ_opAA = ["O_static_AA_F", "O_static_AA_F"];
CQ_opHMG = ["O_HMG_01_high_F", "O_HMG_01_high_F"];   // each on its own HMG tower (cargo patrol tower), as at the HQs
CQ_opMortar = "O_Mortar_01_F";
CQ_opWatcher = "O_spotter_F";
CQ_opSquad = ["O_Soldier_SL_F", "O_Soldier_AR_F", "O_Soldier_LAT_F", "O_soldier_M_F", "O_Soldier_GL_F", "O_Soldier_F", "O_Soldier_F", "O_Soldier_AR_F"];   // scaled with CQ_scale
CQ_opSkill = 0.7;
CQ_opBoat = "O_Boat_Armed_01_hmg_F";
CQ_opBoats = 2;
CQ_opJamRadius = 600;                    // m: MAGPIE identifies nothing in there while the jammer works
CQ_opFuzz = [250, 750];                  // m: the rough area's centre is this far off the outpost
CQ_opFuzzR = 900;                        // m: radius of the rough area (the outpost is inside)
CQ_opAlert = 900;                        // m: what one man of the post sees, every man of it knows (shared by radio)
CQ_opHear = 250;                         // m: a player this close is heard even unseen
CQ_opMortarRange = 1500;                 // m: the mortar only fires on players this close
CQ_opMortarDelay = [30, 60];             // s between the watcher spotting a player and the rounds
CQ_opMortarSpread = 60;                  // m around the target
CQ_opMortarEvery = 90;                   // s between two salvos
CQ_opSupplyDelay = 600;                  // s added to that HQ's resupply flights once the outpost fell
CQ_opDetour = 4000;                      // m: flights to that HQ start this far sideways (the long way round)

// --- nGD: the enemy radio network ("break the net, take the net") -------------
CQ_netEvery = 10;                        // s between two network updates (links, isolation, map)
CQ_netCoverBase = 7000;                  // m: MAGPIE identifies enemies this close to the base...
CQ_netCoverRelay = 4000;                 // ...or this close to a relay we hold (nothing beyond: no data link)
CQ_netTrunkStub = 1500;                  // m of the trunk line drawn from a root HQ toward the carrier (its position stays unknown)
CQ_relayClass = "Land_TTowerSmall_1_F";  // the friendly relay an engineer puts up
CQ_hackTime = 20;                        // s an engineer holds "Hack radio tower" at its foot: the tower becomes our relay (no demolition)
CQ_hackRange = 15;                       // m from the tower's centre
CQ_towerGuard = ["O_Soldier_SL_F", "O_Soldier_AR_F", "O_Soldier_LAT_F", "O_soldier_M_F", "O_Soldier_GL_F", "O_Soldier_F", "O_Soldier_AR_F", "O_Soldier_F"];   // its own guard squad (scaled, out of the AI caps)
CQ_towerGuardSkill = 0.65;
CQ_relayRange = 30;                      // m from a fallen tower site to deploy a relay
CQ_relayRetakeRange = 4000;              // the nearest enemy HQ this close sends a squad to destroy a new relay
CQ_lowStockShare = 0.2;                  // HQ marker shows [low ammo] under this share of its depot cap
// player scaling (CQ_fnc_netScale): full power = 4 full squads
CQ_fullPowerPlayers = 24;
CQ_scaleMin = 0.35;                      // fewest players: 35 % of the infantry cap, waves up to twice as slow
CQ_testFullPower = true;                 // TEST: play as if CQ_fullPowerPlayers were connected (debug panel toggle)
CQ_testMagDirect = false;                // TEST ONLY, set false before merging to main: the two Sentinels fly straight to the first enemy HQ site instead of their search circuits

// --- Enemy root insertions --------------------------------------------------
CQ_maxRoots = 6;                         // root insertions in a campaign (victory after the last one)
CQ_rootInterval = 3600;                  // seconds between root insertions
CQ_firstRootDelay = 10;                  // seconds after mission start
CQ_insertionSpawnDistance = 8000;        // helis appear this far from the site
CQ_insertionFlyHeight = 80;              // default; each role has its own band below
// Altitude bands keep formations from colliding (careless transports never dodge)
CQ_heightLifter = 70;
CQ_dropPlaneClass = "I_Heli_Transport_02_F";   // CH-49 Mohawk (base game): carries a vehicle and paradrops it (own parachute)
CQ_heightDrop = 220;                     // paradrop altitude (above ground)
CQ_dropLead = 250;                       // released this far before the LZ (the canopy drifts forward)
CQ_dropCoastGap = 350;                   // paradrop LZ and release point at least this far from any water                    // Taru with a vehicle under the sling
CQ_heightTroops = 95;                    // troop / supply Taru
CQ_heightEscort = 150;                   // Orcas and Kajman above everything
CQ_formationGap = 150;                   // lateral metres between transports

// --- HQ sites and construction ---------------------------------------------
CQ_siteRadius = 40;                      // flat, empty circle needed (the composition reaches ~31 m)
CQ_objectClearance = 0.5;                // extra metres around each object's footprint
CQ_lzClearance = 14;                     // free radius for a Taru landing / vehicle drop
// Terrain objects that block a site, an object or an LZ
CQ_blockerTypes = ["TREE", "SMALL TREE", "BUSH", "ROCK", "ROCKS", "HOUSE", "BUILDING", "WALL", "FENCE",
    "CHURCH", "CHAPEL", "FUELSTATION", "HOSPITAL", "LIGHTHOUSE", "POWER LINES", "POWERSOLAR", "POWERWIND",
    "TRANSMITTER", "WATERTOWER", "RUIN", "STACK", "TOURISM", "VIEW-TOWER", "BUNKER", "FORTRESS", "FOUNTAIN", "QUAY"];
// A whole site ignores bushes (Altis is covered in them); each object and LZ still avoids them
CQ_siteBlockerTypes = CQ_blockerTypes - ["BUSH"];
// Footprint radius (m) of each composition object, used for spacing checks
CQ_objRadius = createHashMapFromArray [
    ["Land_Cargo_Patrol_V1_F", 4],
    ["Land_Cargo_HQ_V1_F", 8], ["Land_BagFence_Long_F", 1.6], ["Land_BagFence_Round_F", 1.5],
    ["Land_Cargo_House_V1_F", 3.5], ["Box_East_Ammo_F", 0.6], ["Land_TTowerBig_2_F", 3],
    ["Land_HelipadSquare_F", 5], ["O_static_AA_F", 1.2],
    ["O_Truck_02_fuel_F", 4.5], ["O_Truck_02_Ammo_F", 4.5]
];
CQ_siteMaxGradient = 0.15;
CQ_siteNoPlayerRadius = 800;
CQ_siteMinHqSpacing = 1500;
// Build truck (CQ_fnc_buildTruck): no build timer any more, each stage goes up when the truck got there
CQ_btTruckClass = "O_Truck_02_transport_F";   // Zamak: the first one comes with the root insertion's paradrop
CQ_btSquad = ["O_Soldier_SL_F", "O_Soldier_AR_F", "O_Soldier_LAT_F", "O_engineer_F", "O_engineer_F", "O_Soldier_GL_F", "O_Soldier_F", "O_Soldier_F"];   // rides in the back
CQ_btStopDist = 20;                      // m from the stage's site: the truck stops, the squad gets out
CQ_btSpawnDelay = 3;                     // s after the stop before the stage appears
CQ_btBoardTime = 25;                     // s the squad gets to board before the truck leaves (near ones are put in)
CQ_btStuck = 45;                         // s without moving 5 m: new route, then a short hop onto free ground
CQ_btLegMax = 240;                       // s per leg at most: the truck is put at its stop (safety)
CQ_btReplaceDelay = 300;                 // s before the carrier paradrops a replacement truck
CQ_btMaxDrops = 16;                      // build trucks the carrier can paradrop in the whole game (replacements + new trucks for founding HQs)
CQ_btEscortClass = "O_MRAP_02_hmg_F";    // escort of a replacement truck (Ifrit HMG, CSAT's Hunter)
CQ_btEscortMax = 3;                      // one escort more per truck the HQ lost, up to this
CQ_btKajClass = "O_Heli_Attack_02_dynamicLoadout_F";   // Kajman teaming with the build truck while an HQ is built
CQ_btKajRange = [100, 500];              // m around the truck: its scouting points
CQ_btKajEvery = [30, 40];                // s between two scouting points
CQ_btKajDelay = 300;                     // s before another Kajman joins after one is lost
CQ_hqMarkerRadius = 400;                 // approximate circle shown to players
CQ_engineerCharges = ["DemoCharge_Remote_Ammo", "DemoCharge_Remote_Ammo_Scripted", "SatchelCharge_Remote_Ammo", "SatchelCharge_Remote_Ammo_Scripted"];

// --- HQ lifecycle (realistic timings) ---------------------------------------
// Securing -> Installing -> Hold -> WaitingReinf -> split (child HQ) -> Holding -> WaitingReinf ...
CQ_activeStates = ["Inbound", "Securing", "Installing", "Hold", "Holding", "WaitingReinf"];
CQ_maxHqs = 6;                           // HQs alive at once
CQ_maxAI = 220;                          // hidden safety limit: every enemy AI alive at once (crews included)
CQ_maxInfantry = 160;                    // enemy foot soldiers alive at once (vehicle / heli / static crews not counted)
CQ_carrierHqs = 6;                       // the carrier has supplies for this many new HQs (insertions + splits), then it is empty
CQ_secureRadius = 1000;                  // squads post out to this perimeter before building
CQ_secureShare = 0.5;                    // perimeter counts as secured once every squad is this far out
CQ_secureTimeout = 60;                   // build starts anyway after 1 min (squads keep walking to their posts)
CQ_holdTime = 60;                        // hold after installation, before calling reinforcements
CQ_waveInterval = 600;                   // a new reinforcement wave every 10 min per HQ
CQ_waveSpawnDist = [1000, 1500];         // convoy spawns on a road this far from the HQ
CQ_waveNoPlayerRadius = 1000;
CQ_waveSquads = 2;
CQ_waveSize = 25;                        // AI budget reserved for one wave
CQ_wavePools = [                         // one vehicle from each pool per wave
    ["truck",  ["O_Truck_02_transport_F", "B_Truck_01_transport_F"]],
    ["armour", ["O_APC_Wheeled_02_rcws_v2_F", "I_APC_tracked_03_cannon_F", "O_APC_Tracked_02_cannon_F"]],   // Marid, Mora, BTR-K Kamysh (no DLC)
    ["random", ["O_MRAP_02_hmg_F", "O_G_Offroad_01_armed_F"]]
];
CQ_dynSimGarrison = false;               // true = HQ squads freeze when no player is near (saves CPU, but they stop patrolling)
// HQ nervousness (CQ_fnc_hqNerves), never calms down: CALM (built, no contact), WARY (contact),
// TENSE (1 objective lost), ALARMED (2), FORTRESS (3+ or commander killed / captured)
CQ_nervNames = ["CALM", "WARY", "TENSE", "ALARMED", "FORTRESS"];
CQ_nervPatrolR = [[400, 1000], [250, 700], [200, 500], [120, 300], [60, 150]];   // patrol loop radius per level (1st squad smallest)
CQ_nervSniperDist = [[800, 1200], [800, 1200], [600, 900], [400, 700], [150, 300]];   // snipers' new spots after an alarm
CQ_nervAlarmTime = 240;                  // s without a new loss before the recalled groups spread out again
CQ_patrolRadius = [250, 700];            // patrol loop radius around an HQ: 1st patrol squad smallest, then wider
CQ_vehPatrolRadius = 1200;               // HQ vehicles (Ifrit, Marid, Mora, Nyx...) roam this far around their HQ
CQ_vehRoamRefresh = 420;                 // new random roaming route every 7 min
CQ_vehRoamNetRange = 4000;               // routes also visit other built HQs this close
CQ_roamMinNormal = 0.93;                 // max slope off road (~21 deg)
CQ_roamHillRise = 18;                    // a spot this many metres above its surroundings is a hill top: avoided
CQ_vehLowFuel = 0.3;                     // ground vehicles under this drive to an HQ fuel tanker
CQ_vehFuelFullCost = 40;                 // fuel points for a full tank of a ground vehicle
CQ_fuelConsumption = 5;                  // every enemy vehicle and helicopter burns fuel this many times faster
// Guerillas: armed locals the HQ raises when stage 4 is done (vanilla FIA on the CSAT side)
CQ_guerillaSquads = 2;
CQ_guerillaSize = [6, 8];
CQ_guerillaVillageRange = 1500;          // they patrol the nearest village this close, else the HQ surroundings
CQ_guerillaLeader = "O_G_Soldier_SL_F";
CQ_guerillaClasses = ["O_G_Soldier_F", "O_G_Soldier_F", "O_G_Soldier_AR_F", "O_G_Soldier_LAT_F", "O_G_Soldier_GL_F",
    "O_G_Soldier_M_F", "O_G_medic_F", "O_G_Soldier_lite_F", "O_G_Soldier_A_F"];
CQ_balanceInterval = 60;                 // every minute, infantry is evened out over the fully built HQs
CQ_balanceMargin = 6;                    // only when an HQ is this many soldiers off the average
CQ_balanceNewBonus = 8;                  // an HQ still securing / building counts this many soldiers short: helped first
CQ_balanceMaxMoves = 3;                  // redeployments started at once after a reinforcement wave
CQ_balanceContactQuiet = 120;            // no redeployment from an HQ in contact the last 2 min
CQ_walkMaxDist = 1000;                   // closer than this, squads walk between HQs
CQ_transportPickRange = 200;             // a squad that must move takes a truck or a parked Taru only if one is this close, else it walks
CQ_heliPreferDist = 3000;                // farther than this, a helicopter is tried before a truck
CQ_watchIdle = 180;                      // a patrolling squad standing still 3 min outside combat gets a new patrol
CQ_objMinGap = 300;                      // HQ objectives (depot, radio tower, fuel tanker, 3 AA, HMG tower): at least this far from each other (relaxed if 7 never fit)
CQ_objMinR = 250;                        // ...anywhere between this far from the command building
CQ_objMaxR = 900;                        // ...and this far (inside the 1000 m AO circle)
CQ_objClearR = 12;                       // ...on a spot with no tree, bush, rock, building or object within this radius
CQ_objMaxSlope = 0.2;                    // ...and flat: max height difference ratio over that radius (isFlatEmpty gradient)
// Enemy HQ codenames (famous real operation names), one picked at random per HQ, never twice in a
// game; messages and markers show "NAME (root)", "NAME (P1)"... (rank in the network, CQ_fnc_objName)
CQ_aoRadius = 1000;                      // m: red circle hatched in black around every built enemy HQ (gone when it falls)
CQ_hqMarkerType = "loc_radio";           // enemy HQ marker icon (CfgMarkers class)
CQ_hqNames = ["ROLLING THUNDER", "URGENT FURY", "OVERLORD", "AVALANCHE", "RED DAWN", "KILLER",
    "MASHER", "JUNIPER COBRA", "HERCULES", "CARTHAGE", "EAGLE CLAW", "BEASTMASTER"];
// Enemy squad callsigns (real aviator callsigns, aggressive ones), given in this order to every
// enemy squad (CQ_fnc_callsignTick); a wiped-out squad frees its name for the next one; numbers
// ("Viper 2") only when every name is in use at once
CQ_enemyCallsigns = ["Viper", "Talon", "Ghost", "Hammer", "Bandit", "Hawk", "Tank", "Dozer", "Badger", "Bear",
    "Barracuda", "Beast", "Blackjack", "Blaze", "Bone-Saw", "Bloodlust", "Butcher", "Bullet", "Boomslang", "Bison",
    "Blindside", "Butane", "Bam-Bam", "Lasher", "Lazer", "Snake", "Smoke", "Toro", "Chaos", "Steel Rain",
    "Dead Walker", "Skull", "Xerxes", "Mad Dog", "Giant Killer", "Fatal"];
CQ_cmdEscortClasses = ["O_recon_TL_F", "O_recon_F", "O_recon_F", "O_recon_M_F", "O_recon_LAT_F", "O_recon_medic_F"];   // elite squad always around each enemy HQ commander
CQ_cmdEscortSkill = 0.8;
CQ_objGuardSize = 3;                     // ...each site guarded by this many soldiers taken from the HQ patrols
CQ_hmgTowerDir = 270;                    // HMG watchtower built when an HQ is finished: compass direction from the HQ (270 = west)
CQ_hmgTowerDist = 45;                    // ...and distance
// Enemy support teams: one medic team, one engineer team, dropped again after destruction
CQ_specialVehicle = "I_MRAP_03_hmg_F";   // Strider HMG
CQ_specialFirstDelay = 40;               // first drop: 40 s after the first Blackfish drop of the game
CQ_specialRespawn = 900;                 // a wiped-out team is dropped again 15 min later
CQ_specialRespawns = 3;                  // ...at most this many times per team (first drop not counted)
CQ_specialRange = 6000;
// Snipers: with every carrier insertion, CQ_snipersPerWave snipers on high ground on the HQ's
// west side, driven by the medic and engineer teams to CQ_sniperDrop m short of their spots
CQ_snipersPerWave = 4;
CQ_sniperClass = "O_sniper_F";           // falls back to the marksman if missing or DLC
CQ_sniperSeats = 2;                      // Strider cargo seats each team keeps free for them
CQ_sniperDist = [800, 1200];             // m from the HQ
CQ_sniperArc = [200, 340];               // bearings from the HQ (west side)
CQ_sniperGap = 200;                      // m between two spots
CQ_sniperDrop = 200;                     // m short of the spots where the team drops them
CQ_sniperWait = 1200;                    // s: a job no team has taken by then is done on foot                  // how far a team drives for a job
// HUNTERS: CSAT special forces sent after the player squad hurting an HQ (CQ_fnc_huntLaunch)
CQ_huntTeams = 3;                        // per carrier, one alive at a time (not shown on the carrier marker)
CQ_huntClasses = ["O_recon_TL_F", "O_recon_F", "O_recon_F", "O_Soldier_AR_F", "O_recon_LAT_F", "O_recon_medic_F"];
CQ_huntHaloAlt = 2500;                   // m: HALO jump altitude
CQ_huntChuteAlt = 150;                   // m: chute opened
CQ_huntDropDist = [1500, 2500];          // m from the target squad
CQ_huntUpdate = [120, 180];              // s between two position updates on the target
CQ_huntFuzz = 300;                       // m of error on the target position (exact once they know one of them)
CQ_huntTime = 1800;                      // s of hunt, then front-line patrol
CQ_huntPatrolR = 600;                    // m: patrol around the western-most HQ
CQ_huntSpotChance = 0.25;                // MAGPIE identification chance per pass
CQ_huntBounty = 150;                     // squad points for wiping a team out
CQ_medicHealAbove = 0.25;                // soldiers hurt more than this get treated
// Radio direction finder (players with a radio): signal from enemy HQ radios
CQ_rdfRange = 6000;                      // no signal beyond this
CQ_rdfTop = 40;                          // signal panel: px from the top of the screen (centred)
CQ_playerMapMarkers = false;             // true = enemy HQ areas and the carrier shown on the players' map
// Base defence spots (AA + HMG, NATO gunners), around the camp, off the runway
CQ_baseDefAngles = [45, 225, 315];       // relative to the camp front (135 removed: it sat on the taxiway the drones use)
CQ_baseDefRadius = 230;
CQ_runwayClear = 250;                    // no base defence spot within this distance of the runway centre line (taxiways, aprons)
CQ_baseDefRespawn = 600;                 // a lost spot is rebuilt 10 min later
// Supply crates at the base (load them into any vehicle)
CQ_crateClass = "B_supplyCrate_F";
CQ_crateCount = 6;
CQ_crateCleanup = 600;                   // empty crates far from the base removed after 10 min
CQ_crateRoles = ["B_Soldier_SL_F", "B_medic_F", "B_soldier_AR_F", "B_soldier_LAT_F", "B_engineer_F", "B_Soldier_F", "B_Helipilot_F"];
CQ_crateExtraMags = [["HandGrenade", 12], ["MiniGrenade", 6], ["SmokeShell", 12], ["SmokeShellGreen", 6], ["SmokeShellRed", 4],
    ["1Rnd_HE_Grenade_shell", 16], ["1Rnd_Smoke_Grenade_shell", 6], ["NLAW_F", 3], ["DemoCharge_Remote_Mag", 6],
    ["SatchelCharge_Remote_Mag", 2], ["APERSMine_Range_Mag", 4], ["Chemlight_green", 6],
    // launcher rounds (base game only): RPG-42, Titan AT
    ["RPG32_F", 5], ["RPG32_HE_F", 3], ["Titan_AT", 2]];
// Rifle, DMR / sniper and machine-gun ammunition for the base-game weapons (no DLC, no pistols):
// MX, Katiba, TRG/Mk20, Mk18, SDAR, Rahim, LRR, Lynx, MX SW, Mk200, Zafir
CQ_crateRifleMags = [
    // assault rifles
    ["30Rnd_65x39_caseless_mag", 8], ["30Rnd_65x39_caseless_green", 8], ["30Rnd_556x45_Stanag", 8], ["20Rnd_762x51_Mag", 6],
    ["20Rnd_556x45_UW_mag", 4],
    // DMR / sniper
    ["10Rnd_762x54_Mag", 4],
    ["7Rnd_408_Mag", 4], ["5Rnd_127x108_Mag", 4],
    // machine-gun belts / boxes
    ["100Rnd_65x39_caseless_mag", 3], ["200Rnd_65x39_cased_Box", 3], ["150Rnd_762x54_Box", 3]
];
// launchers in every crate / auto-fill (one of each, for the rounds above)
CQ_crateWeapons = [["launch_RPG32_F", 1], ["launch_O_Titan_short_F", 1]];   // base game launchers (NLAW rounds come with the AT class)
CQ_crateItems = [["FirstAidKit", 24], ["Medikit", 2], ["ToolKit", 2], ["MineDetector", 1]];
CQ_loadZoneCount = 4;                    // loadout zones in the base parking area (auto-fill vehicles)
CQ_loadZoneRadius = 9;
// Classes taken in game (every lobby slot is a Rifleman): [label, config class for the loadout, traits]
// [label, unit class (loadout), traits, max players in that class]
// UI design: dark theme from the project colour chart (no dark green): charcoal-olive panels,
// cream text. Buttons (class CQ_Button, description.ext): dark, olive on hover AND when active
// (focused/pressed: the same colour, no mismatch), red when selected (CQ_fnc_uiSel).
//   chart: #918C3B olive   #A6A381 light brown   #F2F1DF cream   #BA392C red
CQ_ui = createHashMapFromArray [
    ["font", "PuristaMedium"], ["fontHead", "PuristaSemibold"], ["fontLight", "PuristaLight"],
    ["panel", [0.07, 0.068, 0.05, 0.97]], ["header", [0.15, 0.146, 0.098, 1]], ["inset", [0, 0, 0, 0.55]],
    ["button", [0.2, 0.192, 0.122, 1]], ["buttonHover", [0.569, 0.549, 0.231, 1]], ["buttonOn", [0.729, 0.224, 0.173, 1]],
    ["buttonActive", [0.949, 0.945, 0.875, 1]], ["textOn", [0.949, 0.945, 0.875, 1]],
    ["text", [0.949, 0.945, 0.875, 1]], ["muted", [0.651, 0.639, 0.506, 1]], ["dim", [0.45, 0.44, 0.35, 1]],
    ["accent", [0.569, 0.549, 0.231, 1]], ["alert", [0.729, 0.224, 0.173, 1]], ["warn", [0.651, 0.639, 0.506, 1]]
];   // hex on dark backgrounds: text #F2F1DF, muted #A6A381, accent #918C3B, dim #7A7860, alert #BA392C
CQ_splashEnabled = false;                 // POC splash before the intro: black, picture centred, text under it
CQ_splashWidth = 0.8;                    // picture width, share of the screen width
CQ_splashTime = 4;                       // s (Space ends it)
CQ_introEnabled = false;                 // cinematic at join: black + typed time/place, satellite, coast, flight, landing, eyes (CQ_fnc_intro)
CQ_introShots = [8, 8, 8, 8];            // s per shot: satellite, coast, squad on a hilltop, landing (on the shop pad)
CQ_introScene = -1;                      // squad shot: -1 random, or 0 attack, 1 retreat, 2 report, 3 sneak, 4 ambush
CQ_introFade = 1;                        // s per fade (out, and in) between shots; the end is a blink
CQ_introSatAlt = 1300;                   // m: satellite shot altitude (under the clouds)
CQ_introViewDist = 7000;                 // m: view distance during the satellite shot only
CQ_introHoverTop = 7;                    // landing shot: the Hummingbird descends from this height...
CQ_introPrewarm = 3.5;                   // s: the landing (movement + engine sound) starts this long before the picture opens
CQ_introLoadPause = 1;                   // s on black after the loading screen, before the typing starts
CQ_introHoverLow = 2.1;                  // ...to this (about 1 m above the pad), never touching
CQ_introMaxTime = 90;                    // s: watchdog, the intro is cleaned up whatever happens
CQ_startAfterIntro = 5;                  // s after the FIRST player's intro: the mission starts
CQ_introPlace = "ALTIS  ·  AEGEAN SEA  ·  AAC AIRFIELD";   // typed on black before the shots, under the time and date
CQ_introTypeDelay = 0.06;               // s per typed letter
CQ_menuSize = 0.85;                      // U menu: transceiver picture height (share of the screen height)
CQ_menuOverhang = 0.18;                  // share of the picture pushed past the right screen edge (the side connectors go off screen)
CQ_sqSize = 0.85;                        // squads / class / stats window: field tablet picture height (share of the screen height), centred
CQ_sqScreen = [0.2773, 0.2672, 0.7920, 0.7719];   // its green screen zone in the picture (fractions), under the status bar, right of the icon column
CQ_sqTint = 0.72;                        // opacity of the dark tint over the green screen (readability)
CQ_menuScreen = [0.4102, 0.4062, 0.7070, 0.5410];   // its green screen zone in the picture (fractions), under the status bar, right of the icon column
CQ_bleedOut = 300;                       // s a downed player waits for a medic (ReviveBleedOutDelay in description.ext)
CQ_surgeChance = 0.10;                   // adrenalineSurge: chance for a downed medic to get up on his own over the whole wait
CQ_bleedMedicRange = 500;                // BLEEDOUT (give up and respawn) only allowed with no medic this close
CQ_bleedKey = 48;                        // B
CQ_surgeEvery = 30;                      // s between two small rolls (1.05 % each for 10 % over 5 min)
CQ_basicKit = ["ItemGPS", "ItemMap", "ItemCompass", "ItemRadio"];   // linked on every preset, plus binoculars (CQ_fnc_basicKit)
CQ_classes = [
    ["Rifleman",        "B_Soldier_F",      [],                                  26],
    ["Squad Leader",    "B_Soldier_SL_F",   [],                                  4],
    ["Medic",           "B_medic_F",        ["Medic"],                           4],
    ["Grenadier",       "B_Soldier_GL_F",   [],                                  4],
    ["Autorifleman",    "B_soldier_AR_F",   [],                                  4],
    ["Light Anti-Tank", "B_soldier_LAT_F",  [],                                  4],
    ["Heavy Anti-Tank", "B_soldier_AT_F",   [],                                  2],
    ["Anti-Air",        "B_soldier_AA_F",   [],                                  2],
    ["Engineer",        "B_engineer_F",     ["Engineer", "explosiveSpecialist"], 4],
    ["Sniper",          "B_sniper_F",       [],                                  2],
    ["Pilot",           "B_Helipilot_F",    [],                                  4]
];
// Class kits, topped up over the vanilla loadout of each class (CQ_fnc_classKit):
// [primary mags carried, launcher rounds total (loaded + carried), [[item, count], ...], backpack if none ("" = none)]
// Everyone also gets a P07 with 3 mags and the CQ_basicKit items.
CQ_classKit = createHashMapFromArray [
    ["Rifleman",        [10, 0, [["HandGrenade", 2], ["SmokeShell", 2], ["FirstAidKit", 2]], "B_AssaultPack_mcamo"]],
    ["Squad Leader",    [10, 0, [["HandGrenade", 2], ["SmokeShell", 4], ["SmokeShellBlue", 2], ["SmokeShellGreen", 2], ["SmokeShellRed", 1], ["1Rnd_HE_Grenade_shell", 6], ["FirstAidKit", 2], ["Laserbatteries", 2], ["Laserdesignator", 1]], "B_AssaultPack_mcamo"]],
    ["Medic",           [10, 0, [["Medikit", 1], ["FirstAidKit", 18], ["SmokeShell", 6], ["HandGrenade", 2]], "B_Kitbag_mcamo"]],
    ["Grenadier",       [10, 0, [["1Rnd_HE_Grenade_shell", 14], ["1Rnd_Smoke_Grenade_shell", 4], ["HandGrenade", 2], ["SmokeShell", 2], ["FirstAidKit", 2]], "B_Kitbag_mcamo"]],
    ["Autorifleman",    [6, 0, [["HandGrenade", 2], ["SmokeShell", 2], ["FirstAidKit", 2]], "B_Kitbag_mcamo"]],
    ["Light Anti-Tank", [8, 3, [["HandGrenade", 2], ["SmokeShell", 2], ["FirstAidKit", 2]], "B_Kitbag_mcamo"]],
    ["Heavy Anti-Tank", [8, 2, [["Titan_AP", 1], ["HandGrenade", 2], ["SmokeShell", 2], ["FirstAidKit", 2]], "B_Carryall_mcamo"]],
    ["Anti-Air",        [8, 3, [["HandGrenade", 2], ["SmokeShell", 2], ["FirstAidKit", 2]], "B_Carryall_mcamo"]],
    ["Engineer",        [10, 0, [["ToolKit", 1], ["MineDetector", 1], ["DemoCharge_Remote_Mag", 3], ["SatchelCharge_Remote_Mag", 1], ["HandGrenade", 2], ["SmokeShell", 2], ["FirstAidKit", 2]], "B_Kitbag_mcamo"]],
    ["Sniper",          [9, 0, [["HandGrenade", 2], ["SmokeShell", 2], ["FirstAidKit", 2], ["Rangefinder", 1]], "B_AssaultPack_mcamo"]],
    ["Pilot",           [5, 0, [["SmokeShellBlue", 2], ["FirstAidKit", 2]], ""]]
];
CQ_classSidearm = ["hgun_P07_F", "16Rnd_9x21_Mag", 3];
// Class gear (CQ_fnc_classKit), applied over the vanilla loadout before the kit above:
// [primary, [attachment choices, ...], launcher, uniform, vest, headgear]
//   attachment choice: one class or a list (the first that exists, is not DLC and fits the weapon)
//   "" keeps the vanilla item, "-" removes it. Anything tagged DLC is skipped (vanilla kept).
// Everyone also gets CQ_classNvg. Suppressors on every weapon that takes one.
private _mx = ["muzzle_snds_H", "acc_pointer_IR"];
CQ_classGear = createHashMapFromArray [
    ["Rifleman",        ["arifle_MX_F",    _mx + ["optic_Hamr", "bipod_01_F_snd"], "",                       "U_B_CombatUniform_mcam", "V_PlateCarrier2_rgr",    "H_HelmetSpecB"]],
    ["Squad Leader",    ["arifle_MX_GL_F", _mx + ["optic_Arco"],                   "",                       "U_B_CombatUniform_mcam", "V_PlateCarrierGL_rgr",   "H_HelmetSpecB"]],
    ["Medic",           ["arifle_MXC_F",   _mx + ["optic_Holosight"],              "",                       "U_B_CombatUniform_mcam", "V_PlateCarrier2_rgr",    "H_HelmetSpecB"]],
    ["Grenadier",       ["arifle_MX_GL_F", _mx + ["optic_Arco"],                   "",                       "U_B_CombatUniform_mcam", "V_PlateCarrierGL_rgr",   "H_HelmetSpecB"]],
    ["Autorifleman",    ["LMG_Mk200_F",    ["muzzle_snds_H_MG", "acc_pointer_IR", "optic_Hamr", "bipod_01_F_snd"], "", "U_B_CombatUniform_mcam", "V_PlateCarrierSpec_rgr", "H_HelmetSpecB"]],
    ["Light Anti-Tank", ["arifle_MX_F",    _mx + ["optic_Hamr", "bipod_01_F_snd"], "launch_NLAW_F",          "U_B_CombatUniform_mcam", "V_PlateCarrier2_rgr",    "H_HelmetSpecB"]],
    ["Heavy Anti-Tank", ["arifle_MX_F",    _mx + ["optic_Hamr", "bipod_01_F_snd"], "launch_B_Titan_short_F", "U_B_CombatUniform_mcam", "V_PlateCarrier2_rgr",    "H_HelmetSpecB"]],
    ["Anti-Air",        ["arifle_MX_F",    _mx + ["optic_Hamr", "bipod_01_F_snd"], "launch_B_Titan_F",       "U_B_CombatUniform_mcam", "V_PlateCarrier2_rgr",    "H_HelmetSpecB"]],
    ["Engineer",        ["arifle_MXC_F",   _mx + ["optic_Holosight"],              "",                       "U_B_CombatUniform_mcam", "V_PlateCarrier2_rgr",    "H_HelmetSpecB"]],
    ["Sniper",          ["srifle_GM6_F",   [["optic_LRPS", "optic_SOS"], "bipod_01_F_snd"], "",            "U_B_GhillieSuit",        "V_Chestrig_rgr",         "-"]],
    ["Pilot",           ["arifle_MXC_F",   _mx + ["optic_Holosight"],              "",                       "",                       "",                       ""]]
];
CQ_classNvg = "NVGoggles";
// Arsenal (open to everyone, CQ_fnc_arsenalOpen): role gear is only offered to its classes
// [tags, classes allowed]. A tag is an item type from BIS_fnc_itemType (either part), or:
//   "GL"      rifles with a grenade launcher
//   "@name"   items whose class name contains "name" (case ignored)
// Magazines are never gated (rockets, missiles, belts, charges...): anyone carries ammo for the squad.
// The class's own starting loadout stays usable whatever the gates (it is on the player).
CQ_arsenalGates = [
    [["Launcher", "MissileLauncher", "RocketLauncher"], ["Light Anti-Tank", "Heavy Anti-Tank", "Anti-Air"]],
    [["MachineGun"],                                    ["Autorifleman"]],
    [["SniperRifle"],                                   ["Sniper"]],
    [["GL"],                                            ["Squad Leader", "Grenadier"]],
    [["Medikit"],                                       ["Medic"]],
    [["Toolkit"],                                       ["Engineer"]],
    [["MineDetector"],                                  ["Engineer"]],
    [["LaserDesignator", "@Laserdesignator"],           ["Squad Leader"]],
    [["@Rangefinder"],                                  ["Squad Leader", "Sniper", "Light Anti-Tank", "Heavy Anti-Tank", "Anti-Air"]],
    [["UAVTerminal", "@UAV_"],                          []],        // no drones for soldiers: only MAGPIE flies them
    [["@Ghillie"],                                      ["Sniper"]],
    [["@PilotHelmet", "@PilotCoveralls", "@HeliPilotCoveralls"], ["Pilot"]]
];
CQ_inviteTimeout = 30;                   // s before an unanswered squad invite expires
CQ_classChangeRange = 2;                 // classes are changed inside the HQ compound walls (+ this margin, m)
CQ_squadNames = ["Alpha", "Bravo", "Charlie", "Delta", "Echo", "Foxtrot", "Golf", "Hotel", "India", "Juliet"];   // names given to new player squads
// Contact / heavy support
CQ_helpRadius = 700;                     // patrolling squads this close to a contact join in
CQ_flareWindow = 120;                    // the spotting squad wiped (to CQ_flareLossShare) within this -> red flare
CQ_flareLossShare = 0.4;                 // ...i.e. 60% of it lost
CQ_flareGarrisonShare = 0.3;             // heavy support: 30% of the HQ garrison to the flare
CQ_flareRecallRange = 2500;              // half of the roaming squads within this fall back to the HQ
CQ_flareCooldown = 600;
CQ_rootDefendCooldown = 1200;            // contact at a root HQ: all its child HQs rally (once per 20 min)
CQ_colonistShare = 0.7;                  // share of infantry leaving to found a child HQ
CQ_colonistArrivalShare = 0.6;           // a child HQ starts securing once 60% of its colonists are on site
CQ_minInfantryToExpand = 16;
CQ_minDefenders = 8;                     // never send away the last 8 infantry of an HQ
CQ_childDistance = [1600, 2400];         // child HQ ~2 km from its parent

// --- Contact, comms and QRF ---------------------------------------------------
CQ_contactRadius = 1500;                 // a group must spot players within this of its HQ
CQ_contactCooldown = 240;                // one call per HQ every 4 min
CQ_commsRange = 3000;                    // two HQs are linked when both radios stand within this
CQ_qrfShares = [[1000, 0.5], [2000, 0.3], [3000, 0.15]];   // [distance to contact, share of available troops]
CQ_qrfTime = 600;                        // a QRF hunts 10 min, then returns to patrol its HQ
CQ_hqHeliClass = "O_Heli_Light_02_dynamicLoadout_F";       // PO-30 Orca parked behind each HQ
CQ_heliHuntTime = 360;                   // an armed heli hunts 6 min, then returns

// --- Ammo: what each shooter carries ------------------------------------------
CQ_infMags = 8;                          // rifle magazines carried (+1 loaded), ~10 max
CQ_infBelts = 3;                         // MG belts
CQ_infRockets = 1;                       // spare launcher rockets
CQ_vehSpawnAmmo = 0.5;                   // ground vehicles arrive half loaded
CQ_vehRearmTo = 0.8;
CQ_lowAmmo = 0.35;                       // infantry under this: go rearm at the nearest stocked HQ
CQ_vehLowAmmo = 0.25;
CQ_airLowAmmo = 0.15;
CQ_minAmmoToAdvance = 0.5;               // under this a group never joins a QRF or a colonisation
// Ammo points (AP) cost: rifle mag 1, MG belt 3, rocket 5; vehicles: cost of a full reload
CQ_costMag = 1; CQ_costBelt = 3; CQ_costRocket = 5;
CQ_vehFullCost = createHashMapFromArray [["static", 40], ["air", 120], ["armour", 150], ["light", 60]];

// --- Depots and supply chain --------------------------------------------------
CQ_depotCap = 400;                       // ammo points an HQ depot can hold
CQ_hubCap = 1500;                        // main HQ (oldest standing HQ) depot
CQ_rootStartStock = 300;                 // brought by a root insertion
CQ_childCarryShare = 0.3;                // colonists take this share of the parent's stock...
CQ_childCarryMax = 150;                  // ...capped
CQ_rearmRadius = 60;                     // units this close to a depot get rearmed...
CQ_rearmUnitBelow = 0.7;                 // ...a soldier only under 70% of his magazines
CQ_rearmVehBelow = 0.5;                  // ...a vehicle only under 50% (statics 60%)
CQ_rearmMinStock = 20;
CQ_rearmWaitMax = 240;                   // a group waiting at a depot goes back to work after 4 min, rearmed or not
CQ_infReserve = 80;                      // ammo points kept for infantry: vehicles, statics and helis only use what is above
CQ_hubLowShare = 0.15;                   // main HQ under 15% of its cap...
CQ_hubLowFlightDelay = 180;              // ...the next supply flight leaves within 3 min                   // an HQ with less is not a rearm destination
CQ_logiTickSeconds = 15;
CQ_requestShare = 0.4;                   // an HQ under 40% of its cap requests a truck
CQ_truckClass = "B_Truck_01_ammo_F";     // HEMTT ammo, spawned at the main HQ
CQ_truckLoad = 200;
CQ_trucksMax = 3;
CQ_hubReserve = 150;                     // the main HQ never ships its last 150 AP
CQ_ammoFlightInterval = 1200;            // an ammo flight to the main HQ every 20 min
CQ_ammoFlightLoad = 600;
CQ_ammoFlightClass = "I_Heli_Transport_02_F";   // CH-49 Mohawk (base game) carries the ammo/fuel resupply
CQ_troopHeliClass = "I_Heli_Transport_02_F";    // CH-49 Mohawk (base game) for troop insertions (was the Taru, DLC)

// --- Fuel (aircraft) ---------------------------------------------------------
// Depots also store fuel points (FP): a full refuel of a helicopter costs CQ_fuelFullCost.
CQ_airLowFuel = 0.25;                    // under this a heli flies to the nearest HQ with fuel
CQ_airMinFuelToHunt = 0.4;               // under this it never goes hunting
CQ_fuelFullCost = 100;
CQ_rootStartFuel = 200;
CQ_flightFuelLoad = 400;                 // brought by each supply flight to the main HQ
CQ_truckFuelLoad = 150;                  // carried by each HEMTT next to its ammo
CQ_hubFuelReserve = 100;
CQ_rearmMinFuel = 15;                    // an HQ with less is not a refuel destination
CQ_tankerClass = "O_Truck_02_fuel_F";    // Zamak fuel tanker parked in every HQ: it HOLDS the HQ's fuel
CQ_fieldTruckClass = "O_Truck_02_Ammo_F"; // Zamak ammo truck parked in every HQ: field resupply
CQ_fieldResupplyMin = 400;               // a low group farther than this from its depot gets the truck...
CQ_fieldResupplyRange = 2000;            // ...if it is within this
CQ_fieldResupplyLoad = 100;              // ammo points the field truck takes out

// --- Air fleet --------------------------------------------------------------
CQ_escortClasses = ["O_Heli_Light_02_dynamicLoadout_F", "O_Heli_Light_02_dynamicLoadout_F", "O_Heli_Attack_02_dynamicLoadout_F"];
CQ_fleetMax = 12;                        // helicopters under the air manager (each parks at its own HQ)
CQ_airPatrolRest = [60, 180];           // an armed heli rests this long on its pad between patrols
CQ_airPatrolTime = [240, 480];           // one patrol sortie lasts this long
CQ_airPatrolRadius = [600, 1400];        // patrol ring around the HQ
CQ_airPatrolHeight = [70, 170];          // random altitude per sortie (spreads the helis out)
CQ_airPatrolMinFuel = 0.5;               // under this it stays parked (or goes to refuel)
CQ_airPatrolShare = 0.7;                 // at most this share of armed helis in the air on patrol (the rest = ready QRF)
CQ_airPatrolHqs = 3;                     // a patrol sweeps its home HQ + 1..3 other HQs of the network
CQ_airPatrolPerHq = 120;                 // +2 min of sortie per extra HQ on the route
CQ_airBalanceInterval = 60;              // armed helicopters re-based to even them out over the built HQs
CQ_airPatrolBaseGap = 2000;              // patrol points never closer than this to the player base
CQ_airQrfMax = 2;                        // armed helis sent on one contact
CQ_airQrfRange = 4000;
CQ_airRearmTime = 60;

// --- DEBUG overrides (set CQ_debug = false above for the real campaign) -----
if (CQ_debug) then {
    CQ_debugFirstAtRunway = false;       // true: 1st root lands at the runway end (marker "cq_debug_site" overrides)
    CQ_firstRootDelay = 30;
    CQ_insertionSpawnDistance = 3500;
    CQ_secureTimeout = 90;
    CQ_baseNoSpawnRadius = 1200;         // the runway HQ is only ~900 m from the base
    CQ_waveInterval = 300;
    CQ_ammoFlightInterval = 300;
} else {
    CQ_debugFirstAtRunway = false;
};

// --- Roles ----------------------------------------------------------------
CQ_pilotClasses = ["B_Helipilot_F"];     // only these may fly aircraft
CQ_engineerClasses = ["B_engineer_F"];   // get engineer + explosiveSpecialist traits

// Player statistics (in memory only, wiped by a server restart)
// stat keys, in the order CQ_statsPub carries them
CQ_statKeys = ["killsInf", "vehLight", "vehArmor", "vehAir", "vehStatic", "deaths", "teamkills", "longest",
    "objTower", "objDepot", "objCmdKilled", "objCmdCaptured", "objPoints", "heals", "shots", "distFoot", "distVeh", "timePlayed"];
// score = sum of stat x weight (objPoints are already points)
CQ_statWeights = [["killsInf", 10], ["vehLight", 20], ["vehArmor", 40], ["vehAir", 50], ["vehStatic", 10],
    ["objPoints", 1], ["heals", 5], ["teamkills", -50]];

// Vehicle shop (squad leaders spend their SQUAD combat points)
// squad points: members' combat actions, worth (stat x weight); team kills cost points
CQ_squadPointWeights = [["killsInf", 10], ["vehLight", 20], ["vehArmor", 40], ["vehAir", 50], ["vehStatic", 10],
    ["objPoints", 1], ["teamkills", -50]];
// [class, cost, name, short description]  - base game only (a DLC class is hidden automatically)
CQ_shopCatalog = [
    ["B_G_Offroad_01_AT_F",              120, "Offroad AT",      "Pickup with an SPG-9 recoilless rifle. Fast, fragile."],
    ["B_MRAP_01_hmg_F",                  150, "Hunter HMG",      "MRAP, .50 cal turret. Good all-rounder."],
    ["I_MRAP_03_hmg_F",                  170, "Strider HMG",     "MRAP, .50 cal turret, better armour."],
    ["B_MRAP_01_gmg_F",                  220, "Hunter GMG",      "MRAP, 40 mm grenade machine gun."],
    ["B_APC_Tracked_01_rcws_F",          400, "IFV-6c Panther",  "Tracked APC, HMG + GMG, carries a squad."],
    ["B_APC_Wheeled_01_cannon_F",        550, "AMV-7 Marshall",  "Wheeled IFV, 40 mm cannon, carries a squad."],
    ["B_Heli_Light_01_dynamicLoadout_F", 600, "AH-9 Pawnee",     "Light attack helicopter, guns + rockets. Needs a pilot."]
];
CQ_shopMaxPerSquad = 1;                  // bought vehicles alive at the same time per squad
CQ_shopRange = 6;                        // metres from the shop terminal to use it

// MAGPIE - friendly UAV recon (CQ_fnc_magInit / CQ_fnc_magTick)
// [callsign / airframe name, classes (first available, no DLC), flight altitude m, ellipse scale]
// The two large drones are Greyhawk airframes named Sentinel_Argos (low) and Sentinel_Hermes
// (high, wider sensor); the Sentinel UCAV itself needs the Jets DLC. Weapons are removed: MAGPIE only looks.
CQ_magDrones = [
    ["Darter",   ["B_UAV_01_F"],                                  250, 0.8],
    ["Sentinel_Argos",  ["B_UAV_02_dynamicLoadout_F", "B_UAV_02_F"],     900, 1.2],
    ["Sentinel_Hermes", ["B_UAV_05_F", "B_UAV_02_dynamicLoadout_F", "B_UAV_02_F"], 1500, 1.6]
];
CQ_magFirstDelay = 5;                    // s after mission start: first take-off (the carrier arrives at start)
CQ_magPadDist = 200;                     // m behind the HQ compound: the Darters' take-off field (grid of pads)
CQ_magPadGap = 12;                       // m between two Darter pads
CQ_magStuckTime = 20;                    // s still on the ground before a drone is nudged forward
CQ_magRespawn = 480;                     // s before a lost drone is replaced (8 min), on the runway
CQ_magReportEvery = 120;                 // s between two MAGPIE reports (only if something is new)
// MAGPIE photos: every new enemy (vehicle or soldier) identified is photographed along the drone's line of
// sight (render to texture, 64x64) and shown in a grid under the next report
CQ_magReportVehMax = 8;                  // MAGPIE report: vehicle lines listed per category (GROUND / AIR), then "+N more"
CQ_magPhotos = false;                    // photo grid under MAGPIE reports (off: text reports only, no cameras)
CQ_magPhotoMax = 8;                      // photos per report at most (4 per row)
CQ_magPhotoSlots = 24;                   // render textures reused in turn (cq_ph_0..23)
CQ_magPhotoFov = 0.7;                    // camera field of view (zoom) for the stills
CQ_magPhotoDist = 12;                    // m from a vehicle, along the drone's line of sight
CQ_magPhotoDistInf = 3;                  // m from a soldier
// (a thumbnail is the drone's view of the target while the card is on screen: Arma clears a render
// texture once its camera is gone, so a frozen still is not possible; the preview shows while the map is open)
CQ_magPhotoBorder = 3;                   // frame thickness around each thumbnail, px
CQ_magPhotoPx = 64;                      // square thumbnail size on the card and render texture size, px
CQ_magPhotoAspect = 4 / 3;               // the camera's own ratio (it renders it squeezed into the square texture): the picture is unsqueezed to it, then centre-cropped to the square (raise it if things still look too thin)
CQ_magMarkerTime = 10;                   // s the report dots stay on the map
CQ_magDetectEvery = 4;                   // s between two detection passes
CQ_magPlanEvery = 90;                    // s between two flight plans of a drone
// scan chain: CQ_magChainCount extra Darters fan out from the base to a north-south line and
// sweep it east across the island, spread over the land at each step (no slot over the sea)
CQ_magChainCount = 0;                    // allaroundisland: replaced by the dormant Darters below
CQ_magChainAlt = 250;                    // m
CQ_magChainStep = 600;                   // m the line moves east each step
CQ_magChainStepTime = 90;                // s max per step (moves on earlier once 70 % of the chain is in place)
// encirclement: the first identified contact becomes the focus; every airborne drone takes a
// sector of a ring around it, the ring turns slowly and tightens (risking the Tigris)
CQ_magRingStart = 3000;                  // m ring radius at first contact
CQ_magRingMin = 700;                     // m tightest ring
CQ_magRingShrink = 120;                  // m per minute the ring tightens
CQ_magRingTurn = 0.5;                    // deg per second the ring turns (a full turn in 12 min)
CQ_magOsc = [0.3, 240];                  // Sentinels loiter radius around a contact: +/- 30 %, one swing every 240 s
CQ_magChecksPerPass = 30;                // line-of-sight checks per drone and detection pass (was 60)
CQ_magCentreEvery = 30;                 // s: the encirclement centre is re-evaluated (first ground contact -> largest group -> radio tower)
CQ_magClusterR = 600;                    // m: positions this close form a group
CQ_magCentreMove = 300;                  // m: the drones re-route only if the centre moves more than this
CQ_magFocusQuiet = 300;                  // s without a new contact in the ring (once tight) -> next focus
CQ_magCoastGap = 1500;                   // keep this far from the coast facing the carrier group
CQ_magArea = [1500, 1500, 29500, 29500]; // area she sweeps: all of Altis [xmin, ymin, xmax, ymax]
// Dormant Darters (CQ_fnc_magDormant): MAGPIE has Darters grounded all over the island, every
// CQ_magDormantGap m on land (coordinates only, no objects). A ground enemy passing within
// CQ_magDormantWake m of one wakes it: a Darter takes off right there, first gets away from the
// enemy to more than 80 % of its sensor range, then joins the fleet. Each point wakes once.
// A woken Darter destroyed is replaced from the nearest point left, after CQ_magDormantReplace s.
// Woken Darters also relay MAGPIE's data link (CQ_netCoverRelay around them).
CQ_magDormant = true;
CQ_magDormantGap = 500;                  // m between two points (grid)
CQ_magDormantWake = 500;                 // m: a ground enemy this close wakes the point
CQ_magDormantBase = 2500;                // m: no point this close to the player base
CQ_magDormantMax = 6;                    // woken Darters alive at once, at most
CQ_magDormantAlt = 250;                  // m flight altitude (sensor ~600 m)
CQ_magDormantFlee = 0.9;                 // flee until this fraction of the sensor range from the enemy (> 80 %)
CQ_magDormantReplace = 60;               // s before a destroyed woken Darter is replaced
CQ_magDormantRelay = true;               // woken Darters extend the data link like a relay
CQ_magCell = 1000;                       // search grid cell (m)
CQ_magMemory = 600;                      // s an identified position is kept for the flight plans
CQ_magSensor = [300, 1.2, 2400];         // sensor radius = 300 + altitude x 1.2, max 2400 m (Darter ~600, Sentinel_Argos ~1380, Sentinel_Hermes ~2100)
CQ_magSpotChance = createHashMapFromArray [["inf", 0.6], ["static", 0.7], ["light", 0.8], ["armour", 0.85], ["air", 0.9]];   // chance per pass to identify a new contact in sight
CQ_magAaClasses = ["O_APC_Tracked_02_AA_F"];   // anti-air MAGPIE keeps away from once identified (HQ AA guns are a plain risk)
CQ_magAaAvoid = 2500;                    // m kept from the last known position of a Tigris (its missiles reach ~4 km: a moved Tigris is deadly)
CQ_magAoRange = 2500;                    // a contact belongs to the nearest known AO within this range
// Tigris: one long-range anti-air vehicle paradropped with each carrier insertion; it roams the HQ network
CQ_tigrisClass = "O_APC_Tracked_02_AA_F";
CQ_tigrisPerInsertion = 1;
CQ_tigrisRadar = 6000;                   // m: a MAGPIE drone in line of sight within this range can be noticed
CQ_tigrisSpot = [0.25, 0.03];            // chance per 4 s check to notice a drone in sight: at point blank -> at the radar edge
CQ_tigrisSpotSize = 0.5;                 // x for the small Darter
CQ_tigrisTrack = 40;                     // s a noticed drone stays tracked
CQ_tigrisMissileRange = 3500;            // m (slant): the Tigris launches a Titan at a tracked drone within this
CQ_tigrisSalvo = 25;                     // s between two launches of one Tigris
CQ_tigrisGuide = 0.5;                    // share of launches forced onto the drone (the others often miss)

// Range map (fn_rangeMapClient): the ground each enemy MAGPIE sees right now can fire on (line of
// sight through terrain + buildings, vegetation ignored, within his weapon range), fire cone darker
CQ_rangeMap = true;
CQ_rangeCell = 25;                       // m per cell
CQ_rangeOf = createHashMapFromArray [["rifle", 400], ["mg", 700], ["launcher", 500], ["sniper", 900], ["vehicle", 1000], ["static", 1200]];   // m by weapon
CQ_rangeCone = 45;                       // deg either side of where the enemy faces = fire cone
CQ_rangeMove = 40;                       // m an enemy must move before his range is recomputed
CQ_rangeBudget = 120;                    // line-of-sight checks between two short pauses
CQ_rangeAlpha = [0.10, 0.05, 0.12];      // opacity: 1 enemy, + per extra enemy (max 4), + inside a fire cone
// MAGPIE radar echoes on the map (fn_magMapClient): live filled circle + fading empty traces
CQ_echoPx = 5;                           // circle size in screen pixels (same at every zoom)
CQ_echoLife = 5;                         // s a trace circle stays (fading out)
CQ_echoColor = [0.729, 0.224, 0.173];    // chart red #BA392C
// MAGPIE heatmap (map overlay, every player; OFF by default since the radar echoes): contacts only, blue -> red
// contour bands shaped by the terrain, fading (half-life) as the information gets old
CQ_heatCell = 300;                       // m per cell
CQ_heatHalfHeat = 60;                    // s: contact heat halves every minute
CQ_heatEvery = 5;                        // s between two server updates
CQ_heatPubEvery = 10;                    // s between two broadcasts to the players
CQ_heatWeights = createHashMapFromArray [["inf", 0.15], ["static", 0.3], ["light", 0.35], ["armour", 0.6], ["air", 0.6]];   // heat per seen unit (summed per cell, max 1)
CQ_heatEnabled = false;                   // false: no heatmap overlay on the map (the server grid still runs)
CQ_heatFine = 120;                       // m: drawn tile size (the field is sampled this fine)
CQ_heatSigma = 260;                      // m: spread of one contact cell (gaussian)
CQ_heatTerrain = 0.35;                   // heightmap mask: how much local relief bends the contours
CQ_heatBands = 7;                        // colour bands (stepped contours, blue -> red)
CQ_heatAlpha = 0.10;                     // final opacity of the overlay
CQ_heatMaxTiles = 1200;                  // drawn tiles at most (strongest first, on screen only)
// fixed-wing spawn spots placed in Eden by hand: name -> [[x, y], direction]
CQ_magFixedSpawns = createHashMapFromArray [
    ["Sentinel_Argos",  [[14305.65, 15841.31], 39.09]],
    ["Sentinel_Hermes", [[14287.53, 15824.28], 39.09]]
];
// Search circuits (drawn on the map by Django): until MAGPIE's FIRST contact, each Sentinel flies
// the shared trunk east from the base, then loops its own circuit over and over:
//   Sentinel_Argos   north loop, clockwise: Almyra salt lake, Sofia, back down the NE coast
//   Sentinel_Hermes  south loop: down the spine to Selakano, round the south tip, up the east coast
// After the first contact they switch to the usual encirclement / ellipse behaviour.
// name -> [trunk points, loop points]  ([x, y] metres)
CQ_magTrunk = [[17000, 16000], [19700, 15950], [20800, 16100]];
CQ_magPatrol = createHashMapFromArray [
    ["Sentinel_Argos",  [CQ_magTrunk, [[20800, 16450], [22600, 17600], [24050, 18550], [25350, 20150], [26050, 21400], [27150, 21500],
        [27950, 20800], [28000, 19500], [27300, 18400], [25850, 17400], [24550, 16750], [23700, 15950], [22600, 15550], [21150, 15500]]]],
    ["Sentinel_Hermes", [CQ_magTrunk, [[20300, 15700], [20150, 14000], [20150, 11800], [20250, 9050], [20350, 6950], [21000, 6300], [22100, 6300],
        [23100, 6950], [23650, 8550], [23550, 10800], [23150, 13050], [23550, 14850], [21950, 15500]]]]
];
CQ_magRunwayIn = 15;                     // m past the runway threshold (SW end): where the fixed-wing drones spawn
CQ_magRunwayFlip = false;                // true if the drones spawn facing off the runway end
CQ_runwayLength = 3200;                  // m cleared ahead of the drones' take-off spot (whole runway)
CQ_runwayHalfWidth = 30;                 // ... runway half width either side of the centre line
CQ_runwayMargin = 30;                    // ... plus this margin around it
CQ_runwayBehind = 600;                   // m also cleared behind the drones' take-off spot
