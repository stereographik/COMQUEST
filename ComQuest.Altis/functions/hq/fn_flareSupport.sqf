/*
    CQ_fnc_flareSupport  (server)
    [_hq, _pos, _group] call CQ_fnc_flareSupport;
    A squad that got hammered fires a red flare high over its position. Heavy support:
      - CQ_flareGarrisonShare (30%) of its HQ's garrison goes search & destroy on the spot
      - half of the roaming squads around (patrols of any HQ within CQ_flareRecallRange of the
        HQ) fall back to protect the HQ
    At most once per HQ every CQ_flareCooldown seconds.
*/
params ["_hq", "_pos", ["_g", grpNull]];
if (time - (_hq getOrDefault ["flareT", -1e6]) < CQ_flareCooldown) exitWith {};
_hq set ["flareT", time];
private _c = _hq get "pos";
private _from = if (!isNull _g && { ({ alive _x } count units _g) > 0 }) then { getPosATL leader _g } else { _pos };

// the flare: a red 40 mm flare shell high in the sky, a second one a few seconds later
[_from] spawn {
    params ["_p"];
    for "_i" from 1 to 2 do {
        private _f = createVehicle ["F_40mm_Red", (_p vectorAdd [0, 0, 160 + random 40]), [], 0, "CAN_COLLIDE"];
        _f setVelocity [0, 0, -2];
        sleep 6;
    };
};

// 30% of the garrison -> the spot
private _inf = (_hq get "infantry") select { ({ alive _x } count units _x) > 0 && { (_x getVariable ["CQ_role", ""]) in ["patrol", "reinf", "secure", "defend"] } };
private _total = [(_hq get "infantry")] call CQ_fnc_aliveCount;
private _want = round (_total * CQ_flareGarrisonShare);
private _sent = 0;
{
    if (_sent >= _want) exitWith {};
    [_x] call CQ_fnc_clearWaypoints;
    _x setVariable ["CQ_role", "qrf"];
    _x setVariable ["CQ_qrfUntil", time + CQ_qrfTime];
    _x setBehaviour "COMBAT";
    _x setSpeedMode "FULL";
    (_x addWaypoint [_pos, 60]) setWaypointType "SAD";
    _sent = _sent + ({ alive _x } count units _x);
} forEach ([_inf, [], { (leader _x) distance2D _pos }, "ASCEND"] call BIS_fnc_sortBy);

// half of the roaming squads around fall back to protect the HQ
private _roam = [];
{
    if ((_y get "state") in CQ_activeStates) then {
        _roam append ((_y get "infantry") select {
            (_x getVariable ["CQ_role", ""]) == "patrol" && { (leader _x) distance2D _c < CQ_flareRecallRange } && { (leader _x) distance2D _c > 250 }
        });
    };
} forEach CQ_hqs;
_roam = _roam call BIS_fnc_arrayShuffle;
private _back = _roam select [0, ceil (count _roam / 2)];
{
    [_x] call CQ_fnc_clearWaypoints;
    _x setSpeedMode "FULL";
    [_x, _c, 200] call CQ_fnc_infPatrol;
    _x setSpeedMode "FULL";
} forEach _back;

["RED FLARE", format ["HQ #%1: red flare at grid %2, %3 men sent, %4 roaming squads fall back to the HQ", _hq get "id", mapGridPosition _from, _sent, count _back]] call CQ_fnc_announce;
["flare", [[_hq get "id"] call CQ_fnc_objName], _hq] call CQ_fnc_say;
