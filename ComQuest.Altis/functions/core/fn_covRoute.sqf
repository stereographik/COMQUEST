/*
    CQ_fnc_covRoute  (server)
    ["tick"] call CQ_fnc_covRoute;          director task: one HQ at a time gets its route computed
    [ "compute", _hq ] spawn CQ_fnc_covRoute;

    COVERED APPROACH: for every enemy HQ, once, the best covered way in for the friendlies, shown on
    the map (CQ_fnc_covRouteClient) once the HQ is on the players' map (MAGPIE saw it, or intel).

    The ground within CQ_covRadius m is cut in CQ_covCell m cells. Each cell:
      exposure  share of the watchers that see a man standing there (1.5 m): the HQ itself (an eye
                CQ_covHqEye m up, counted twice) and the CQ_covHills highest points around it
                (2 m up). Terrain blocks the view (terrainIntersectASL), then buildings, walls and
                rocks (lineIntersectsSurfaces, FIRE). Trees and bushes are ignored.
      cover     a building, wall or rock within CQ_covNear m, or a ditch (the cell lies
                CQ_covDitch m+ below the mean of its neighbours): cheaper to cross
      slope     steep cells cost much more; water cannot be crossed
    One Dijkstra search from the HQ gives the cheapest way from every cell. Start points are tried
    all around at 90% of the radius, except the 45 deg cone that points from the HQ to the carrier
    (the enemy's rear); the route kept is the one least seen (exposure per metre).
    Result: CQ_covRoutes (public) = [[hqId, [[x, y, exposure], ...], covered %], ...]
*/
params ["_mode", ["_hq", createHashMap]];
if (!isServer) exitWith {};

