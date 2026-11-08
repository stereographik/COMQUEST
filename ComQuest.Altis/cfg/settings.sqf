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

// --- Roles ----------------------------------------------------------------
CQ_pilotClasses = ["B_Helipilot_F"];     // only these may fly aircraft
CQ_engineerClasses = ["B_engineer_F"];   // get engineer + explosiveSpecialist traits
