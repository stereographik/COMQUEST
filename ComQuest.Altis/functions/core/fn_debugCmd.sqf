/*
    CQ_fnc_debugCmd  (server, DEBUG only, called from the debug panel)
    [_cmd, _hqId] remoteExec ["CQ_fnc_debugCmd", 2];
      "next"    advance the selected HQ to its next phase
      "ammo"    +200 ammo in the selected HQ's depot
      "fuel"    +200 fuel in the selected HQ's depot
      "destroy" kill the commander and blow the depot (before the build: kill its troops)
      "root"    launch the next root insertion now
      "flight"  launch the ammo flight to the main HQ now
      "list"    just refresh
    Answers the caller with the HQ list (CQ_fnc_debugUiFill).
*/
params [["_cmd", "list"], ["_id", -1]];
if (!CQ_debug) exitWith {};

private _caller = remoteExecutedOwner;
private _hq = CQ_hqs getOrDefault [_id, createHashMap];
private _msg = "";
private _needHq = _cmd in ["next", "ammo", "fuel", "destroy"];

if (_needHq && { count _hq == 0 }) then {
    _msg = "Select an HQ in the list first";
} else {
    switch (_cmd) do {
        case "next": {
            private _st = _hq get "state";
            _msg = switch (_st) do {
                case "Inbound": {
                    if ((_hq get "parent") > -1) then { _hq set ["moveSkip", true]; "colonists moved to the site" }
                    else { "root insertion still flying: wait for the landing" };
                };
                case "Securing": {
                    if (_hq get "secureStarted") then { _hq set ["stateT", time - CQ_secureTimeout - 1]; "perimeter forced: installing next tick" }
                    else { "securing starts next tick, press again" };
                };
                case "Installing": { _hq set ["skipStage", true]; "next build stage now" };
                case "Hold": { _hq set ["stateT", time - CQ_holdTime - 1]; "hold ended: calling reinforcements" };
                case "Holding": { _hq set ["nextWaveT", time]; "next reinforcement wave requested" };
                case "WaitingReinf": { _hq set ["waveSkip", true]; "convoy moved to the HQ: split next" };
                default { format ["state %1 cannot be advanced", _st] };
            };
            _msg = format ["HQ #%1 (%2): %3", _id, _st, _msg];
        };
        case "ammo": {
            if ((_hq get "buildDone") && { alive (_hq get "depot") }) then {
                _hq set ["stock", ((_hq get "stock") + 200) min (_hq get "cap")];
                _msg = format ["HQ #%1 depot now %2/%3", _id, round (_hq get "stock"), _hq get "cap"];
            } else {
                _msg = format ["HQ #%1 has no depot yet", _id];
            };
        };
        case "fuel": {
            if ((_hq get "buildDone") && { alive (_hq get "depot") }) then {
                _hq set ["fuel", ((_hq get "fuel") + 200) min (_hq get "cap")];
                _msg = format ["HQ #%1 fuel now %2/%3", _id, round (_hq get "fuel"), _hq get "cap"];
            } else {
                _msg = format ["HQ #%1 has no depot yet", _id];
            };
        };
        case "destroy": {
            if (_hq get "buildDone") then {
                { if (!isNull _x) then { _x setDamage 1 } } forEach [_hq get "commander", _hq get "depot"];
            } else {
                { { _x setDamage 1 } forEach units _x } forEach ((_hq get "infantry") + [_hq get "cmdGroup"]);
            };
            _msg = format ["HQ #%1 destroyed (debug)", _id];
        };
        case "root": {
            if (CQ_rootsLaunched < CQ_maxRoots) then {
                CQ_nextRootTime = 0;
                _msg = format ["root insertion %1/%2 launching", CQ_rootsLaunched + 1, CQ_maxRoots];
            } else {
                _msg = "all root insertions already used";
            };
        };
        case "flight": {
            if (CQ_hubId < 0) then { _msg = "no main HQ yet" } else {
                if (CQ_ammoFlightActive) then { _msg = "an ammo flight is already in the air" } else {
                    CQ_nextAmmoFlight = time - 1;
                    CQ_logiNext = 0;
                    _msg = format ["supply flight to main HQ #%1 launching", CQ_hubId];
                };
            };
        };
    };
};
if (_msg != "") then { ["DEBUG panel: %1", [_msg]] call CQ_fnc_log };

// --- answer with the HQ list and a status line
private _rows = [];
{
    private _h = _y;
    private _inf = [(_h get "infantry")] call CQ_fnc_aliveCount;
    _rows pushBack [_h get "id", format ["HQ #%1%2  %3  |  ammo %4  fuel %9 /%5  |  inf %6%7%8",
        _h get "id", ["", " MAIN"] select ((_h get "id") == CQ_hubId), _h get "state",
        round (_h get "stock"), _h get "cap", _inf,
        ["", format ["  |  child of #%1", _h get "parent"]] select ((_h get "parent") > -1),
        ["", format ["  |  site tolerance %1", _h get "siteLevel"]] select ((_h get "siteLevel") > 0),
        round (_h get "fuel")]];
} forEach CQ_hqs;
_rows sort true;

private _status = format ["Roots %1/%2 (next in %3 s)  |  main HQ %4  |  trucks %5  |  aircraft %6  |  enemy AI %7",
    CQ_rootsLaunched, CQ_maxRoots, round ((CQ_nextRootTime - serverTime) max 0),
    ["none", format ["#%1", CQ_hubId]] select (CQ_hubId > -1), CQ_trucksActive, count CQ_air, call CQ_fnc_enemyCount];

[_rows, _msg, _status] remoteExec ["CQ_fnc_debugUiFill", _caller];
