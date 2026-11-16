/*
    CQ_fnc_debugMap  (client, debug panel users: debug mission, host or logged-in admin)
    Map overlay, switched from the debug panel (all off by default outside CQ_debug):
      CQ_dbgShowEnemy   every enemy unit and crewed vehicle (CSAT red, guerillas green)
      CQ_dbgShowFriend  every friendly unit and crewed vehicle (blue), civilians purple
      CQ_dbgShowTnt     the woken Darters' tentacle: chain, ring slots, zone perimeter (purple)
      CQ_dbgShowEmp     the EMP event (CQ_empDbg from CQ_fnc_empTick, orange): the real device spot
                        and its 5 km blast radius, the search circle, guards left, timer; then the
                        Stomper, its spawn site, a line to its current goal, the target and its
                        400 m strike radius
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
        // the woken Darters' tentacle (CQ_fnc_magDormant): chain from its root, ring slots, zone perimeter
        if (missionNamespace getVariable ["CQ_dbgShowTnt", false]) then {
            (missionNamespace getVariable ["CQ_tntPub", []]) params [["_ch", []], ["_rg", []], ["_pe", []]];
            if (_pe isNotEqualTo []) then { _map drawEllipse [_pe select 0, _pe select 1, _pe select 1, 0, [0.7, 0.3, 1, 0.9], ""] };
            for "_i" from 1 to (count _ch - 1) do { _map drawLine [_ch select (_i - 1), _ch select _i, [0.7, 0.3, 1, 1]] };
            { _map drawIcon ["\A3\ui_f\data\map\markers\military\dot_CA.paa", [0.7, 0.3, 1, 1], _x, 14, 14, 0, [" C" + str _forEachIndex, " ROOT"] select (_forEachIndex == 0), 1, 0.03, "PuristaMedium", "right"] } forEach _ch;
            { _map drawIcon ["\A3\ui_f\data\map\markers\military\circle_CA.paa", [0.7, 0.3, 1, 1], _x, 14, 14, 0, " R" + str (_forEachIndex + 1), 1, 0.03, "PuristaMedium", "right"] } forEach _rg;
        };
        // the EMP event (CQ_fnc_empTick publishes CQ_empDbg every 2 s while it runs)
        if (missionNamespace getVariable ["CQ_dbgShowEmp", false]) then {
            (missionNamespace getVariable ["CQ_empDbg", []]) params [["_ph", ""], ["_dp", []], ["_fd", false], ["_lt", 0], ["_sc", []], ["_up", []], ["_gl", []], ["_tg", []], ["_ld", false], ["_sp", []], ["_gd", 0], ["_nu", 0]];
            if (_ph != "") then {
                private _o = [1, 0.55, 0.1, 1];
                if (_ph == "armed") then {
                    _map drawEllipse [_dp, CQ_empBlastR, CQ_empBlastR, 0, [1, 0.55, 0.1, 0.35], ""];
                    if (_sc isNotEqualTo [] && { !_fd }) then { _map drawEllipse [_sc, CQ_empSearchR, CQ_empSearchR, 0, _o, ""] };
                };
                if (_dp isNotEqualTo [] && { !_ld }) then {
                    _map drawIcon ["\A3\ui_f\data\map\markers\military\destroy_CA.paa", _o, _dp, 22, 22, 0,
                        format [" EMP %1 | %2 | found %3 | guards %4", toUpper _ph, if (_ph == "armed") then { format ["%1:%2", floor ((_lt max 0) / 60), floor ((_lt max 0) mod 60)] } else { "" }, _fd, _gd], 1, 0.035, "PuristaMedium", "right"];
                };
                if (_sp isNotEqualTo []) then { _map drawIcon ["\A3\ui_f\data\map\markers\military\start_CA.paa", _o, _sp, 18, 18, 0, " Stomper spawn", 1, 0.03, "PuristaMedium", "right"] };
                if (_up isNotEqualTo []) then {
                    _map drawIcon ["\A3\ui_f\data\map\markers\nato\b_uav.paa", _o, _up, 24, 24, 0, format [" STOMPER %1 | nudges %2", ["to the device", "loaded"] select _ld, _nu], 1, 0.035, "PuristaMedium", "right"];
                    if (_gl isNotEqualTo []) then { _map drawLine [_up, _gl, _o] };
                };
                if (_tg isNotEqualTo []) then {
                    _map drawEllipse [_tg, CQ_empHitR, CQ_empHitR, 0, _o, ""];
                    _map drawIcon ["\A3\ui_f\data\map\markers\military\objective_CA.paa", _o, _tg, 22, 22, 0, " EMP TARGET", 1, 0.035, "PuristaMedium", "right"];
                };
            };
        };
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
        private _teamCol = { [[0.55, 0.66, 0.82, 1], [1, 1, 1, 1]] select (_this == "medic") };
        private _icon = {
            private _i = getText (configOf _this >> "icon");
            private _p = getText (configFile >> "CfgVehicleIcons" >> _i);
            [_p, _i] select (_p == "")
        };
        private _st = missionNamespace getVariable ["CQ_dbgShowStates", false];   // enemy vehicles: their state instead of role/ammo
        if (CQ_dbgShowEnemy || CQ_dbgShowFriend) then {
            // crewed vehicles (one icon for the vehicle and everyone inside)
            {
                if (alive _x && { (crew _x) isNotEqualTo [] }) then {
                    private _g = group effectiveCommander _x;
                    if ((side _g) call _want) then {
                        private _bt = _x getVariable ["CQ_btHq", -1];     // the HQ build truck and its Kajman: black
                        if (_bt < 0) then { _bt = _x getVariable ["CQ_btKaj", -1] };
                        private _tm = _x getVariable ["CQ_team", ""];     // support teams: medic white, engineer grey-blue
                        if (_tm != "") then {
                            _map drawIcon [_x call _icon, _tm call _teamCol, getPosASLVisual _x, 30 * CQ_mapIconScale, 30 * CQ_mapIconScale, getDirVisual _x, format [" %1 TEAM", toUpper _tm], 1, 0.035, "PuristaMedium", "right"];
                        } else {
                        _map drawIcon [_x call _icon, [(side _g) call _col, [0, 0, 0, 1]] select (_bt > -1), getPosASLVisual _x, ([24, 30] select (_bt > -1)) * CQ_mapIconScale, ([24, 30] select (_bt > -1)) * CQ_mapIconScale, getDirVisual _x,
                            " " + ([format ["%1 %2", groupId _g, [_x getVariable ["CQ_dbg", ""], _x getVariable ["CQ_dbgSt", ""]] select _st], format [["BUILD TRUCK HQ #%1", "BUILD TRUCK KAJMAN HQ #%1"] select ((_x getVariable ["CQ_btKaj", -1]) > -1), _bt]] select (_bt > -1))
                                + (["", format [": %1", _x getVariable ["CQ_dbgSt", ""]]] select (_st && { _bt > -1 })), 1, 0.035, "PuristaMedium", "right"];
                        };
                    };
                };
            } forEach vehicles;
            // soldiers on foot
            {
                if (vehicle _x == _x && { alive _x }) then {
                    private _g = group _x;
                    if ((side _g) call _want) then {
                        private _tm = _g getVariable ["CQ_team", ""];
                        private _txt = ["", [format ["%1 %2", groupId _g, _g getVariable ["CQ_dbg", ""]], format ["%1 TEAM", toUpper _tm]] select (_tm != "")] select (leader _g == _x);
                        _map drawIcon [_x call _icon, [(side _g) call _col, _tm call _teamCol] select (_tm != ""), getPosASLVisual _x, 16 * CQ_mapIconScale, 16 * CQ_mapIconScale, getDirVisual _x, " " + _txt, 1, 0.03, "PuristaMedium", "right"];
                    };
                };
            } forEach allUnits;
        };
        if (CQ_dbgShowHq) then {
            {
                _x params ["_id", "_txt", "_pos"];
                if (_pos isEqualTo []) then { continue };
                _map drawIcon ["\A3\ui_f\data\map\markers\military\objective_CA.paa", [0.95, 0.2, 0.2, 1], _pos, 30 * CQ_mapIconScale, 30 * CQ_mapIconScale, 0,
                    format [" HQ #%1", _id], 2, 0.045, "PuristaBold", "right"];
                _map drawEllipse [_pos, 300, 300, 0, [0.95, 0.2, 0.2, 0.6], ""];
            } forEach (missionNamespace getVariable ["CQ_dbgHqList", []]);
        };
    }];
};
