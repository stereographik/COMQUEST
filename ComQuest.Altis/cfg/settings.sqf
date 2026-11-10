/*
    cfg\settings.sqf
    Every tunable number of ComQuest lives here.
    Loaded on every machine (server and clients) before init, by CQ_fnc_settings.
*/

CQ_debug = true;                         // log to systemChat as well as the .rpt
CQ_playerView = true;                    // final player view by default: no debug chat, cards or markers (toggle in the debug panel)
CQ_debugCards = false;                   // debug phase messages as orange cards too (story lines use the cards)

// --- Director -------------------------------------------------------------
CQ_tickSeconds = 5;                      // one server tick every 5 s

// --- Player base (Altis International Airport) -----------------------------
CQ_basePos = [14267, 16099, 0];         // base compound centre (HQ zone drawn on the map)
CQ_baseRadius = 300;                     // base zone drawn on the map
CQ_baseNoSpawnRadius = 2500;             // no enemy site closer than this (milestone 2)

CQ_baseDir = 38;                         // compound front and vehicle rows compass direction
// --- Base vehicles (fixed numbers, each respawns when destroyed or abandoned) ----
// [classname, parking role in the camp (CQ_fnc_baseSetup), count]
CQ_baseVehicles = [
    ["B_MRAP_01_F",               "hunter",     4],   // Hunter, unarmed
    ["I_MRAP_03_F",               "strider",    4],   // Strider, unarmed
    ["B_G_Offroad_01_armed_F",    "pickup",     4],   // Offroad HMG
    ["B_Truck_01_transport_F",    "hemtt",      2],   // HEMTT troop transport
    ["B_Heli_Light_01_F",         "littlebird", 2],   // MH-6 Little Bird
    ["B_Heli_Transport_01_F",     "ghosthawk",  2],   // UH-80 Ghost Hawk
    ["B_Heli_Transport_01_F",     "blackhawk",  1]    // the "blackhawk": a 3rd UH-80 Ghost Hawk
];
CQ_baseVehPadding = 25;                  // metres between base vehicles (fallback search)
// Base layout (CQ_fnc_baseSetup), from the zones drawn on the map:
//   HQ compound at CQ_basePos facing CQ_baseDir; 4 parallel vehicle rows in the vehicle zone
//   (start point next to the HQ, running along CQ_baseDir); a crate dispenser + loadout zone
//   at the far end of each row; 2 repair stations east of the vehicle zone
CQ_compoundSize = [80, 60];              // inner compound width x depth (m)
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
CQ_vehRespawnDelay = 60;                 // seconds after destruction
CQ_vehAbandonDelay = 900;                // seconds empty and still away from its spot before it respawns there (15 min)
CQ_vehAbandonDistance = 30;              // ...away from its parking spot

// --- Enemy origin: a carrier off the east coast -------------------------------
CQ_carrierClass = "Land_Carrier_01_base_F";   // USS Freedom (free Jets platform update)
CQ_coastBand = [9000, 23000];            // latitudes (y) where the carrier can appear
CQ_carrierOffshore = 3000;               // metres out from the coast (deeper water if needed)
CQ_rootInland = [1500, 4000];            // root insertions land this far inland from a coast point
CQ_firstRootInland = [600, 2000];        // the very first one is a beachhead: within 2 km of the shore, west of the carrier
CQ_rootCoastSpread = 4000;               // ...picked up to this far north/south of the carrier's coast point
CQ_childSpread = 70;                     // child HQs head toward the player base, +/- this many degrees
CQ_waveSpread = 60;                      // waves arrive from the carrier side of the HQ, +/- degrees
CQ_assaultRange = 3500;                  // an HQ this close to the player base assaults it instead of colonising

