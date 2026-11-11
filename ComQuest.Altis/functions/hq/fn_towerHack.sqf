/*
    CQ_fnc_towerHack  (server, from an engineer's "Hack radio tower" hold action)
    [_tower, _player] remoteExec ["CQ_fnc_towerHack", 2];
    The enemy radio tower is not blown up: an engineer hacks it (CQ_hackTime s at its foot) and it
    is ours at once, as a relay (MAGPIE identifies within CQ_netCoverRelay of it). For its HQ the
    radio is gone (no more calls for help; with its commander gone the HQ falls). The tower can
    now be destroyed like any building: the nearest standing HQ sends a squad to take it down.
*/
params ["_t", "_u"];
if (!isServer || { isNull _t } || { !alive _t } || { _t getVariable ["CQ_hacked", false] }) exitWith {};
private _id = _t getVariable ["CQ_hqId", -1];
private _hq = CQ_hqs getOrDefault [_id, createHashMap];
_t setVariable ["CQ_hacked", true, true];
_t removeAllEventHandlers "HandleDamage";          // destructible from now on (it is our relay)
if (count _hq > 0) then { _hq set ["radio", objNull]; _hq set ["radioHacked", _t] };
// OPERATION briefing: this objective is done, by the hacker's squad
private _c = _t getVariable ["CQ_opEntry", []];
if (_c isNotEqualTo [] && { (_c select 1) < 0 }) then { _c set [1, time]; _c set [2, if (isNull _u) then { "" } else { groupId group _u }] };
CQ_opNext = 0;
// the relay
if (isNil "CQ_relays") then { CQ_relays = [] };
private _pos = getPosATL _t;
CQ_relays pushBack [_id, _t, _pos];
call CQ_fnc_relaySites;
CQ_netNext = 0;
private _name = if (count _hq > 0) then { [_id] call CQ_fnc_objName } else { "an enemy HQ" };
["Radio tower hacked", format ["%1 hacked the radio tower of %2 (grid %3): it is our relay now, MAGPIE covers %4 m around it",
    [name _u, "Command"] select (isNull _u), _name, mapGridPosition _pos, CQ_netCoverRelay]] call CQ_fnc_announce;
["towerHacked", [_name]] call CQ_fnc_say;
if (!isNull _u) then { [_u, 75, "radio tower hacked"] call CQ_fnc_scoreAdd };

// the nearest other standing HQ sends a squad to take it down
private _near = (values CQ_hqs) select { (_x get "state") in CQ_activeStates && { (_x get "id") != _id } && { (_x get "pos") distance2D _pos < CQ_relayRetakeRange } };
if (_near isNotEqualTo []) then {
    _near = [_near, [], { (_x get "pos") distance2D _pos }] call BIS_fnc_sortBy;
    private _h = _near select 0;
    private _g = ((_h get "infantry") select { !isNull _x && { (_x getVariable ["CQ_role", ""]) == "patrol" } && { ({ alive _x } count units _x) >= 3 } }) param [0, grpNull];
    if (!isNull _g) then {
        [_g] call CQ_fnc_clearWaypoints;
        _g setVariable ["CQ_role", "qrf"];
        _g setVariable ["CQ_qrfUntil", time + CQ_qrfTime];
        _g setBehaviour "AWARE";
        _g setSpeedMode "FULL";
        (_g addWaypoint [_pos, 30]) setWaypointType "SAD";
        ["Hacked tower: HQ #%1 sends %2 to take it down at %3", [_h get "id", groupId _g, mapGridPosition _pos]] call CQ_fnc_log;
    };
};
