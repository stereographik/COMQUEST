/*
    CQ_fnc_squadUi  (client)   U key, or the scroll menu
    [_view] spawn CQ_fnc_squadUi;      _view: "squads" (default) or "board"
    One window, two views (tabs at the top):
      SQUADS       all friendly squads + the unassigned players (everyone starts unassigned),
                   free slots; members of the selected squad; Join / Create / Leave / Disband
      LEADERBOARD  per class (Squad Leader, Medic, Autorifleman...) or All = MVP ranking:
                   kills, vehicles, objectives, deaths, score. Nothing is stored: a server
                   restart wipes it.
    Refreshes every second while open. U or Esc closes it.
*/
params [["_view", "squads"]];
if (!hasInterface) exitWith {};
disableSerialization;
private _open = uiNamespace getVariable ["CQ_sqDisplay", displayNull];
if (!isNull _open) exitWith { uiNamespace setVariable ["CQ_sqView", _view] };

private _d = (findDisplay 46) createDisplay "RscDisplayEmpty";
uiNamespace setVariable ["CQ_sqDisplay", _d];
uiNamespace setVariable ["CQ_sqView", _view];
_d displayAddEventHandler ["KeyDown", { params ["_d", "_k"]; if (_k == 22) then { _d closeDisplay 1; true } else { false } }];

private _W = safeZoneW * 0.56;
private _H = safeZoneH * 0.66;
private _X = safeZoneX + (safeZoneW - _W) / 2;
private _Y = safeZoneY + (safeZoneH - _H) / 2;
private _L = 0.042;
private _mk = {
    params ["_cls", "_idc", "_pos", ["_txt", ""]];
    private _c = _d ctrlCreate [_cls, _idc];
    _c ctrlSetPosition _pos;
    if (_txt != "") then { _c ctrlSetText _txt };
    _c ctrlCommit 0;
    _c
};
(["RscText", -1, [_X, _Y, _W, _H]] call _mk) ctrlSetBackgroundColor [0.03, 0.04, 0.03, 0.88];
(["RscText", -1, [_X, _Y, _W, _L * 1.1]] call _mk) ctrlSetBackgroundColor [0.12, 0.16, 0.1, 0.95];
private _tabS = ["RscButton", 7090, [_X + 0.01, _Y + 0.004, _W * 0.18, _L], "SQUADS"] call _mk;
private _tabB = ["RscButton", 7091, [_X + 0.02 + _W * 0.18, _Y + 0.004, _W * 0.22, _L], "LEADERBOARD"] call _mk;
private _close = ["RscButton", 7092, [_X + _W - 0.05, _Y + 0.004, 0.04, _L], "X"] call _mk;
_tabS ctrlAddEventHandler ["ButtonClick", { uiNamespace setVariable ["CQ_sqView", "squads"] }];
_tabB ctrlAddEventHandler ["ButtonClick", { uiNamespace setVariable ["CQ_sqView", "board"] }];
_close ctrlAddEventHandler ["ButtonClick", { (uiNamespace getVariable ["CQ_sqDisplay", displayNull]) closeDisplay 1 }];

