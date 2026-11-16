/*
    CQ_fnc_empStart  (server)
    private _ok = call CQ_fnc_empStart;
    Plants the EMP device (see CQ_fnc_empTick): next to a large building CQ_empNear m from the
    tentacle's head (the relay vehicle and WASP; CQ_empSiteDist m from the base without them,
    CQ_empHqGap m clear of enemy HQs), on a spot a Stomper can reach, preferring the ones
    closest to our vehicles and drones (our network). A table beside it with a UAV terminal on it
    (a prop until the defuse), CQ_crashSurvivors holding a ring around it (CQ_fnc_eventHold), a
    crewed armed pickup (CQ_fnc_eventTechnical), a search circle (CQ_empSearchR, off-centre) and
    the countdown. Defuse: hold actions (engineer CQ_empDefuse s; anyone CQ_empDefuseAny s while
    no engineer is alive), restarted when the defuser is hit (CQ_fnc_empClient sets CQ_empHitT).
    Returns false when no site was found.
*/
if (!isServer) exitWith { false };

// ---- site: aimed at the tentacle's head (the relay vehicle and WASP: their middle), on a big
// building CQ_empNear m from it (twice as far when nothing fits), away from the enemy HQs; with
// neither of them out, CQ_empSiteDist m from the base. Closest to our network first.
private _hqPos = (values CQ_hqs) select { (_x get "state") in CQ_activeStates } apply { _x get "pos" };
private _heads = [missionNamespace getVariable ["CQ_linkRelayVeh", objNull]]
    + (((missionNamespace getVariable ["CQ_mag", []]) select { (_x getOrDefault ["role", ""]) == "wasp" }) apply { _x get "veh" });
_heads = _heads select { alive _x };
private _ctr = CQ_basePos;
private _ring = CQ_empSiteDist;
if (_heads isNotEqualTo []) then {
    private _sx = 0; private _sy = 0;
    { _sx = _sx + ((getPosATL _x) select 0); _sy = _sy + ((getPosATL _x) select 1) } forEach _heads;
    _ctr = [_sx / count _heads, _sy / count _heads, 0];
    _ring = CQ_empNear;
};
private _find = {
    params ["_r0", "_r1"];
    (nearestObjects [_ctr, ["House", "Building"], _r1]) select {
        private _b = _x;
        private _dd = _b distance2D _ctr;
        _dd >= _r0 && { count (_b buildingPos -1) >= 4 } && { !surfaceIsWater getPos _b }
        && { (_hqPos findIf { _x distance2D _b < CQ_empHqGap }) == -1 }
        && { (_heads findIf { _x distance2D _b < (CQ_empNear select 0) }) == -1 }
    }
};
private _cands = _ring call _find;
if (_cands isEqualTo [] && { _heads isNotEqualTo [] }) then { _cands = [_ring select 0, (_ring select 1) * 2] call _find };
if (_cands isEqualTo []) exitWith { ["EMP event: no building found %1-%2 m from %3", [_ring select 0, _ring select 1, mapGridPosition _ctr]] call CQ_fnc_log; false };
private _ours = (vehicles select { alive _x && { getNumber (configOf _x >> "side") == 1 } && { !(_x isKindOf "ParachuteBase") } }) + (((missionNamespace getVariable ["CQ_mag", []]) apply { _x get "veh" }) select { alive _x });
if (_ours isEqualTo []) then { _ours = [CQ_basePos] };
private _netD = { params ["_p"]; private _m = 1e6; { _m = _m min (_x distance2D _p) } forEach _ours; _m };
_cands = [_cands, [], { [getPos _x] call _netD }, "ASCEND"] call BIS_fnc_sortBy;
private _b = selectRandom (_cands select [0, 8]);

// ---- the device: outside the building, on open ground a Stomper fits on
private _sz = (sizeOf typeOf _b) / 2;
private _p = [];
for "_i" from 0 to 11 do {
    private _try = (getPos _b) getPos [_sz + 4, (getDir _b) + _i * 30];
    _try = _try findEmptyPosition [0, 12, CQ_empStomper];
    if (_try isNotEqualTo [] && { !surfaceIsWater _try }) exitWith { _p = _try };
};
if (_p isEqualTo []) exitWith { ["EMP event: no open spot next to %1 at %2", [typeOf _b, mapGridPosition _b]] call CQ_fnc_log; false };
_p = [_p select 0, _p select 1, 0];
private _dcls = CQ_empDevice param [CQ_empDevice findIf { isClass (configFile >> "CfgVehicles" >> _x) && { getText (configFile >> "CfgVehicles" >> _x >> "DLC") == "" } }, ""];
if (_dcls == "") exitWith { ["EMP event: no device class available"] call CQ_fnc_log; false };
private _dev = createVehicle [_dcls, _p, [], 0, "CAN_COLLIDE"];
_dev setDir (_b getDir _p);
_dev allowDamage false;
_dev enableSimulationGlobal false;
private _tp = _p getPos [2.2, (_b getDir _p) + 90];
private _table = createVehicle [CQ_empTable, [_tp select 0, _tp select 1, 0], [], 0, "CAN_COLLIDE"];
_table setDir (_b getDir _p);
_table allowDamage false;
// the terminal on the table: a prop (not takeable) until the defuse
private _top = ((boundingBoxReal _table) select 1) select 2;
private _model = getText (configFile >> "CfgWeapons" >> "B_UavTerminal" >> "model");
private _prop = createSimpleObject [_model, (getPosASL _table) vectorAdd [0, 0, _top + 0.02]];
_prop setDir (getDir _table);

