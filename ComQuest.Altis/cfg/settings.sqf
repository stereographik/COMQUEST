/*
    cfg\settings.sqf
    Every tunable number of ComQuest lives here.
    Loaded on every machine (server and clients) before init, by CQ_fnc_settings.
*/

CQ_debug = true;                         // log to systemChat as well as the .rpt

// --- Director -------------------------------------------------------------
CQ_tickSeconds = 5;                      // one server tick every 5 s

// --- Player base (Altis International Airport) -----------------------------
CQ_basePos = [14734, 16730, 0];
CQ_baseRadius = 300;                     // base zone drawn on the map
CQ_baseNoSpawnRadius = 2500;             // no enemy site closer than this (milestone 2)

// --- Base vehicles --------------------------------------------------------
// [classname, marker for an exact spot (optional, place it in Eden), direction]
// If the marker does not exist, a free spot near CQ_basePos is used.
CQ_baseVehicles = [
    ["B_Heli_Light_01_F", "cq_veh_heli",    0],   // MH-6 Hummingbird, unarmed
    ["I_MRAP_03_F",       "cq_veh_strider", 0],   // Strider, unarmed
    ["B_MRAP_01_F",       "cq_veh_hunter",  0]    // Hunter, unarmed
];
CQ_vehRespawnDelay = 60;                 // seconds after destruction
CQ_vehAbandonDelay = 600;                // seconds empty before it returns to base
CQ_vehAbandonDistance = 300;             // only counts as abandoned this far from base

// --- Enemy root insertions --------------------------------------------------
CQ_maxRoots = 6;                         // root insertions in a campaign (victory after the last one)
CQ_rootInterval = 3600;                  // seconds between root insertions
CQ_firstRootDelay = 120;                 // seconds after mission start
CQ_insertionSpawnDistance = 8000;        // helis appear this far from the site
CQ_insertionFlyHeight = 80;
CQ_insertionEscort = true;               // Mi-48 Kajman escort

// --- HQ sites and construction ---------------------------------------------
CQ_siteRadius = 40;                      // flat, empty circle needed (the composition reaches ~31 m)
CQ_objectClearance = 0.5;                // extra metres around each object's footprint
CQ_lzClearance = 14;                     // free radius for a Taru landing / vehicle drop
// Terrain objects that block a site, an object or an LZ
CQ_blockerTypes = ["TREE", "SMALL TREE", "BUSH", "ROCK", "ROCKS", "HOUSE", "BUILDING", "WALL", "FENCE",
    "CHURCH", "CHAPEL", "FUELSTATION", "HOSPITAL", "LIGHTHOUSE", "POWER LINES", "POWERSOLAR", "POWERWIND",
    "TRANSMITTER", "WATERTOWER", "RUIN", "STACK", "TOURISM", "VIEW-TOWER", "BUNKER", "FORTRESS", "FOUNTAIN", "QUAY"];
// Footprint radius (m) of each composition object, used for spacing checks
CQ_objRadius = createHashMapFromArray [
    ["Land_Cargo_HQ_V1_F", 8], ["Land_BagFence_Long_F", 1.6], ["Land_BagFence_Round_F", 1.5],
    ["Land_Cargo_House_V1_F", 3.5], ["Box_East_Ammo_F", 0.6], ["Land_TTowerBig_2_F", 3],
    ["Land_HelipadSquare_F", 5], ["O_static_AA_F", 1.2]
];
CQ_siteMaxGradient = 0.15;
CQ_siteNoPlayerRadius = 800;
CQ_siteMinHqSpacing = 1500;
CQ_hqBuildStageTime = 45;                // seconds per construction stage (4 stages)
CQ_hqMarkerRadius = 400;                 // approximate circle shown to players
CQ_engineerCharges = ["DemoCharge_Remote_Ammo", "DemoCharge_Remote_Ammo_Scripted", "SatchelCharge_Remote_Ammo", "SatchelCharge_Remote_Ammo_Scripted"];

// --- DEBUG overrides (set CQ_debug = false above for the real campaign) -----
if (CQ_debug) then {
    CQ_debugFirstAtRunway = true;        // 1st root lands at the runway end (marker "cq_debug_site" overrides)
    CQ_firstRootDelay = 30;
    CQ_insertionSpawnDistance = 3500;
    CQ_insertionEscort = false;          // no gunship shooting the base while you watch
    CQ_hqBuildStageTime = 20;
} else {
    CQ_debugFirstAtRunway = false;
};

// --- Roles ----------------------------------------------------------------
CQ_pilotClasses = ["B_Helipilot_F"];     // only these may fly aircraft
CQ_engineerClasses = ["B_engineer_F"];   // get engineer + explosiveSpecialist traits