// --- squads view
private _top = _Y + _L * 1.5;
private _info = ["RscStructuredText", 7003, [_X + 0.01, _top, _W - 0.02, _L]] call _mk;
private _grpList = ["RscListBox", 7001, [_X + 0.01, _top + _L * 1.1, _W * 0.48, _H - _L * 4.4]] call _mk;
private _memList = ["RscListBox", 7002, [_X + 0.02 + _W * 0.48, _top + _L * 1.1, _W * 0.5 - 0.03, _H - _L * 4.4]] call _mk;
private _bw = (_W - 0.05) / 4;
private _by = _Y + _H - _L * 1.5;
private _bJoin = ["RscButton", 7010, [_X + 0.01, _by, _bw, _L * 1.1], "JOIN SQUAD"] call _mk;
private _bNew = ["RscButton", 7013, [_X + 0.02 + _bw, _by, _bw, _L * 1.1], "CREATE SQUAD"] call _mk;
private _bUng = ["RscButton", 7011, [_X + 0.03 + 2 * _bw, _by, _bw, _L * 1.1], "LEAVE SQUAD"] call _mk;
private _bDis = ["RscButton", 7012, [_X + 0.04 + 3 * _bw, _by, _bw, _L * 1.1], "DISBAND SQUAD"] call _mk;
_bNew ctrlAddEventHandler ["ButtonClick", {
    if !((group player) getVariable ["CQ_solo", false]) exitWith { hint "Leave your squad first to create a new one" };
    ["create", player] remoteExec ["CQ_fnc_squadCmd", 2];
}];
_bJoin ctrlAddEventHandler ["ButtonClick", {
    private _lb = (uiNamespace getVariable ["CQ_sqDisplay", displayNull]) displayCtrl 7001;
    private _i = lbCurSel _lb;
    if (_i < 0) exitWith { hint "Select a squad first" };
    private _g = (uiNamespace getVariable ["CQ_sqGroups", []]) param [_lb lbValue _i, grpNull];
    if (isNull _g) exitWith { hint "Select a squad first" };
    if (_g isEqualTo group player) exitWith { hint "You are already in this squad" };
    ["join", player, _g] remoteExec ["CQ_fnc_squadCmd", 2];
}];
_bUng ctrlAddEventHandler ["ButtonClick", {
    if ((group player) getVariable ["CQ_solo", false]) exitWith { hint "You are not in a squad" };
    ["ungroup", player] remoteExec ["CQ_fnc_squadCmd", 2];
}];
_bDis ctrlAddEventHandler ["ButtonClick", {
    if (leader group player != player) exitWith { hint "Only the squad leader can disband the squad" };
    ["disband", player] remoteExec ["CQ_fnc_squadCmd", 2];
}];
_grpList ctrlAddEventHandler ["LBSelChanged", { uiNamespace setVariable ["CQ_sqRefreshMembers", true] }];
private _sqCtrls = [_info, _grpList, _memList, _bJoin, _bNew, _bUng, _bDis];

// --- leaderboard view
private _clsList = ["RscListBox", 7102, [_X + 0.01, _top, _W * 0.22, _H - _L * 2]] call _mk;
private _board = ["RscListNBox", 7103, [_X + 0.02 + _W * 0.22, _top, _W * 0.78 - 0.03, _H - _L * 2]] call _mk;
_board lnbSetColumnsPos [0, 0.06, 0.38, 0.55, 0.66, 0.77, 0.86, 0.93];
_clsList ctrlAddEventHandler ["LBSelChanged", { uiNamespace setVariable ["CQ_sqBoardDirty", true] }];
private _bdCtrls = [_clsList, _board];

private _role = {
    params ["_u"];
    private _r = roleDescription _u;
    if (_r find "@" > -1) then { _r = (_r splitString "@") select 0 };
    if (_r find " - " > -1) then { _r = (_r splitString "-") select (count (_r splitString "-") - 1); _r = _r trim [" ", 0] };
    if (_r == "") then { _r = getText (configOf _u >> "displayName") };
    _r
};

