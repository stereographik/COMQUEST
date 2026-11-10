/*
    CQ_fnc_hqNew  (server)
    [_pos, _parentId] call CQ_fnc_hqNew  ->  HQ record (HashMap), stored in CQ_hqs by id.
    States: Inbound -> Securing -> Installing -> Hold -> WaitingReinf -> Holding -> WaitingReinf ...
            -> Destroyed | Failed
*/
params ["_pos", ["_parent", -1]];

private _id = CQ_hqNextId;
CQ_hqNextId = CQ_hqNextId + 1;

// codename: a random one of CQ_hqNames not used yet in this game, kept for the whole game
// (numbered if the list ever runs out: "OVERLORD 2")
if (isNil "CQ_hqNamesUsed") then { CQ_hqNamesUsed = [] };
private _free = CQ_hqNames - CQ_hqNamesUsed;
private _name = if (_free isNotEqualTo []) then { selectRandom _free } else { format ["%1 %2", selectRandom CQ_hqNames, floor (count CQ_hqNamesUsed / count CQ_hqNames) + 1] };
CQ_hqNamesUsed pushBack _name;

private _hq = createHashMapFromArray [
    ["id", _id],
    ["name", _name],
    ["pos", _pos],
    ["dir", random 360],
    ["parent", _parent],
    ["installations", []], ["cmdCaptured", false], ["rootDefendT", -1e6],
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
// every new HQ (insertion or split) uses one HQ's worth of the carrier's supplies
CQ_carrierLeft = (missionNamespace getVariable ["CQ_carrierLeft", CQ_carrierHqs]) - 1;
call CQ_fnc_carrierMarker;
["Carrier: supplies for %1 more HQ(s) (%2%%)", [CQ_carrierLeft max 0, round (100 * (CQ_carrierLeft max 0) / CQ_carrierHqs)]] call CQ_fnc_log;
_hq
