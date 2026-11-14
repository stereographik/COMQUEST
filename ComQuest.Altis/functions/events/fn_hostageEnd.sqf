/*
    CQ_fnc_hostageEnd  (server)
    [_result] call CQ_fnc_hostageEnd;   _result: "" (just clear), "home", "dead"
    Ends the hostage event: markers out, the guerillas patrol where they are, the helicopter and
    the technician are removed once nobody is near them.
*/
params [["_res", ""]];
if (!isServer || { isNil "CQ_hstState" }) exitWith {};
private _s = CQ_hstState;
if ((_s get "phase") == "done") exitWith {};
_s set ["phase", "done"];
deleteMarker "cq_hst"; deleteMarker "cq_hst_lz";
CQ_hstPos = nil; publicVariable "CQ_hstPos";
private _gg = _s get "guer";
if (!isNull _gg && { ({ alive _x } count units _gg) > 0 }) then { [_gg] call CQ_fnc_clearWaypoints; [_gg, getPosATL (leader _gg), 250] call CQ_fnc_infPatrol };
// the guards left alive stay where they are
private _h = _s get "hostage";
private _v = _s get "heli";
[_h, _v, _res == "home"] spawn {
    params ["_h", "_v", "_home"];
    sleep ([90, 180] select _home);
    // home: gone once nobody rides the helicopter; elsewhere: once nobody is near
    waitUntil { sleep 10;
        if (_home) then { isNull _v || { (crew _v) findIf { isPlayer _x } == -1 } }
        else { (allPlayers findIf { alive _x && { (!isNull _h && { _x distance2D _h < 300 }) || { !isNull _v && { _x in crew _v || { _x distance2D _v < 300 } } } } }) == -1 } };
    if (!isNull _v) then { { if (!isPlayer _x) then { deleteVehicle _x } } forEach crew _v; deleteVehicle _v };
    if (!isNull _h) then { deleteVehicle _h };
};
switch (_res) do {
    case "home": {
        CQ_hstBoostUntil = (time max (missionNamespace getVariable ["CQ_hstBoostUntil", -1])) + CQ_hstBoostTime;
        publicVariable "CQ_hstBoostUntil";
        private _p = _s get "freer";
        if (!isNull _p) then { [_p, CQ_hstPoints, "hostage rescue"] call CQ_fnc_scoreAdd };
        ["Hostage event: technician home, Darter range x%1 until %2 s (%3 points to %4)", [CQ_hstBoost, round CQ_hstBoostUntil, CQ_hstPoints, if (isNull _p) then { "nobody" } else { name _p }]] call CQ_fnc_log;
        ["hstHome", [if (isNull _p) then { "the team" } else { name _p }, round (CQ_hstBoostTime / 60)]] call CQ_fnc_say;
        if (!isNil "CQ_hstKey") then { [CQ_hstKey, 2, format ["Hostage at grid %1", mapGridPosition (_s get "pos")], "technician brought home", _p] call CQ_fnc_opSide };
    };
    case "dead": {
        ["Hostage event: the technician is dead"] call CQ_fnc_log;
        ["hstDead", []] call CQ_fnc_say;
        if (!isNil "CQ_hstKey") then { [CQ_hstKey, 2, format ["Hostage at grid %1", mapGridPosition (_s get "pos")], "technician killed"] call CQ_fnc_opSide };
    };
};