private _lastView = "";
private _clsSel = "All (MVP)";
while { !isNull _d } do {
    private _view = uiNamespace getVariable ["CQ_sqView", "squads"];
    if (_view != _lastView) then {
        { _x ctrlShow (_view == "squads") } forEach _sqCtrls;
        { _x ctrlShow (_view == "board") } forEach _bdCtrls;
        _tabS ctrlSetBackgroundColor ([[0.2, 0.2, 0.2, 0.8], [0.35, 0.5, 0.25, 1]] select (_view == "squads"));
        _tabB ctrlSetBackgroundColor ([[0.2, 0.2, 0.2, 0.8], [0.35, 0.5, 0.25, 1]] select (_view == "board"));
        _lastView = _view;
    };
    private _players = allPlayers select { side group _x == west };

    if (_view == "squads") then {
        private _groups = allGroups select { side _x == west && { (units _x) findIf { isPlayer _x } > -1 } };
        private _squads = _groups select { !(_x getVariable ["CQ_solo", false]) };
        private _solos = _groups - _squads;
        private _slots = playableSlotsNumber west;
        _info ctrlSetStructuredText parseText format [
            "<t size='0.85' color='#c8e07a'>%1 players</t><t size='0.85' color='#d0d0c0'>   |   %2 squads   |   %3 unassigned   |   %4 free slots   |   you: %5</t>",
            count _players, count _squads, count _solos, (_slots - count _players) max 0, ["in " + groupId group player, "unassigned"] select ((group player) getVariable ["CQ_solo", false])];
        private _sel = lbCurSel _grpList;
        private _old = uiNamespace getVariable ["CQ_sqGroups", []];
        private _selG = if (_sel >= 0) then { _old param [_grpList lbValue _sel, grpNull] } else { group player };
        if (isNull _selG) then { _selG = group player };
        private _all = _squads + _solos;
        uiNamespace setVariable ["CQ_sqGroups", _all];
        lbClear _grpList;
        {
            private _g = _x;
            private _np = { isPlayer _x } count units _g;
            private _i = _grpList lbAdd format ["%1   (%2/%3)", groupId _g, _np, count units _g];
            _grpList lbSetValue [_i, _all find _g];
            if (_g isEqualTo group player) then { _grpList lbSetColor [_i, [0.55, 0.9, 0.45, 1]] };
        } forEach _squads;
        if (_solos isNotEqualTo []) then {
            private _h = _grpList lbAdd "--- UNASSIGNED ---";
            _grpList lbSetColor [_h, [0.7, 0.7, 0.6, 1]];
            _grpList lbSetValue [_h, -1];
            { private _i = _grpList lbAdd format ["   %1", name leader _x]; _grpList lbSetValue [_i, _all find _x] } forEach _solos;
        };
        private _want = _all find _selG;
        for "_i" from 0 to (lbSize _grpList) - 1 do { if ((_grpList lbValue _i) == _want && { _want > -1 }) exitWith { _grpList lbSetCurSel _i } };
        private _sg = _selG;
        lbClear _memList;
        if (!isNull _sg) then {
            {
                private _i = _memList lbAdd format ["%1%2  -  %3%4", ["", "* "] select (leader _sg == _x), name _x, [_x] call _role, ["  (AI)", ""] select (isPlayer _x)];
                if (_x == player) then { _memList lbSetColor [_i, [0.55, 0.9, 0.45, 1]] };
                if (!alive _x) then { _memList lbSetColor [_i, [0.6, 0.3, 0.3, 1]] };
            } forEach units _sg;
        };
    } else {
        // classes present
        private _classes = ["All (MVP)"];
        { _classes pushBackUnique ([_x] call _role) } forEach _players;
        if ((lbSize _clsList) != count _classes) then {
            lbClear _clsList;
            { _clsList lbAdd _x } forEach _classes;
            _clsList lbSetCurSel ((_classes find _clsSel) max 0);
        };
        private _ci = lbCurSel _clsList;
        if (_ci >= 0) then { _clsSel = _clsList lbText _ci };
        private _rows = [];
        {
            private _s = getPlayerScores _x;
            if (count _s < 6) then { _s = [0, 0, 0, 0, 0, 0] };
            private _uid = getPlayerUID _x;
            private _e = (missionNamespace getVariable ["CQ_scoreTable", []]) select { (_x select 0) == _uid };
            private _obj = if (_e isEqualTo []) then { 0 } else { (_e select 0) select 2 };
            private _pts = if (_e isEqualTo []) then { 0 } else { (_e select 0) select 3 };
            private _r = [_x] call _role;
            if (_clsSel == "All (MVP)" || { _r == _clsSel }) then {
                _rows pushBack [(_s select 5) + _pts, name _x, _r, _s select 0, (_s select 1) + (_s select 2) + (_s select 3), _obj, _s select 4, _x == player];
            };
        } forEach _players;
        _rows = [_rows, [], { _x select 0 }, "DESCEND"] call BIS_fnc_sortBy;
        lnbClear _board;
        _board lnbAddRow ["#", "NAME", "CLASS", "KILLS", "VEHICLES", "OBJ.", "DEATHS", "SCORE"];
        _board lnbSetColor [[0, 0], [0.78, 0.88, 0.48, 1]];
        {
            _x params ["_sc", "_n", "_r", "_k", "_v", "_o", "_de", "_me"];
            private _row = _board lnbAddRow [str (_forEachIndex + 1), _n, _r, str _k, str _v, str _o, str _de, str _sc];
            if (_me) then { for "_c" from 0 to 7 do { _board lnbSetColor [[_row, _c], [0.55, 0.9, 0.45, 1]] } };
            if (_forEachIndex == 0 && { _clsSel == "All (MVP)" }) then { _board lnbSetText [[_row, 1], format ["%1  (MVP)", _n]] };
        } forEach _rows;
    };
    sleep 1;
};
uiNamespace setVariable ["CQ_sqDisplay", displayNull];