// ---- the defenders and the armed pickup
private _g = createGroup [east, true];
{ _g createUnit [_x, _p getPos [12, random 360], [], 0, "NONE"] } forEach CQ_crashSurvivors;
[units _g] call CQ_fnc_unitPrep;
{ _x setSkill CQ_crashSkill } forEach units _g;
_g setGroupIdGlobal ["EMP guards"];
_g enableDynamicSimulation false;
[units _g, _p, CQ_eventHoldR] call CQ_fnc_eventHold;
private _tech = [_p] call CQ_fnc_eventTechnical;
private _men = (units _g) + (if (isNull _tech) then { [] } else { [_tech] + crew _tech });

// ---- defuse: engineer, or anyone while no engineer is alive
{
    _x params ["_label", "_cond", "_time"];
    [_dev, _label,
        "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_unbind_ca.paa",
        "\a3\ui_f\data\IGUI\Cfg\holdactions\holdAction_unbind_ca.paa",
        format ["_this distance _target < 3 && { alive _this } && { (missionNamespace getVariable ['CQ_empPhase', '']) == 'armed' } && { %1 }", _cond],
        "_caller distance _target < 3 && { alive _caller } && { (_caller getVariable ['CQ_empHitT', -1]) < (_caller getVariable ['CQ_empHoldT', 1e9]) }",
        { params ["", "_caller"]; _caller setVariable ["CQ_empHoldT", time] }, {},
        { params ["", "_caller"]; [_caller] remoteExec ["CQ_fnc_empDefuse", 2] },
        {}, [], _time, 20, false, false
    ] remoteExec ["BIS_fnc_holdActionAdd", 0, _dev];
} forEach [
    ["<t color='#E8A33D'>Defuse the EMP device</t>", "_this getUnitTrait 'engineer'", CQ_empDefuse],
    ["<t color='#E8A33D'>Defuse the EMP device (no engineer: slow)</t>", "!(_this getUnitTrait 'engineer') && { !(missionNamespace getVariable ['CQ_empEngAlive', true]) }", CQ_empDefuseAny]
];

// ---- search circle (off-centre: the device is somewhere inside) and countdown label
private _c = _p getPos [random (CQ_empSearchR * 0.6), random 360];
private _m = createMarker ["cq_emp", _c];
_m setMarkerShape "ELLIPSE";
_m setMarkerSize [CQ_empSearchR, CQ_empSearchR];
_m setMarkerBrush "FDiagonal";
_m setMarkerColor "ColorOrange";
private _mt = createMarker ["cq_emp_t", _c];
_mt setMarkerType "mil_warning";
_mt setMarkerColor "ColorOrange";
_mt setMarkerText format [" EMP %1:00", floor (CQ_empTimer / 60)];

CQ_empState = createHashMapFromArray [
    ["pos", _p], ["building", _b], ["device", _dev], ["table", _table], ["prop", _prop], ["holder", objNull],
    ["men", _men], ["tech", _tech], ["endT", time + CQ_empTimer], ["found", false], ["warned", []],
    ["stomper", objNull], ["target", []], ["programmer", objNull], ["loaded", false], ["t0", time]
];
CQ_empPhase = "armed"; publicVariable "CQ_empPhase";
CQ_empEndT = time + CQ_empTimer; publicVariable "CQ_empEndT";
CQ_empKey = format ["emp%1", round time];
["EMP event: device %1 at %2 (next to %3, %4 m from the base, %5 guards, armed pickup %6), goes off in %7 s",
    [_dcls, mapGridPosition _p, typeOf _b, round (_p distance2D CQ_basePos), count units _g, ["none", typeOf _tech] select !isNull _tech, CQ_empTimer]] call CQ_fnc_log;
["EMP event: aimed at the tentacle's head %1 (%2 of relay vehicle / WASP out), device %3 m from it", [mapGridPosition _ctr, count _heads, round (_p distance2D _ctr)]] call CQ_fnc_log;
["EMP device", format ["CSAT planted an EMP device around grid %1. %2 min to defuse it (engineers).", mapGridPosition _c, round (CQ_empTimer / 60)]] call CQ_fnc_announce;
["empStart", [mapGridPosition _c, round (CQ_empTimer / 60)]] call CQ_fnc_say;
[CQ_empKey, 1, format ["EMP device around grid %1", mapGridPosition _c], "armed"] call CQ_fnc_opSide;
true
