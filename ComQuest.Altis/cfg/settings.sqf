/*
    cfg\settings.sqf
    Every tunable number of ComQuest lives here.
    Loaded on every machine (server and clients) before init, by CQ_fnc_settings.
*/

CQ_debug = true;                         // log to systemChat as well as the .rpt
CQ_debugCards = false;                   // debug phase messages as orange cards too (story lines use the cards)

// --- Director -------------------------------------------------------------
CQ_tickSeconds = 5;                      // one server tick every 5 s

// --- Player base (Altis International Airport) -----------------------------
CQ_basePos = [14182, 16282, 0];         // base camp centre (where the squads were placed in Eden)
CQ_baseRadius = 300;                     // base zone drawn on the map
CQ_baseNoSpawnRadius = 2500;             // no enemy site closer than this (milestone 2)

CQ_baseDir = 45;                         // camp front (heli line) compass direction: turn it to fit the airfield
// --- Base vehicles (fixed numbers, each respawns when destroyed or abandoned) ----
// [classname, parking role in the camp (CQ_fnc_baseSetup), count]
CQ_baseVehicles = [
    ["B_MRAP_01_F",               "hunter",     4],   // Hunter, unarmed
    ["I_MRAP_03_F",               "strider",    4],   // Strider, unarmed
    ["B_G_Offroad_01_armed_F",    "pickup",     4],   // Offroad HMG
    ["B_Truck_01_transport_F",    "hemtt",      2],   // HEMTT troop transport
    ["B_Heli_Light_01_F",         "littlebird", 2],   // MH-6 Little Bird
    ["B_Heli_Transport_01_F",     "ghosthawk",  2],   // UH-80 Ghost Hawk
    ["B_Heli_Attack_01_dynamicLoadout_F", "blackhawk", 1]   // AH-99 Blackfoot
];
CQ_baseVehPadding = 25;                  // metres between base vehicles (and from the arsenal crate)
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
CQ_dropPlaneClass = "B_T_VTOL_01_vehicle_F";   // V-44X Blackfish (vehicle transport): paradrops the insertion vehicles
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
CQ_hqMarkerRadius = 400;                 // approximate circle shown to players
CQ_engineerCharges = ["DemoCharge_Remote_Ammo", "DemoCharge_Remote_Ammo_Scripted", "SatchelCharge_Remote_Ammo", "SatchelCharge_Remote_Ammo_Scripted"];

// --- HQ lifecycle (realistic timings) ---------------------------------------
// Securing -> Installing -> Hold -> WaitingReinf -> split (child HQ) -> Holding -> WaitingReinf ...
CQ_activeStates = ["Inbound", "Securing", "Installing", "Hold", "Holding", "WaitingReinf"];
CQ_maxHqs = 8;                           // HQs alive at once
CQ_maxAI = 200;                          // enemy AI alive at once
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
    ["armour", ["O_APC_Wheeled_02_rcws_v2_F", "I_APC_tracked_03_cannon_F", "I_LT_01_cannon_F"]],
    ["random", ["O_MRAP_02_hmg_F", "O_G_Offroad_01_armed_F"]]
];
CQ_dynSimGarrison = false;               // true = HQ squads freeze when no player is near (saves CPU, but they stop patrolling)
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
CQ_specialRespawn = 300;                 // a wiped-out team is dropped again 5 min later
CQ_specialRange = 6000;                  // how far a team drives for a job
CQ_medicHealAbove = 0.25;                // soldiers hurt more than this get treated
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
CQ_ammoFlightClass = "O_Heli_Transport_04_ammo_F";   // Taru with ammo pod

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