// --- Enemy root insertions --------------------------------------------------
CQ_maxRoots = 6;                         // root insertions in a campaign (victory after the last one)
CQ_rootInterval = 3600;                  // seconds between root insertions
CQ_firstRootDelay = 120;                 // seconds after mission start
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
CQ_hqBuildStageTime = 120;               // seconds per construction stage (4 stages, 8 min)
CQ_buildPauseRange = 400;                // m: BLUFOR this close to a site under construction stops the work
CQ_buildPauseAfterContact = 120;         // s: and for this long after the HQ reports contact
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
CQ_secureTimeout = 180;                  // build starts anyway after 3 min (squads keep walking to their posts)
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
    ["Marksman",        "B_soldier_M_F",    [],                                  2],
    ["Sniper",          "B_sniper_F",       [],                                  2],
    ["Pilot",           "B_Helipilot_F",    [],                                  4]
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
    CQ_hqBuildStageTime = 45;
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
// Arma 3 has no MQ-9 Reaper and its Sentinel UCAV needs the Jets DLC: the "Reaper" slot flies a
// second Greyhawk airframe, higher and wider. Weapons are removed: MAGPIE only looks.
CQ_magDrones = [
    ["Darter",   ["B_UAV_01_F"],                                  250, 0.8],
    ["Greyhawk", ["B_UAV_02_dynamicLoadout_F", "B_UAV_02_F"],     900, 1.2],
    ["Reaper",   ["B_UAV_05_F", "B_UAV_02_dynamicLoadout_F", "B_UAV_02_F"], 1500, 1.6]
];
CQ_magFirstDelay = 5;                    // s after mission start: first take-off (the carrier arrives at start)
CQ_magPadDist = 200;                     // m behind the HQ compound: the Darters' take-off field (grid of pads)
CQ_magPadGap = 12;                       // m between two Darter pads
CQ_magStuckTime = 20;                    // s still on the ground before a drone is nudged forward
CQ_magRespawn = 480;                     // s before a lost drone is replaced (8 min), on the runway
CQ_magReportEvery = 120;                 // s between two MAGPIE reports (only if something is new)
CQ_magMarkerTime = 10;                   // s the report dots stay on the map
CQ_magDetectEvery = 4;                   // s between two detection passes
CQ_magPlanEvery = 90;                    // s between two flight plans of a drone
// scan chain: CQ_magChainCount extra Darters fan out from the base to a north-south line and
// sweep it east across the island, spread over the land at each step (no slot over the sea)
CQ_magChainCount = 9;
CQ_magChainAlt = 250;                    // m
CQ_magChainStep = 600;                   // m the line moves east each step
CQ_magChainStepTime = 90;                // s max per step (moves on earlier once 70 % of the chain is in place)
// encirclement: the first identified contact becomes the focus; every airborne drone takes a
// sector of a ring around it, the ring turns slowly and tightens (risking the Tigris)
CQ_magRingStart = 3000;                  // m ring radius at first contact
CQ_magRingMin = 700;                     // m tightest ring
CQ_magRingShrink = 120;                  // m per minute the ring tightens
CQ_magRingTurn = 0.5;                    // deg per second the ring turns (a full turn in 12 min)
CQ_magOsc = [0.3, 240];                  // Greyhawk / Reaper loiter radius around a contact: +/- 30 %, one swing every 240 s
CQ_magFocusQuiet = 300;                  // s without a new contact in the ring (once tight) -> next focus
CQ_magCoastGap = 1500;                   // keep this far from the EAST coast (the carrier group)
CQ_magArea = [14500, 9000, 28500, 24500]; // area she sweeps: east Altis [xmin, ymin, xmax, ymax]
CQ_magCell = 1000;                       // search grid cell (m)
CQ_magMemory = 600;                      // s an identified position is kept for the flight plans
CQ_magSensor = [300, 1.2, 2400];         // sensor radius = 300 + altitude x 1.2, max 2400 m (Darter ~600, Greyhawk ~1380, Reaper ~2100)
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

// MAGPIE heatmap (map overlay, every player, always on): cold where her drones scanned,
// yellow -> red where they saw enemies; both fade (half-life) as the information gets old
CQ_heatCell = 300;                       // m per cell
CQ_heatHalfHeat = 60;                    // s: contact heat halves every minute
CQ_heatHalfScan = 60;                    // s: scan halves every minute
CQ_heatEvery = 5;                        // s between two server updates
CQ_heatPubEvery = 10;                    // s between two broadcasts to the players
CQ_heatWeights = createHashMapFromArray [["inf", 0.15], ["static", 0.3], ["light", 0.35], ["armour", 0.6], ["air", 0.6]];   // heat per seen unit (summed per cell, max 1)
CQ_heatEnabled = true;                   // false: no heatmap overlay on the map (the server grid still runs)
CQ_heatColdMerge = 3;                    // the cold (scanned) layer is drawn in 3 x 3 merged cells (900 m): 9x fewer blobs
CQ_heatMaxBlobs = 150;                   // per layer, strongest first; only blobs on screen are drawn
CQ_heatBlobCold = 1.8;                   // blob diameter in (merged) cells (overlap = smooth gradient)
CQ_heatBlobHot = 2.6;
CQ_heatIconK = 1;                        // size calibration of the blobs on the map
// fixed-wing spawn spots placed in Eden by hand: name -> [[x, y], direction]
CQ_magFixedSpawns = createHashMapFromArray [
    ["Greyhawk", [[14305.65, 15841.31], 39.09]],
    ["Reaper",   [[14287.53, 15824.28], 39.09]]
];
CQ_magRunwayIn = 15;                     // m past the runway threshold (SW end): where the fixed-wing drones spawn
CQ_magRunwayFlip = false;                // true if the drones spawn facing off the runway end
CQ_runwayLength = 3200;                  // m cleared ahead of the drones' take-off spot (whole runway)
CQ_runwayHalfWidth = 30;                 // ... runway half width either side of the centre line
CQ_runwayMargin = 30;                    // ... plus this margin around it
CQ_runwayBehind = 600;                   // m also cleared behind the drones' take-off spot
