/*
    CQ_fnc_debugMap  (client, debug panel users: debug mission, host or logged-in admin)
    Map overlay, switched from the debug panel (all off by default outside CQ_debug):
      CQ_dbgShowEnemy   every enemy unit and crewed vehicle (CSAT red, guerillas green)
      CQ_dbgShowFriend  every friendly unit and crewed vehicle (blue), civilians purple
      CQ_dbgShowHq      every enemy HQ site with its number and state (list sent by the server
                        with each panel refresh, CQ_dbgHqList)
    Group leaders show their callsign; CSAT groups and vehicles also show role and ammo %.
*/
if (!hasInterface) exitWith {};
if (isNil "CQ_dbgShowEnemy") then { CQ_dbgShowEnemy = false };     // switched on from the debug panel
if (isNil "CQ_dbgShowFriend") then { CQ_dbgShowFriend = false };
if (isNil "CQ_dbgShowHq") then { CQ_dbgShowHq = false };
if (!isNil "CQ_dbgMapHooked") exitWith {};
CQ_dbgMapHooked = true;

[] spawn {
    disableSerialization;
    waitUntil { sleep 0.5; !isNull ((findDisplay 12) displayCtrl 51) };
    ((findDisplay 12) displayCtrl 51) ctrlAddEventHandler ["Draw", {
        params ["_map"];
        if (!CQ_dbgShowEnemy && { !CQ_dbgShowFriend } && { !CQ_dbgShowHq }) exitWith {};
        private _col = {
            switch (_this) do {
                case east: { [0.9, 0.15, 0.15, 1] };
                case west: { [0.2, 0.45, 1, 1] };
                case independent: { [0.1, 0.7, 0.2, 1] };
                default { [0.7, 0.3, 0.9, 1] };
            }
        };
        private _want = { private _s = _this; [CQ_dbgShowFriend, CQ_dbgShowEnemy] select (_s in [east, independent]) };
        private _icon = {
            private _i = getText (configOf _this >> "icon");
            private _p = getText (configFile >> "CfgVehicleIcons" >> _i);
            [_p, _i] select (_p == "")
        };
        if (CQ_dbgShowEnemy || CQ_dbgShowFriend) then {
            // crewed vehicles (one icon for the vehicle and everyone inside)
            {
                if (alive _x && { (crew _x) isNotEqualTo [] }) then {
                    private _g = group effectiveCommander _x;
                    if ((side _g) call _want) then {
                        private _bt = _x getVariable ["CQ_btHq", -1];     // the HQ build truck: black
                        _map drawIcon [_x call _icon, [(side _g) call _col, [0, 0, 0, 1]] select (_bt > -1), getPosASLVisual _x, [24, 30] select (_bt > -1), [24, 30] select (_bt > -1), getDirVisual _x,
                            [format ["%1 %2", groupId _g, _x getVariable ["CQ_dbg", ""]], format ["BUILD TRUCK HQ #%1", _bt]] select (_bt > -1), 1, 0.035, "PuristaMedium", "right"];
                    };
                };
            } forEach vehicles;
            // soldiers on foot
            {
                if (vehicle _x == _x && { alive _x }) then {
                    private _g = group _x;
                    if ((side _g) call _want) then {
                        private _txt = ["", format ["%1 %2", groupId _g, _g getVariable ["CQ_dbg", ""]]] select (leader _g == _x);
                        _map drawIcon [_x call _icon, (side _g) call _col, getPosASLVisual _x, 16, 16, getDirVisual _x, _txt, 1, 0.03, "PuristaMedium", "right"];
                    };
                };
            } forEach allUnits;
        };
        if (CQ_dbgShowHq) then {
            {
                _x params ["_id", "_txt", "_pos"];
                if (_pos isEqualTo []) then { continue };
                _map drawIcon ["\A3\ui_f\data\map\markers\military\objective_CA.paa", [0.95, 0.2, 0.2, 1], _pos, 30, 30, 0,
                    format ["HQ #%1", _id], 2, 0.045, "PuristaBold", "right"];
                _map drawEllipse [_pos, 300, 300, 0, [0.95, 0.2, 0.2, 0.6], ""];
            } forEach (missionNamespace getVariable ["CQ_dbgHqList", []]);
        };
    }];
};
