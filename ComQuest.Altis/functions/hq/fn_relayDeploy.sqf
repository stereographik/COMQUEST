/*
    CQ_fnc_relayDeploy  (server, from the engineer's "Deploy relay" action)    nGD takeover
    [_unit] remoteExec ["CQ_fnc_relayDeploy", 2];
    An engineer at the tower site of a fallen enemy HQ (within CQ_relayRange) puts up a friendly
    relay (CQ_relayClass): the node is ours at once. MAGPIE identifies enemies within
    CQ_netCoverRelay of it (CQ_fnc_magTick). The relay can be destroyed: the coverage is lost
    and the site can be relayed again. The nearest standing enemy HQ within CQ_relayRetakeRange
    sends a squad to destroy it.
*/
params ["_u"];
if (isNull _u || { (_u getVariable ["CQ_class", ""]) != "Engineer" }) exitWith {};
if (isNil "CQ_relays") then { CQ_relays = [] };
private _sites = (missionNamespace getVariable ["CQ_relaySites", []]) select { _u distance2D (_x select 1) < CQ_relayRange };
if (_sites isEqualTo []) exitWith { "No fallen enemy tower site here" remoteExec ["hint", _u] };
(_sites select 0) params ["_id", "_tp"];
private _p = [_tp getPos [8, random 360], 2, 20] call CQ_fnc_clearPos;
if (_p isEqualTo []) then { _p = _tp getPos [10, random 360] };
private _r = createVehicle [CQ_relayClass, _p, [], 0, "CAN_COLLIDE"];
_r setVariable ["CQ_relayOf", _id, true];
private _pos = getPosATL _r;
CQ_relays pushBack [_id, _r, _pos];
call CQ_fnc_relaySites;
CQ_netNext = 0;                          // the map and MAGPIE coverage update at once
["Relay deployed", format ["%1 put up a relay on the ruins of %2 (grid %3): MAGPIE now covers %4 m around it",
    name _u, [_id] call CQ_fnc_objName, mapGridPosition _pos, CQ_netCoverRelay]] call CQ_fnc_announce;
["relayUp", [[_id] call CQ_fnc_objName]] call CQ_fnc_say;
[_u, 50, "relay"] call CQ_fnc_scoreAdd;

// the nearest standing HQ sends a squad to take it down
private _near = (values CQ_hqs) select { (_x get "state") in CQ_activeStates && { (_x get "pos") distance2D _pos < CQ_relayRetakeRange } };
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
        ["Relay: HQ #%1 sends %2 to retake the relay at %3", [_h get "id", groupId _g, mapGridPosition _pos]] call CQ_fnc_log;
    };
};
