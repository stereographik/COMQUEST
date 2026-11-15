/*
    CQ_fnc_boat  (server)
    Engineers' inflatable boats. An Engineer with a ToolKit inflates a boat in the water (at least
    CQ_boatMinDepth m deep at his feet: half legs in, or swimming), CQ_boatMax out at a time; packing one of his boats
    (empty, within CQ_boatPackRange m) gives it back; at the base he recalls them all (like the
    sandbag walls). A boat belongs to the player's UID (CQ_boats) and to his squad: only its
    members get in (CQ_squadGroup). Count published as CQ_bt_<uid>.
      ["inflate", [_unit]]
      ["pack",    [_unit, _boat]]
      ["recall",  [_unit]]
*/
params ["_mode", ["_args", []]];
if (!isServer) exitWith {};
if (isNil "CQ_boats") then { CQ_boats = createHashMap };

private _publish = {
    params ["_uid", "_list"];
    CQ_boats set [_uid, _list];
    missionNamespace setVariable ["CQ_bt_" + _uid, count _list, true];
};

switch (_mode) do {

    case "inflate": {
        _args params ["_unit"];
        private _uid = getPlayerUID _unit;
        private _mine = (CQ_boats getOrDefault [_uid, []]) select { alive _x };
        private _p = getPosASL _unit;
        private _depth = -(getTerrainHeightASL _p);
        private _why = switch (true) do {
            case (!(_unit getUnitTrait "engineer")): { "Only engineers carry inflatable boats." };
            case (!("ToolKit" in items _unit)): { "You need a toolkit to inflate a boat." };
            case (count _mine >= CQ_boatMax): { format ["You already have %1 boats out. Pack one, or recall them from the base.", CQ_boatMax] };
            case (vehicle _unit != _unit): { "Get out first." };
            case (!surfaceIsWater _p || { _depth < CQ_boatMinDepth }): { "Wade in deeper first: water at least half way up your legs, or swim." };
            default { "" };
        };
        if (_why != "") exitWith { [_why] remoteExec ["hint", _unit] };
        // afloat, 4 m away toward the deepest water around him, its bow out to sea
        private _best = _p getPos [4, getDir _unit]; private _bz = 1e9;
        for "_a" from 0 to 315 step 45 do {
            private _q = _p getPos [4, _a];
            private _z = getTerrainHeightASL _q;
            if (surfaceIsWater _q && { _z < _bz }) then { _bz = _z; _best = _q };
        };
        private _b = createVehicle [CQ_boatClass, [_best select 0, _best select 1, 0], [], 0, "CAN_COLLIDE"];
        _b setDir (_p getDir _best);
        _b setPosASL [_best select 0, _best select 1, 0.3];
        _b setVariable ["CQ_boatOwner", _uid, true];
        _b setVariable ["CQ_squadGroup", group _unit, true];   // his squad's members only
        _b setVariable ["CQ_boughtBy", "inflatable", true];    // ours (not an enemy vehicle)
        _mine pushBack _b;
        [_uid, _mine] call _publish;
        [format ["Boat inflated (%1/%2). Pack it here, or recall your boats from the base.", count _mine, CQ_boatMax]] remoteExec ["hint", _unit];
        ["%1 inflated a boat at grid %2 (%3/%4)", [name _unit, mapGridPosition _b, count _mine, CQ_boatMax]] call CQ_fnc_log;
    };

    case "pack": {
        _args params ["_unit", "_b"];
        private _uid = getPlayerUID _unit;
        if (isNull _b || { (_b getVariable ["CQ_boatOwner", ""]) != _uid } || { _unit distance _b > CQ_boatPackRange + 2 }) exitWith {};
        if ((crew _b) findIf { alive _x } > -1) exitWith { ["Everyone out of the boat first."] remoteExec ["hint", _unit] };
        private _mine = (CQ_boats getOrDefault [_uid, []]) select { alive _x && { _x != _b } };
        private _g = mapGridPosition _b;
        deleteVehicle _b;
        [_uid, _mine] call _publish;
        [format ["Boat packed (%1/%2 out).", count _mine, CQ_boatMax]] remoteExec ["hint", _unit];
        ["%1 packed a boat at grid %2", [name _unit, _g]] call CQ_fnc_log;
    };

    case "recall": {
        _args params ["_unit"];
        if (_unit distance2D CQ_basePos > CQ_baseRadius) exitWith {};
        private _uid = getPlayerUID _unit;
        private _all = (CQ_boats getOrDefault [_uid, []]) select { !isNull _x };
        private _busy = _all select { alive _x && { (crew _x) findIf { alive _x } > -1 } };   // someone aboard: stays
        { deleteVehicle _x } forEach (_all - _busy);
        [_uid, _busy] call _publish;
        [format ["%1 boat%2 recalled%3.", count _all - count _busy, ["s", ""] select ((count _all - count _busy) == 1),
            ["", format [" (%1 in use, left out)", count _busy]] select (_busy isNotEqualTo [])]] remoteExec ["hint", _unit];
        ["%1 recalled %2 boats", [name _unit, count _all - count _busy]] call CQ_fnc_log;
    };
};
