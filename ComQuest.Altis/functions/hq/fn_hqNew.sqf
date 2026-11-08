/*
    CQ_fnc_hqNew  (server)
    [_pos, _parentId] call CQ_fnc_hqNew  ->  HQ record (HashMap), stored in CQ_hqs by id.
    States: Inbound -> Securing -> Installing -> Hold -> WaitingReinf -> Holding -> WaitingReinf ...
            -> Destroyed | Failed
*/
params ["_pos", ["_parent", -1]];

private _id = CQ_hqNextId;
CQ_hqNextId = CQ_hqNextId + 1;

private _hq = createHashMapFromArray [
    ["id", _id],
    ["pos", _pos],
    ["dir", random 360],
    ["parent", _parent],
    ["state", "Inbound"],
    ["stateT", time],
    ["born", time],
    // forces
    ["infantry", []],            // infantry groups (roles on the group: secure, defend, patrol, reinf, qrf)
    ["cmdGroup", grpNull],
    ["vehicles", []],
    ["support", []],             // AA crews, QRF heli crew
    // composition
    ["objects", []],
    ["building", objNull],
    ["commander", objNull],
    ["radio", objNull],
    ["depot", objNull],
    ["pad", objNull],
    ["markers", []],
    ["markersMade", false],
    // lifecycle
    ["secureStarted", false],
    ["buildStarted", false],
    ["buildDone", false],
    ["nextWaveT", 0],
    ["waveResult", []],
    ["lastContactT", -1e6],
    ["siteLevel", 0],            // tolerance level the site search needed (CQ_fnc_findSite)
    // debug skips (debug panel)
    ["skipStage", false],
    ["waveSkip", false],
    ["moveSkip", false],
    // ammo depot
    ["stock", 0],
    ["stockInit", 0],            // ammo points the depot starts with (root: insertion cargo, child: carried)
    ["cap", CQ_depotCap],        // same cap for ammo and fuel
    ["fuel", 0],                 // held by the tanker: tanker destroyed = fuel lost
    ["tanker", objNull],
    ["fieldTruck", objNull],
    ["fieldTruckHome", []],
    ["fieldRun", false],
    ["fuelInit", 0],
    ["truckInbound", false],
    ["lowWarned", false],
    ["rearmPad", objNull]
];

CQ_hqs set [_id, _hq];
_hq
