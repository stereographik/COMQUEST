/*
    CQ_fnc_debugMap  (client, DEBUG only)
    Draws every unit and crewed vehicle on the map, coloured by side:
    CSAT red, NATO blue, AAF green, civilians purple. Group leaders show their callsign;
    CSAT groups and vehicles also show role and ammo % (published by the server in debug).
*/
if (!hasInterface || { !CQ_debug }) exitWith {};

[] spawn {
    disableSerialization;
    waitUntil { sleep 0.5; !isNull ((findDisplay 12) displayCtrl 51) };
    ((findDisplay 12) displayCtrl 51) ctrlAddEventHandler ["Draw", {
        params ["_map"];
        private _col = {
            switch (_this) do {
                case east: { [0.9, 0.15, 0.15, 1] };
                case west: { [0.2, 0.45, 1, 1] };
                case independent: { [0.1, 0.7, 0.2, 1] };
                default { [0.7, 0.3, 0.9, 1] };
            }
        };
        private _icon = {
            private _i = getText (configOf _this >> "icon");
            private _p = getText (configFile >> "CfgVehicleIcons" >> _i);
            [_p, _i] select (_p == "")
        };

        // Crewed vehicles (one icon for the vehicle and everyone inside)
        {
            if (alive _x && { (crew _x) isNotEqualTo [] }) then {
                private _g = group effectiveCommander _x;
                private _txt = format ["%1 %2", groupId _g, _x getVariable ["CQ_dbg", ""]];
                _map drawIcon [_x call _icon, (side _g) call _col, getPosASLVisual _x, 24, 24, getDirVisual _x, _txt, 1, 0.035, "PuristaMedium", "right"];
            };
        } forEach vehicles;

        // Soldiers on foot
        {
            if (vehicle _x == _x) then {
                private _g = group _x;
                private _txt = ["", format ["%1 %2", groupId _g, _g getVariable ["CQ_dbg", ""]]] select (leader _g == _x);
                _map drawIcon [_x call _icon, (side _g) call _col, getPosASLVisual _x, 16, 16, getDirVisual _x, _txt, 1, 0.03, "PuristaMedium", "right"];
            };
        } forEach allUnits;
    }];
    systemChat "[CQ] Debug map on: every unit is drawn on the map";
};
