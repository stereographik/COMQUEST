/*
    CQ_fnc_heatMapClient  (client, spawned once from initPlayerLocal)
    Draws the MAGPIE heatmap (CQ_heatPub, CQ_fnc_heatTick) on the main map as soft blobs
    (media\heat_blob_ca.paa, a white radial dot tinted per cell): cold blue where her drones
    scanned, yellow -> red where they saw enemies.
    Kept cheap: the packet is decoded once when it arrives (not every frame); the cold layer is
    merged into big cells (CQ_heatColdMerge x CQ_heatMerge cells each); only blobs on screen are
    drawn, at most CQ_heatMaxBlobs per layer (strongest first). CQ_heatEnabled = false turns the
    overlay off.
*/
if (!hasInterface || { !CQ_heatEnabled }) exitWith {};
[] spawn {
    disableSerialization;
    waitUntil { sleep 0.5; !isNull ((findDisplay 12) displayCtrl 51) };
    CQ_heatTex = getMissionPath "media\heat_blob_ca.paa";
    ((findDisplay 12) displayCtrl 51) ctrlAddEventHandler ["Draw", {
        params ["_map"];
        private _pub = missionNamespace getVariable ["CQ_heatPub", []];
        if (_pub isEqualTo []) exitWith {};
        // decode once per packet
        if ((_pub select 3) != (missionNamespace getVariable ["CQ_heatSeen", -1])) then {
            CQ_heatSeen = _pub select 3;
            _pub params ["_n", "_cell", "_cells"];
            private _m = CQ_heatColdMerge;
            private _big = createHashMap;
            private _hot = [];
            {
                private _k = floor (_x / 256);
                private _s = (floor ((_x mod 256) / 16)) / 15;
                private _h = (_x mod 16) / 15;
                private _i = floor (_k / _n);
                private _j = _k mod _n;
                if (_s > 0.1) then {
                    private _bk = (floor (_i / _m)) * 1000 + floor (_j / _m);
                    _big set [_bk, (_big getOrDefault [_bk, 0]) + _s];
                };
                if (_h > 0) then { _hot pushBack [_h, [(_i + 0.5) * _cell, (_j + 0.5) * _cell, 0]] };
            } forEach _cells;
            private _bc = _cell * _m;
            private _cold = [];
            { _cold pushBack [(_y / (_m * _m)) min 1, [((floor (_x / 1000)) + 0.5) * _bc, ((_x mod 1000) + 0.5) * _bc, 0]] } forEach _big;
            _cold sort false; _hot sort false;          // strongest first
            CQ_heatLists = [_cold, _hot, _cell];
        };
        (missionNamespace getVariable ["CQ_heatLists", [[], [], 300]]) params ["_cold", "_hot", "_cell"];
        if (_cold isEqualTo [] && { _hot isEqualTo [] }) exitWith {};
        // pixels per cell at the current zoom, and the visible world rectangle (+ margin)
        private _w0 = _map ctrlMapScreenToWorld [safeZoneX, safeZoneY + safeZoneH];
        private _w1 = _map ctrlMapScreenToWorld [safeZoneX + safeZoneW, safeZoneY];
        private _px = (safeZoneW / (((_w1 select 0) - (_w0 select 0)) max 1)) * _cell * (getResolution select 0) / safeZoneW * CQ_heatIconK;
        if (_px < 0.5) exitWith {};
        private _fade = linearConversion [0.008, 0.05, ctrlMapScale _map, 0.35, 1, true];
        private _tex = CQ_heatTex;
        private _mg = _cell * 3;
        private _x0 = (_w0 select 0) - _mg; private _x1 = (_w1 select 0) + _mg;
        private _y0 = (_w0 select 1) - _mg; private _y1 = (_w1 select 1) + _mg;
        private _sc = _px * CQ_heatColdMerge * CQ_heatBlobCold;
        private _left = CQ_heatMaxBlobs;
        {
            _x params ["_s", "_p"];
            if ((_p select 0) < _x0 - _mg * CQ_heatColdMerge || { (_p select 0) > _x1 + _mg * CQ_heatColdMerge } || { (_p select 1) < _y0 - _mg * CQ_heatColdMerge } || { (_p select 1) > _y1 + _mg * CQ_heatColdMerge }) then { continue };
            _map drawIcon [_tex, [0.25, 0.6, 1, 0.22 * _s * _fade], _p, _sc, _sc, 0, "", 0];
            _left = _left - 1;
            if (_left <= 0) then { break };
        } forEach _cold;
        private _sh = _px * CQ_heatBlobHot;
        _left = CQ_heatMaxBlobs;
        {
            _x params ["_h", "_p"];
            if ((_p select 0) < _x0 || { (_p select 0) > _x1 } || { (_p select 1) < _y0 } || { (_p select 1) > _y1 }) then { continue };
            _map drawIcon [_tex, [1, 0.85 - 0.75 * _h, 0.2 - 0.15 * _h, (0.35 + 0.45 * _h) * _fade], _p, _sh, _sh, 0, "", 0];
            _left = _left - 1;
            if (_left <= 0) then { break };
        } forEach _hot;
    }];
};
