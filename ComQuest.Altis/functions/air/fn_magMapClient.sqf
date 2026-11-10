/*
    CQ_fnc_magMapClient  (client, spawned once from initPlayerLocal)
    What MAGPIE gives every player on the map, live:
      - her drones (blue UAV icon + callsign), always
      - radar echoes of every enemy one of her drones has in sight (CQ_magVisible, refreshed by
        the server every CQ_magDetectEvery s), crisp circles of CQ_echoPx pixels whatever the
        zoom, chart red (CQ_echoColor):
          live    a filled circle at the enemy's live position while he is in sight
          trace   every CQ_magDetectEvery s an empty circle is left where he was, fading out
                  over CQ_echoLife s (shows the movement)
        Out of sight = the live circle goes, the last traces fade.
*/
if (!hasInterface) exitWith {};
// traces: a snapshot of the visible enemies' positions every detection pass, kept CQ_echoLife s
CQ_echoes = [];
[] spawn {
    while { true } do {
        private _now = time;
        CQ_echoes = CQ_echoes select { _now - (_x select 1) < CQ_echoLife };
        { if (alive _x) then { CQ_echoes pushBack [getPosASL _x, _now] } } forEach (missionNamespace getVariable ["CQ_magVisible", []]);
        sleep CQ_magDetectEvery;
    };
};
[] spawn {
    disableSerialization;
    waitUntil { sleep 0.5; !isNull ((findDisplay 12) displayCtrl 51) };
    ((findDisplay 12) displayCtrl 51) ctrlAddEventHandler ["Draw", {
        params ["_map"];
        private _icon = {
            private _i = getText (configOf _this >> "icon");
            private _p = getText (configFile >> "CfgVehicleIcons" >> _i);
            [_p, _i] select (_p == "")
        };
        // radar echoes: CQ_echoPx pixels across at any zoom (metres per screen pixel right now)
        private _r = (CQ_echoPx / 2) * ((_map ctrlMapScreenToWorld [0.5, 0.5]) distance2D (_map ctrlMapScreenToWorld [0.5 + pixelW, 0.5]));
        CQ_echoColor params ["_cr", "_cg", "_cb"];
        private _now = time;
        {
            _x params ["_p", "_t"];
            private _a = 1 - (_now - _t) / CQ_echoLife;
            if (_a > 0) then { _map drawEllipse [_p, _r, _r, 0, [_cr, _cg, _cb, _a], ""] };
        } forEach (missionNamespace getVariable ["CQ_echoes", []]);
        {
            if (alive _x) then { _map drawEllipse [getPosASLVisual _x, _r, _r, 0, [_cr, _cg, _cb, 1], "#(rgb,8,8,3)color(1,1,1,1)"] };
        } forEach (missionNamespace getVariable ["CQ_magVisible", []]);
        {
            if (alive _x) then {
                _map drawIcon [_x call _icon, [0.25, 0.55, 1, 1], getPosASLVisual _x, 26, 26, getDirVisual _x,
                    format ["MAGPIE %1", _x getVariable ["CQ_magName", ""]], 1, 0.035, "PuristaMedium", "right"];
            };
        } forEach (missionNamespace getVariable ["CQ_magVehs", []]);
    }];
};
