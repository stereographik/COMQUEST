/*
    CQ_fnc_hqGarrison  (server)
    [_hq] call CQ_fnc_hqGarrison;
    End of installation: commander + guards inside the command building, perimeter squads
    recalled (1st defends the HQ, the others patrol), armed vehicles patrol, the truck parks.
    Creates the map markers once.
*/
params ["_hq"];

private _c = _hq get "pos";
private _id = _hq get "id";
private _bld = _hq get "building";
private _cmdGroup = _hq get "cmdGroup";

// Commander and guards inside the building
if (!isNull _cmdGroup && { ({ alive _x } count units _cmdGroup) > 0 }) then {
    private _spots = if (isNull _bld) then { [] } else { _bld buildingPos -1 };
    {
        if (_spots isNotEqualTo []) then {
            private _p = selectRandom _spots;
            _spots = _spots - [_p];
            _x setPosATL _p;
        } else {
            _x setPosATL (_c getPos [3, random 360]);
        };
        _x disableAI "PATH";
    } forEach (units _cmdGroup select { alive _x });
    _cmdGroup setBehaviour "AWARE";
    _cmdGroup setCombatMode "RED";

    private _cmd = leader _cmdGroup;
    _cmd setVariable ["CQ_hqId", _id];
    _hq set ["commander", _cmd];
    _cmd addEventHandler ["Killed", {
        private _hq = CQ_hqs get ((_this select 0) getVariable ["CQ_hqId", -1]);
        if (isNil "_hq") exitWith {};
        ["Enemy commander killed", format ["HQ #%1 has lost its commander", _hq get "id"]] call CQ_fnc_announce;
    }];
};

// Infantry: 1st squad defends, the others patrol (150, 250, 350... m)
{
    private _g = _x;
    [_g] call CQ_fnc_clearWaypoints;
    if (_forEachIndex == 0) then {
        _g setVariable ["CQ_role", "defend"];
        [_g, _c] call BIS_fnc_taskDefend;
    } else {
        _g setVariable ["CQ_role", "patrol"];
        [_g, _c, (50 + 100 * _forEachIndex) min 400] call BIS_fnc_taskPatrol;
    };
    _g enableDynamicSimulation true;
} forEach ((_hq get "infantry") select { ({ alive _x } count units _x) > 0 });

// Vehicles: armed ones patrol 400 m, the truck parks by the depot
{
    private _v = _x;
    private _vg = group effectiveCommander _v;
    if (alive _v && { !isNull _vg }) then {
        [_vg] call CQ_fnc_clearWaypoints;
        if (_v isKindOf "Truck_F") then {
            _vg move (_c getPos [35, (_hq get "dir") + 270]);
        } else {
            _vg setVariable ["CQ_role", "patrol"];
            [_vg, _c, 400] call BIS_fnc_taskPatrol;
        };
        _vg enableDynamicSimulation true;
    };
} forEach (_hq get "vehicles");

// Map markers, once: approximate circle for players, exact marker only in debug
if !(_hq get "markersMade") then {
    _hq set ["markersMade", true];
    private _fuzzy = _c getPos [random (CQ_hqMarkerRadius * 0.6), random 360];
    private _m1 = createMarker [format ["cq_hq_%1_area", _id], _fuzzy];
    _m1 setMarkerShape "ELLIPSE";
    _m1 setMarkerSize [CQ_hqMarkerRadius, CQ_hqMarkerRadius];
    _m1 setMarkerBrush "Border";
    _m1 setMarkerColor "ColorOPFOR";
    private _m2 = createMarker [format ["cq_hq_%1_label", _id], _fuzzy];
    _m2 setMarkerType "o_hq";
    _m2 setMarkerColor "ColorOPFOR";
    _m2 setMarkerText format ["Enemy HQ #%1", _id];
    (_hq get "markers") append [_m1, _m2];

    if (CQ_debug) then {
        private _m3 = createMarker [format ["cq_hq_%1_exact", _id], _c];
        _m3 setMarkerType "mil_destroy";
        _m3 setMarkerColor "ColorRed";
        _m3 setMarkerText format ["DEBUG exact HQ #%1", _id];
        (_hq get "markers") pushBack _m3;
    };
};