switch (_mode) do {

    case "tick": {
        if (isNil "CQ_covRoutes") then { CQ_covRoutes = []; CQ_covDone = createHashMap; CQ_covBusy = false };
        // routes of HQs that are gone, or not on the players' map yet, are not published
        private _seen = missionNamespace getVariable ["CQ_magHqSeen", createHashMap];
        private _pub = [];
        {
            private _h = CQ_hqs getOrDefault [_x, createHashMap];
            if (count _h > 0 && { (_h get "state") in CQ_activeStates } && { _x in _seen || { _h getOrDefault ["revealed", false] } }) then {
                _pub pushBack ([_x] + _y);
            };
        } forEach CQ_covDone;
        if (_pub isNotEqualTo CQ_covRoutes) then { CQ_covRoutes = _pub; publicVariable "CQ_covRoutes" };
        if (CQ_covBusy) exitWith {};
        private _todo = (values CQ_hqs) select { (_x get "state") in CQ_activeStates && { !((_x get "id") in CQ_covDone) } };
        if (_todo isEqualTo []) exitWith {};
        CQ_covBusy = true;
        ["compute", _todo select 0] spawn CQ_fnc_covRoute;
    };

    case "compute": {
        private _id = _hq get "id";
        private _c = _hq get "pos";
        private _t0 = diag_tickTime;
        private _rad = CQ_covRadius;
        private _cs = CQ_covCell;
        private _n = 2 * ceil (_rad / _cs) + 1;                 // cells per side, the HQ in the middle cell
        private _half = (_n - 1) / 2;
        private _x0 = (_c select 0) - _half * _cs;
        private _y0 = (_c select 1) - _half * _cs;
        private _pos = { params ["_i", "_j"]; [_x0 + _i * _cs, _y0 + _j * _cs, 0] };
        // heights
        private _hgt = [];
        for "_j" from 0 to _n - 1 do { for "_i" from 0 to _n - 1 do { _hgt pushBack (getTerrainHeightASL ([_i, _j] call _pos)) } };
        // watchers: the HQ and the highest points around it (CQ_covHills, 300 m apart, 200 m+ out)
        private _cand = [];
        for "_j" from 0 to _n - 1 step 2 do {
            for "_i" from 0 to _n - 1 step 2 do {
                private _p = [_i, _j] call _pos;
                private _d = _p distance2D _c;
                if (_d > 200 && { _d < _rad }) then { _cand pushBack [_hgt select (_j * _n + _i), _p] };
            };
        };
        _cand sort false;
        private _eyes = [[(_c select 0), (_c select 1), (getTerrainHeightASL _c) + CQ_covHqEye], [(_c select 0), (_c select 1), (getTerrainHeightASL _c) + CQ_covHqEye]];   // the HQ counts twice
        private _hills = [];
        {
            if (count _hills >= CQ_covHills) exitWith {};
            private _p = _x select 1;
            if (_hills findIf { _x distance2D _p < 300 } < 0) then { _hills pushBack _p };
        } forEach _cand;
        { _eyes pushBack [_x select 0, _x select 1, (getTerrainHeightASL _x) + 2] } forEach _hills;
        sleep 0.01;
        // cost of every cell
        private _cost = [];
        private _expo = [];
        private _k = 0;
        for "_j" from 0 to _n - 1 do {
            for "_i" from 0 to _n - 1 do {
                private _p = [_i, _j] call _pos;
                private _h = _hgt select (_j * _n + _i);
                if ((_p distance2D _c) > _rad + _cs || { _h < 0.3 }) then { _cost pushBack -1; _expo pushBack 1; continue };   // outside, or water
                private _man = [_p select 0, _p select 1, _h + 1.5];
                private _seenBy = 0;
                {
                    if !(terrainIntersectASL [_x, _man]) then {
                        if ((lineIntersectsSurfaces [_x, _man, objNull, objNull, true, 1, "FIRE", "NONE"]) isEqualTo []) then { _seenBy = _seenBy + 1 };
                    };
                } forEach _eyes;
                private _e = _seenBy / (count _eyes);
                // neighbours: slope and ditch
                private _sum = 0; private _cnt = 0; private _dz = 0;
                {
                    _x params ["_di", "_dj"];
                    private _ii = _i + _di; private _jj = _j + _dj;
                    if (_ii >= 0 && { _ii < _n } && { _jj >= 0 } && { _jj < _n }) then {
                        private _hn = _hgt select (_jj * _n + _ii);
                        _sum = _sum + _hn; _cnt = _cnt + 1; _dz = _dz max (abs (_hn - _h));
                    };
                } forEach [[1, 0], [-1, 0], [0, 1], [0, -1]];
                private _ditch = _cnt > 0 && { (_sum / _cnt) - _h >= CQ_covDitch };
                private _slope = _dz / _cs;
                private _cover = (nearestTerrainObjects [_p, ["BUILDING", "HOUSE", "WALL", "ROCK", "ROCKS", "BUNKER", "FORTRESS", "RUIN"], CQ_covNear, false, true]) isNotEqualTo [];
                private _v = 1 + CQ_covExposeCost * _e - ([0, 0.5] select _ditch) - ([0, 0.4] select _cover);
                _v = (_v max 0.3) * ([1, 4] select (_slope > 0.45)) * ([1, 20] select (_slope > 0.8));
                _cost pushBack _v; _expo pushBack _e;
                _k = _k + 1;
                if (_k mod 60 == 0) then { sleep 0.01 };   // spread over many frames
            };
        };
        // Dijkstra from the HQ cell (binary heap of [dist, index])
        private _nCells = _n * _n;
        private _dist = []; _dist resize _nCells; _dist = _dist apply { 1e12 };
        private _prev = []; _prev resize _nCells; _prev = _prev apply { -1 };
        private _src = _half * _n + _half;
        _dist set [_src, 0];
        private _heap = [[0, _src]];
        private _push = {
            params ["_e"];
            _heap pushBack _e;
            private _i = (count _heap) - 1;
            while { _i > 0 } do {
                private _p = floor ((_i - 1) / 2);
                if (((_heap select _p) select 0) <= (_e select 0)) exitWith {};
                _heap set [_i, _heap select _p]; _i = _p;
            };
            _heap set [_i, _e];
        };
        private _pop = {
            private _top = _heap select 0;
            private _last = _heap deleteAt ((count _heap) - 1);
            private _m = count _heap;
            if (_m > 0) then {
                private _i = 0;
                while { true } do {
                    private _l = 2 * _i + 1;
                    if (_l >= _m) exitWith {};
                    private _r = _l + 1;
                    private _s = if (_r < _m && { ((_heap select _r) select 0) < ((_heap select _l) select 0) }) then { _r } else { _l };
                    if (((_heap select _s) select 0) >= (_last select 0)) exitWith {};
                    _heap set [_i, _heap select _s]; _i = _s;
                };
                _heap set [_i, _last];
            };
            _top
        };
        private _steps = [[1, 0, 1], [-1, 0, 1], [0, 1, 1], [0, -1, 1], [1, 1, 1.414], [1, -1, 1.414], [-1, 1, 1.414], [-1, -1, 1.414]];
        private _ops = 0;
        while { _heap isNotEqualTo [] } do {
            (call _pop) params ["_d", "_u"];
            if (_d > (_dist select _u)) then { continue };
            private _ui = _u mod _n; private _uj = floor (_u / _n);
            private _cu = _cost select _u;
            {
                _x params ["_di", "_dj", "_w"];
                private _ii = _ui + _di; private _jj = _uj + _dj;
                if (_ii < 0 || { _ii >= _n } || { _jj < 0 } || { _jj >= _n }) then { continue };
                private _v = _jj * _n + _ii;
                private _cv = _cost select _v;
                if (_cv < 0) then { continue };
                private _nd = _d + _w * _cs * (_cu + _cv) / 2;
                if (_nd < (_dist select _v)) then { _dist set [_v, _nd]; _prev set [_v, _u]; [[_nd, _v]] call _push };
            } forEach _steps;
            _ops = _ops + 1;
            if (_ops mod 150 == 0) then { sleep 0.01 };
        };
        // start points: every 10 deg at 90% of the radius, except the cone toward the carrier
        private _back = if (isNil "CQ_carrierPos") then { -999 } else { _c getDir CQ_carrierPos };
        private _best = []; private _bestScore = 1e9;
        for "_a" from 0 to 350 step 10 do {
            private _off = abs (((_a - _back) + 540) mod 360 - 180);
            if (_off < CQ_covCone / 2) then { continue };
            private _sp = _c getPos [_rad * 0.9, _a];
            private _si = round (((_sp select 0) - _x0) / _cs); private _sj = round (((_sp select 1) - _y0) / _cs);
            if (_si < 0 || { _si >= _n } || { _sj < 0 } || { _sj >= _n }) then { continue };
            private _s = _sj * _n + _si;
            if ((_dist select _s) >= 1e12) then { continue };
            // walk back to the HQ: exposure per metre
            private _path = []; private _u = _s; private _ex = 0; private _len = 0; private _guard = 0;
            while { _u >= 0 && { _guard < 2000 } } do {
                private _p = [_u mod _n, floor (_u / _n)] call _pos;
                if (_path isNotEqualTo []) then {
                    private _l = (_path select ((count _path) - 1)) distance2D _p;
                    _len = _len + _l; _ex = _ex + _l * (_expo select _u);
                };
                _path pushBack [_p select 0, _p select 1, _expo select _u];
                _u = _prev select _u; _guard = _guard + 1;
            };
            private _score = _ex / (_len max 1);
            if (_score < _bestScore) then { _bestScore = _score; _best = _path };
        };
        if (_best isEqualTo []) exitWith {
            CQ_covDone set [_id, [[], 0]]; CQ_covBusy = false;
            ["Covered approach HQ #%1: no route found", [_id]] call CQ_fnc_log;
        };
        // thin the line: keep a point every 2 cells, and wherever the exposure class changes
        private _cls = { if (_this < 0.25) then { 0 } else { [1, 2] select (_this >= 0.5) } };
        private _thin = [_best select 0];
        { if (_forEachIndex mod 2 == 0 || { ((_x select 2) call _cls) != (((_best select (_forEachIndex - 1)) select 2) call _cls) }) then { _thin pushBack _x } } forEach (_best select [1, (count _best) - 1]);
        _thin pushBack (_best select ((count _best) - 1));
        private _pct = round (100 * (1 - _bestScore));
        CQ_covDone set [_id, [_thin, _pct]];
        CQ_covBusy = false;
        ["Covered approach HQ #%1: %2 %% covered, %3 m from %4 deg, %5 watchers, %6 cells, %7 s", [_id, _pct,
            round (((_best select 0) distance2D _c)), round (_c getDir (_best select 0)), count _eyes, _nCells, round (diag_tickTime - _t0)]] call CQ_fnc_log;
    };
};
