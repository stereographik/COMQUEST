/*
    CQ_fnc_magMapClient  (client, spawned once from initPlayerLocal)
    What MAGPIE gives every player on the map, live:
      - her drones (blue UAV icon + callsign), always
      - every enemy one of her drones has in sight right now (CQ_magVisible, refreshed by the
        server every CQ_magDetectEvery s; drawn at its live position, red). Out of sight = gone.
*/
if (!hasInterface) exitWith {};
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
        {
            if (alive _x) then {
                private _sz = [14, 22] select (!(_x isKindOf "CAManBase"));
                _map drawIcon [_x call _icon, [0.9, 0.15, 0.15, 0.95], getPosASLVisual _x, _sz, _sz, getDirVisual _x, "", 0, 0.03, "PuristaMedium", "right"];
            };
        } forEach (missionNamespace getVariable ["CQ_magVisible", []]);
        {
            if (alive _x) then {
                _map drawIcon [_x call _icon, [0.25, 0.55, 1, 1], getPosASLVisual _x, 26, 26, getDirVisual _x,
                    format ["MAGPIE %1", _x getVariable ["CQ_magName", ""]], 1, 0.035, "PuristaMedium", "right"];
            };
        } forEach (missionNamespace getVariable ["CQ_magVehs", []]);
    }];
};
