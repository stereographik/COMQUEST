/*
    CQ_fnc_rangeMapClient  (client, once, from initPlayerLocal; drawn by CQ_fnc_magMapClient)
    RANGE MAP: the ground every enemy MAGPIE sees right now (CQ_magVisible) can fire on.
    For each of them, the terrain within his weapon range (CQ_rangeOf) is cut into cells of
    CQ_rangeCell m; a cell is "in range" when a standing man in it (1.7 m) is in line of sight
    of the enemy's eyes: terrain (terrainIntersectASL), then buildings, walls and vegetation
    (lineIntersectsSurfaces, VIEW geometry). Cells inside +/- CQ_rangeCone degrees of where he
    faces form his fire cone (drawn darker).
    Cost control: an enemy is only recomputed when he moved more than CQ_rangeMove m (his cone
    only when he turned more than 20 degrees); line-of-sight checks run in the background,
    CQ_rangeBudget at a time. Each enemy's cells are added to / removed from one shared grid
    (CQ_rangeAgg: cell key -> [x, y, enemies, cones]) that the map draws.
*/
if (!hasInterface || { !CQ_rangeMap }) exitWith {};
CQ_rangeAgg = createHashMap;
CQ_rangeUnits = createHashMap;     // hashValue -> [unit, pos, dir, cells [[key, x, y, bearing]], range]

private _rangeOf = {
    params ["_u"];
    private _v = vehicle _u;
    if (_v != _u) exitWith {
        if (_v isKindOf "StaticWeapon") exitWith { [CQ_rangeOf get "static", 0] select (_v isKindOf "O_static_AA_F") };
        if (_v isKindOf "Air") exitWith { 0 };
        [0, CQ_rangeOf get "vehicle"] select ((_u in [gunner _v, commander _v]) && { (count weapons _v) > 0 })
    };
    private _w = toLower primaryWeapon _u;
    private _r = CQ_rangeOf get "rifle";
    if ("srifle" in _w) then { _r = CQ_rangeOf get "sniper" };
    if ("lmg" in _w || { "mmg" in _w }) then { _r = CQ_rangeOf get "mg" };
    if (secondaryWeapon _u != "") then { _r = _r max (CQ_rangeOf get "launcher") };
    _r
};
// add (+1) or remove (-1) one enemy's contribution to the shared grid
private _apply = {
    params ["_rec", "_sgn"];
    _rec params ["", "", "_dir", "_cells"];
    {
        _x params ["_k", "_cx", "_cy", "_b"];
        private _cone = [0, 1] select (abs ((_b - _dir + 540) % 360 - 180) <= CQ_rangeCone);
        private _a = CQ_rangeAgg getOrDefault [_k, [_cx, _cy, 0, 0]];
        _a set [2, (_a select 2) + _sgn];
        _a set [3, (_a select 3) + _sgn * _cone];
        if ((_a select 2) <= 0) then { CQ_rangeAgg deleteAt _k } else { CQ_rangeAgg set [_k, _a] };
    } forEach _cells;
};
[_rangeOf, _apply] spawn {
    params ["_rangeOf", "_apply"];
    private _c = CQ_rangeCell;
    private _n = 0;
    while { true } do {
        private _vis = (missionNamespace getVariable ["CQ_magVisible", []]) select { alive _x };
        private _keys = _vis apply { hashValue _x };
        // enemies no longer in sight: their cells go
        { if !(_x in _keys) then { [_y, -1] call _apply; CQ_rangeUnits deleteAt _x } } forEach +CQ_rangeUnits;
        {
            private _u = _x;
            private _k = hashValue _u;
            private _rec = CQ_rangeUnits getOrDefault [_k, []];
            private _pos = getPosASL _u;
            private _dir = getDir (vehicle _u);
            if (_rec isNotEqualTo [] && { (_rec select 1) distance2D _pos < CQ_rangeMove }) then {
                // same place: only re-aim the cone if he turned
                if (abs (((_rec select 2) - _dir + 540) % 360 - 180) > 20) then {
                    [_rec, -1] call _apply; _rec set [2, _dir]; [_rec, 1] call _apply;
                };
                continue;
            };
            private _r = [_u] call _rangeOf;
            if (_r <= 0) then { continue };
            // line of sight from his eyes to a standing man in every cell within range
            private _v = vehicle _u;
            private _eye = _pos vectorAdd [0, 0, [1.6, 2.6] select (_v != _u)];
            private _cells = [];
            private _ix0 = floor (((_pos select 0) - _r) / _c);
            private _iy0 = floor (((_pos select 1) - _r) / _c);
            private _ix1 = floor (((_pos select 0) + _r) / _c);
            private _iy1 = floor (((_pos select 1) + _r) / _c);
            for "_ix" from _ix0 to _ix1 do {
                for "_iy" from _iy0 to _iy1 do {
                    private _cx = (_ix + 0.5) * _c; private _cy = (_iy + 0.5) * _c;
                    private _d = [_cx, _cy] distance2D _pos;
                    if (_d > _r) then { continue };
                    if (surfaceIsWater [_cx, _cy]) then { continue };
                    private _t = AGLToASL [_cx, _cy, 1.7];
                    _n = _n + 1;
                    if (_n mod CQ_rangeBudget == 0) then { uiSleep 0.01 };
                    if (terrainIntersectASL [_eye, _t]) then { continue };
                    if ((lineIntersectsSurfaces [_eye, _t, _v, objNull, true, 1, "VIEW", "FIRE"]) isNotEqualTo []) then { continue };
                    _cells pushBack [format ["%1_%2", _ix, _iy], _cx, _cy, _pos getDir [_cx, _cy]];
                };
            };
            if (!alive _u) then { continue };
            if (_rec isNotEqualTo []) then { [_rec, -1] call _apply };
            _rec = [_u, _pos, _dir, _cells, _r];
            CQ_rangeUnits set [_k, _rec];
            [_rec, 1] call _apply;
        } forEach _vis;
        uiSleep 1;
    };
};
