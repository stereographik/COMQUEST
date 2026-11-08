/*
    CQ_fnc_hqGarrison  (server)
    [_hq, _squads, _cmdGroup, _vehicles] call CQ_fnc_hqGarrison;
    Commander + guard inside the command building, squads defend / patrol, vehicles patrol.
*/
params ["_hq", "_squads", "_cmdGroup", "_vehicles"];

private _c = _hq get "pos";
private _id = _hq get "id";
private _bld = _hq get "building";

// Commander and guards inside the building
if (!isNull _cmdGroup && { (units _cmdGroup) isNotEqualTo [] }) then {
    private _spots = _bld buildingPos -1;
    {
        if (_spots isNotEqualTo []) then {
            private _p = selectRandom _spots;
            _spots = _spots - [_p];
            _x setPosATL _p;
        } else {
            _x setPosATL (_c getPos [3, random 360]);
        };
        _x disableAI "PATH";
    } forEach units _cmdGroup;
    _cmdGroup setBehaviour "AWARE";
    _cmdGroup setCombatMode "RED";
    (_hq get "groups") pushBack _cmdGroup;

    private _cmd = leader _cmdGroup;
    _cmd setVariable ["CQ_hqId", _id];
    _hq set ["commander", _cmd];
    _cmd addEventHandler ["Killed", {
        private _hq = CQ_hqs get ((_this select 0) getVariable ["CQ_hqId", -1]);
        if (isNil "_hq") exitWith {};
        ["Enemy commander killed", format ["HQ #%1 has lost its commander", _hq get "id"]] call CQ_fnc_announce;
    }];
};

// Infantry: 1st squad defends the HQ, the others patrol 150 m and 350 m out
{
    private _g = _x;
    if ((units _g) isNotEqualTo []) then {
        switch (_forEachIndex) do {
            case 0: { [_g, _c] call BIS_fnc_taskDefend };
            case 1: { [_g, _c, 150] call BIS_fnc_taskPatrol };
            default { [_g, _c, 350] call BIS_fnc_taskPatrol };
        };
        _g enableDynamicSimulation true;
        (_hq get "groups") pushBack _g;
    };
} forEach _squads;

// Vehicles: armed ones patrol 400 m; the truck parks by the depot
{
    private _v = _x;
    if (alive _v) then {
        private _vg = group effectiveCommander _v;
        if (isNull _vg) then {
            createVehicleCrew _v;
            _vg = group effectiveCommander _v;
        };
        if (_v isKindOf "Truck_F") then {
            _vg move (_c getPos [30, (_hq get "dir") + 270]);
        } else {
            [_vg, _c, 400] call BIS_fnc_taskPatrol;
        };
        _vg enableDynamicSimulation true;
        (_hq get "groups") pushBack _vg;
    };
} forEach _vehicles;

// Map: approximate circle for players, exact marker only in debug
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
