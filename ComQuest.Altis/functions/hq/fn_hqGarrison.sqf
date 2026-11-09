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

// No commander on the ground (e.g. his Taru was shot down during the insertion): the HQ
// is not left headless, a new officer takes charge with 2 guards. Only at installation:
// a commander killed later by the players is never replaced.
if (isNull (_hq get "commander") && { isNull _cmdGroup || { ({ alive _x } count units _cmdGroup) == 0 } }) then {
    _cmdGroup = createGroup [east, true];
    { _cmdGroup createUnit [_x, _c getPos [5, random 360], [], 0, "NONE"] } forEach ["O_officer_F", "O_Soldier_F", "O_Soldier_F"];
    [units _cmdGroup] call CQ_fnc_unitPrep;
    _cmdGroup enableDynamicSimulation false;
    _hq set ["cmdGroup", _cmdGroup];
    ["Enemy commander appointed", format ["HQ #%1: the commander was lost on the way, a new officer takes charge", _id]] call CQ_fnc_announce;
};

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
    // Capture: hold action for every player (JIP too), only once his guards are down
    [_cmd, "<t color='#9FD3FF'>Capture the commander</t>",
        "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_secure_ca.paa",
        "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_secure_ca.paa",
        "alive _target && { _this distance _target < 3 } && { !(_target getVariable ['CQ_captured', false]) } && { ({ alive _x && { side group _x == east } && { _x != _target } } count (_target nearEntities ['CAManBase', 15])) == 0 }",
        "alive _target && { _caller distance _target < 4 }",
        {}, {}, { ["capture", _target, _caller] remoteExec ["CQ_fnc_cmdCapture", 2] }, {},
        [], 6, 10, true, false] remoteExec ["BIS_fnc_holdActionAdd", 0, _cmd];
    _cmd addEventHandler ["Killed", {
        private _hq = CQ_hqs get ((_this select 0) getVariable ["CQ_hqId", -1]);
        if (isNil "_hq") exitWith {};
        if ((_this select 0) getVariable ["CQ_captured", false]) exitWith {};   // a prisoner's death is not a kill
        ["Enemy commander killed", format ["HQ #%1 has lost its commander", _hq get "id"]] call CQ_fnc_announce;
        ["killCommander", [[_hq get "id"] call CQ_fnc_objName], _hq] call CQ_fnc_say;
        params ["", "_k", "_i"];
        [[_i, _k] select (isNull _i), 40, "HQ commander"] call CQ_fnc_scoreAdd;
    }];
};

// Infantry: 1st squad defends, the others patrol loops getting wider (CQ_patrolRadius)
{
    private _g = _x;
    [_g] call CQ_fnc_clearWaypoints;
    if (_forEachIndex == 0) then {
        _g setVariable ["CQ_role", "defend"];
        [_g, _c] call BIS_fnc_taskDefend;
    } else {
        _g setVariable ["CQ_role", "patrol"];
        CQ_patrolRadius params ["_r0", "_r1"];
        [_g, _c, (_r0 + 150 * (_forEachIndex - 1)) min _r1] call CQ_fnc_infPatrol;
    };
    _g enableDynamicSimulation CQ_dynSimGarrison;
} forEach ((_hq get "infantry") select { ({ alive _x } count units _x) > 0 });

// Vehicles: armed ones patrol 400 m, the truck parks by the depot
{
    private _v = _x;
    private _vg = group effectiveCommander _v;
    if (alive _v && { !isNull _vg }) then {
        [_vg] call CQ_fnc_clearWaypoints;
        [_vg, _v, _c] call CQ_fnc_vehRoam;      // trucks too: CQ_fnc_moveGroups calls them back when needed
        _vg enableDynamicSimulation CQ_dynSimGarrison;
    };
} forEach (_hq get "vehicles");

// Map markers, once: approximate circle for players, exact marker only in debug
if !(_hq get "markersMade") then {
    _hq set ["markersMade", true];
    if (!CQ_playerMapMarkers && { !CQ_debug }) exitWith {};   // players find HQs with the direction finder
    private _fuzzy = _c getPos [random (CQ_hqMarkerRadius * 0.6), random 360];
    private _m1 = createMarker [format ["cq_hq_%1_area", _id], _fuzzy];
    _m1 setMarkerShape "ELLIPSE";
    _m1 setMarkerSize [CQ_hqMarkerRadius, CQ_hqMarkerRadius];
    _m1 setMarkerBrush "Border";
    _m1 setMarkerColor "ColorOPFOR";
    private _m2 = createMarker [format ["cq_hq_%1_label", _id], _fuzzy];
    _m2 setMarkerType "o_hq";
    _m2 setMarkerColor "ColorOPFOR";
    _m2 setMarkerText format ["Objective %1", [_id] call CQ_fnc_objName];
    (_hq get "markers") append [_m1, _m2];

    if (CQ_debug) then {
        private _m3 = createMarker [format ["cq_hq_%1_exact", _id], _c];
        _m3 setMarkerType "mil_destroy";
        _m3 setMarkerColor "ColorRed";
        _m3 setMarkerText format ["DEBUG exact HQ #%1 (%2)", _id, [_id] call CQ_fnc_objName];
        (_hq get "markers") pushBack _m3;
    };
};
