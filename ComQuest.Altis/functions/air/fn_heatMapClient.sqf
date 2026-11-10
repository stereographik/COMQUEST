/*
    CQ_fnc_heatMapClient  (client, spawned once from initPlayerLocal)
    Draws the MAGPIE heatmap (CQ_heatPub, CQ_fnc_heatTick) on the main map as soft blobs
    (media\heat_blob_ca.paa, a white radial dot tinted per cell): cold blue where her drones
    scanned, yellow -> red where they saw enemies. Blobs overlap like a weather radar; the
    whole overlay fades out as you zoom in close, so the terrain stays readable. Always on.
*/
if (!hasInterface) exitWith {};
[] spawn {
    disableSerialization;
    waitUntil { sleep 0.5; !isNull ((findDisplay 12) displayCtrl 51) };
    ((findDisplay 12) displayCtrl 51) ctrlAddEventHandler ["Draw", {
        params ["_map"];
        private _pub = missionNamespace getVariable ["CQ_heatPub", []];
        if (_pub isEqualTo []) exitWith {};
        // rebuild the blob lists when a new packet arrives
        if ((_pub select 3) != (uiNamespace getVariable ["CQ_heatSeen", -1])) then {
            uiNamespace setVariable ["CQ_heatSeen", _pub select 3];
            _pub params ["_n", "_cell", "_cells"];
            private _cold = []; private _hot = [];
            {
                private _k = floor (_x / 256);
                private _s = (floor ((_x mod 256) / 16)) / 15;
                private _h = (_x mod 16) / 15;
                private _p = [((floor (_k / _n)) + 0.5) * _cell, ((_k mod _n) + 0.5) * _cell, 0];
                if (_s > 0.1) then { _cold pushBack [_p, _s] };
                if (_h > 0) then { _hot pushBack [_p, _h] };
            } forEach _cells;
            uiNamespace setVariable ["CQ_heatLists", [_cold, _hot, _cell]];
        };
        (uiNamespace getVariable ["CQ_heatLists", [[], [], 300]]) params ["_cold", "_hot", "_cell"];
        if (_cold isEqualTo [] && { _hot isEqualTo [] }) exitWith {};
        // blob size in pixels for one cell at the current zoom
        private _c = _map ctrlMapScreenToWorld [0.5, 0.5];
        private _a = _map ctrlMapWorldToScreen _c;
        private _b = _map ctrlMapWorldToScreen [(_c select 0) + _cell, _c select 1];
        private _px = (((_b select 0) - (_a select 0)) * (getResolution select 0) / safeZoneW) * CQ_heatIconK;
        if (_px < 1) exitWith {};
        private _fade = linearConversion [0.008, 0.05, ctrlMapScale _map, 0.35, 1, true];
        private _tex = uiNamespace getVariable ["CQ_heatTex", ""];
        if (_tex == "") then { _tex = getMissionPath "media\heat_blob_ca.paa"; uiNamespace setVariable ["CQ_heatTex", _tex] };
        private _sc = _px * CQ_heatBlobCold;
        {
            _x params ["_p", "_s"];
            _map drawIcon [_tex, [0.25, 0.6, 1, 0.22 * _s * _fade], _p, _sc, _sc, 0, "", 0];
        } forEach _cold;
        private _sh = _px * CQ_heatBlobHot;
        {
            _x params ["_p", "_h"];
            _map drawIcon [_tex, [1, 0.85 - 0.75 * _h, 0.2 - 0.15 * _h, (0.35 + 0.45 * _h) * _fade], _p, _sh, _sh, 0, "", 0];
        } forEach _hot;
    }];
};
