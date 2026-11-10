/*
    CQ_fnc_heatMapClient  (client, spawned once from initPlayerLocal)
    MAGPIE heatmap on the main map, contacts only, drawn like a thermal / elevation chart:
      - field: each hot cell of CQ_heatPub (CQ_fnc_heatTick) spreads a gaussian (CQ_heatSigma)
        sampled every CQ_heatFine m
      - heightmap mask: the local relief (terrain height against the ground 200 m around)
        bends the contours (CQ_heatTerrain), so the bands follow ridges and valleys
      - quantised in CQ_heatBands stepped bands, blue -> cyan -> green -> yellow -> orange -> red
      - one flat tile per sample, final opacity CQ_heatAlpha (10 %)
    Built once per packet (every 10 s), not per frame; only tiles on screen are drawn, at most
    CQ_heatMaxTiles, strongest first. The Draw handler is added first, so the other scripted
    map layers (drones, live contacts, debug) are drawn over it. CQ_heatEnabled = false: off.
*/
if (!hasInterface || { !CQ_heatEnabled }) exitWith {};
[] spawn {
    disableSerialization;
    waitUntil { sleep 0.5; !isNull ((findDisplay 12) displayCtrl 51) };
    CQ_heatTiles = [];
    // palette: band 0..1 -> colour (image look: blue, cyan, green, yellow, orange, red)
    CQ_heatRamp = [[0, [0.25, 0.3, 1]], [0.22, [0, 0.85, 1]], [0.42, [0.2, 0.95, 0.35]], [0.62, [1, 0.95, 0.15]], [0.8, [1, 0.55, 0]], [1, [1, 0.1, 0.05]]];
    // rebuild the tiles in the background when a new packet arrives
    [] spawn {
        while { true } do {
            sleep 1;
            private _pub = missionNamespace getVariable ["CQ_heatPub", []];
            if (_pub isEqualTo [] || { (_pub select 3) == (missionNamespace getVariable ["CQ_heatBuilt", -1]) }) then { continue };
            CQ_heatBuilt = _pub select 3;
            _pub params ["_n", "_cell", "_cells"];
            private _f = CQ_heatFine;
            private _sig2 = 2 * CQ_heatSigma ^ 2;
            private _reach = ceil ((CQ_heatSigma * 2.6) / _f);
            private _field = createHashMap;
            {
                private _k = floor (_x / 256);
                private _h = (_x mod 16) / 15;
                if (_h <= 0) then { continue };
                private _cx = ((floor (_k / _n)) + 0.5) * _cell;
                private _cy = ((_k mod _n) + 0.5) * _cell;
                private _i0 = floor (_cx / _f); private _j0 = floor (_cy / _f);
                for "_i" from (_i0 - _reach) to (_i0 + _reach) do {
                    for "_j" from (_j0 - _reach) to (_j0 + _reach) do {
                        private _dx = (_i + 0.5) * _f - _cx; private _dy = (_j + 0.5) * _f - _cy;
                        private _w = _h * exp (-((_dx * _dx + _dy * _dy) / _sig2));
                        if (_w < 0.02) then { continue };
                        private _key = _i * 4096 + _j;
                        _field set [_key, (_field getOrDefault [_key, 0]) + _w];
                    };
                };
            } forEach _cells;
            private _tiles = [];
            private _nb = CQ_heatBands;
            {
                private _i = floor (_x / 4096); private _j = _x mod 4096;
                private _p = [(_i + 0.5) * _f, (_j + 0.5) * _f];
                if (surfaceIsWater _p) then { continue };
                private _v = _y min 1;
                // heightmap mask: higher than the ground around -> hotter, lower -> cooler
                private _hc = getTerrainHeightASL _p;
                private _ha = 0;
                { _ha = _ha + getTerrainHeightASL (_p getPos [200, _x]) } forEach [0, 90, 180, 270];
                private _rel = ((_hc - _ha / 4) / 25) max -1 min 1;
                private _edge = ((_v min (1 - _v)) * 2) max 0.25;      // strongest effect on the band edges
                _v = ((_v + CQ_heatTerrain * _rel * _edge) max 0) min 1;
                if (_v < 0.12) then { continue };
                private _b = (floor (_v * _nb)) min (_nb - 1);
                private _t = (_b + 0.5) / _nb;
                // ramp colour
                private _col = [1, 0.1, 0.05];
                for "_r" from 1 to (count CQ_heatRamp - 1) do {
                    (CQ_heatRamp select (_r - 1)) params ["_t0", "_c0"];
                    (CQ_heatRamp select _r) params ["_t1", "_c1"];
                    if (_t <= _t1) exitWith {
                        private _k2 = (_t - _t0) / (_t1 - _t0);
                        _col = [0, 1, 2] apply { (_c0 select _x) + ((_c1 select _x) - (_c0 select _x)) * _k2 };
                    };
                };
                _col pushBack CQ_heatAlpha;
                _tiles pushBack [_t, [_p select 0, _p select 1, 0], _col];
            } forEach _field;
            _tiles sort false;
            CQ_heatTiles = _tiles;
        };
    };
    ((findDisplay 12) displayCtrl 51) ctrlAddEventHandler ["Draw", {
        params ["_map"];
        if (CQ_heatTiles isEqualTo []) exitWith {};
        private _w0 = _map ctrlMapScreenToWorld [safeZoneX, safeZoneY + safeZoneH];
        private _w1 = _map ctrlMapScreenToWorld [safeZoneX + safeZoneW, safeZoneY];
        private _m = CQ_heatFine;
        private _x0 = (_w0 select 0) - _m; private _x1 = (_w1 select 0) + _m;
        private _y0 = (_w0 select 1) - _m; private _y1 = (_w1 select 1) + _m;
        private _hs = CQ_heatFine / 2;
        private _tex = "#(rgb,8,8,3)color(1,1,1,1)";
        private _left = CQ_heatMaxTiles;
        {
            _x params ["", "_p", "_c"];
            if ((_p select 0) < _x0 || { (_p select 0) > _x1 } || { (_p select 1) < _y0 } || { (_p select 1) > _y1 }) then { continue };
            _map drawRectangle [_p, _hs, _hs, 0, _c, _tex];
            _left = _left - 1;
            if (_left <= 0) then { break };
        } forEach CQ_heatTiles;
    }];
};
