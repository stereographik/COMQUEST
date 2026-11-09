/*
    CQ_fnc_squadUi  (client)   U key, or the scroll menu
    [_view] spawn CQ_fnc_squadUi;      _view: "squads" (default) or "board"
    One window, two views (tabs at the top):
      SQUADS       three columns: friendly squads | members of the selected squad | unassigned
                   players (always shown). Join / Create / Leave / Disband / Invite (the
                   squad leader invites the selected unassigned player, who gets an
                   accept / decline window, CQ_fnc_squadInvite)
      CLASS        every lobby slot is a Rifleman: take your class here (at the base)
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
private _tabC = ["RscButton", 7093, [_X + 0.02 + _W * 0.18, _Y + 0.004, _W * 0.16, _L], "CLASS"] call _mk;
private _tabB = ["RscButton", 7091, [_X + 0.03 + _W * 0.34, _Y + 0.004, _W * 0.22, _L], "LEADERBOARD"] call _mk;
_tabC ctrlAddEventHandler ["ButtonClick", { uiNamespace setVariable ["CQ_sqView", "class"] }];
private _close = ["RscButton", 7092, [_X + _W - 0.05, _Y + 0.004, 0.04, _L], "X"] call _mk;
_tabS ctrlAddEventHandler ["ButtonClick", { uiNamespace setVariable ["CQ_sqView", "squads"] }];
_tabB ctrlAddEventHandler ["ButtonClick", { uiNamespace setVariable ["CQ_sqView", "board"] }];
_close ctrlAddEventHandler ["ButtonClick", { (uiNamespace getVariable ["CQ_sqDisplay", displayNull]) closeDisplay 1 }];

// --- squads view: three columns  SQUADS | MEMBERS | UNASSIGNED PLAYERS (always visible)
private _top = _Y + _L * 1.5;
private _info = ["RscStructuredText", 7003, [_X + 0.01, _top, _W - 0.02, _L]] call _mk;
private _cw = (_W - 0.04) / 3;
private _hy = _top + _L * 1.05;
private _ly = _hy + _L * 0.8;
private _lh = _H - (_ly - _Y) - _L * 1.8;
private _hdr = {
    params ["_x0", "_txt"];
    private _c = ["RscText", -1, [_x0, _hy, _cw, _L * 0.75], _txt] call _mk;
    _c ctrlSetFont "PuristaMedium";
    _c ctrlSetTextColor [0.65, 0.65, 0.65, 1];
    _c
};
private _h1 = [_X + 0.01, "SQUADS"] call _hdr;
private _h2 = [_X + 0.02 + _cw, "MEMBERS"] call _hdr;
private _h3 = [_X + 0.03 + 2 * _cw, "UNASSIGNED PLAYERS"] call _hdr;
private _grpList = ["RscListBox", 7001, [_X + 0.01, _ly, _cw, _lh]] call _mk;
private _memList = ["RscListBox", 7002, [_X + 0.02 + _cw, _ly, _cw, _lh]] call _mk;
private _solList = ["RscListBox", 7004, [_X + 0.03 + 2 * _cw, _ly, _cw, _lh]] call _mk;
private _bw = (_W - 0.06) / 5;
private _by = _Y + _H - _L * 1.5;
private _bJoin = ["RscButton", 7010, [_X + 0.01, _by, _bw, _L * 1.1], "JOIN SQUAD"] call _mk;
private _bNew = ["RscButton", 7013, [_X + 0.02 + _bw, _by, _bw, _L * 1.1], "CREATE SQUAD"] call _mk;
private _bUng = ["RscButton", 7011, [_X + 0.03 + 2 * _bw, _by, _bw, _L * 1.1], "LEAVE SQUAD"] call _mk;
private _bDis = ["RscButton", 7012, [_X + 0.04 + 3 * _bw, _by, _bw, _L * 1.1], "DISBAND SQUAD"] call _mk;
private _bInv = ["RscButton", 7014, [_X + 0.05 + 4 * _bw, _by, _bw, _L * 1.1], "INVITE PLAYER"] call _mk;
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
    if ((group player) getVariable ["CQ_solo", false]) exitWith { hint "You are not in a squad" };
    if (leader group player != player) exitWith { hint "Only the squad leader can disband the squad" };
    ["disband", player] remoteExec ["CQ_fnc_squadCmd", 2];
}];
_bInv ctrlAddEventHandler ["ButtonClick", {
    if ((group player) getVariable ["CQ_solo", false]) exitWith { hint "Create or join a squad first" };
    if (leader group player != player) exitWith { hint "Only the squad leader can invite" };
    private _lb = (uiNamespace getVariable ["CQ_sqDisplay", displayNull]) displayCtrl 7004;
    private _i = lbCurSel _lb;
    if (_i < 0) exitWith { hint "Select an unassigned player first" };
    private _t = (uiNamespace getVariable ["CQ_sqSolos", []]) param [_lb lbValue _i, objNull];
    if (isNull _t) exitWith { hint "Select an unassigned player first" };
    if (_t == player) exitWith { hint "You can't invite yourself" };
    ["invite", player, _t] remoteExec ["CQ_fnc_squadCmd", 2];
}];
_grpList ctrlAddEventHandler ["LBSelChanged", { uiNamespace setVariable ["CQ_sqRefreshMembers", true] }];
private _sqCtrls = [_info, _h1, _h2, _h3, _grpList, _memList, _solList, _bJoin, _bNew, _bUng, _bDis, _bInv];

// --- leaderboard view
private _clsList = ["RscListBox", 7102, [_X + 0.01, _top, _W * 0.22, _H - _L * 2]] call _mk;
private _board = ["RscListNBox", 7103, [_X + 0.02 + _W * 0.22, _top, _W * 0.78 - 0.03, _H - _L * 2]] call _mk;
_board lnbSetColumnsPos [0, 0.06, 0.38, 0.55, 0.66, 0.77, 0.86, 0.93];
_clsList ctrlAddEventHandler ["LBSelChanged", { uiNamespace setVariable ["CQ_sqBoardDirty", true] }];
private _bdCtrls = [_clsList, _board];

// --- class view
private _classList = ["RscListBox", 7201, [_X + 0.01, _top, _W * 0.35, _H - _L * 3.2]] call _mk;
private _classInfo = ["RscStructuredText", 7203, [_X + 0.02 + _W * 0.35, _top, _W * 0.65 - 0.03, _H - _L * 3.2]] call _mk;
private _bTake = ["RscButton", 7202, [_X + 0.01, _Y + _H - _L * 1.5, _W * 0.35, _L * 1.1], "TAKE THIS CLASS"] call _mk;
{ _classList lbAdd (_x select 0) } forEach CQ_classes;
_bTake ctrlAddEventHandler ["ButtonClick", {
    private _lb = (uiNamespace getVariable ["CQ_sqDisplay", displayNull]) displayCtrl 7201;
    private _i = lbCurSel _lb;
    if (_i < 0) exitWith { hint "Select a class first" };
    [_lb lbText _i] call CQ_fnc_setClass;
}];
private _clCtrls = [_classList, _classInfo, _bTake];

private _role = {
    params ["_u"];
    private _r = roleDescription _u;
    private _c = _u getVariable ["CQ_class", ""];
    if (_c != "") exitWith { _c };
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
        { _x ctrlShow (_view == "class") } forEach _clCtrls;
        _tabC ctrlSetBackgroundColor ([[0.2, 0.2, 0.2, 0.8], [0.35, 0.5, 0.25, 1]] select (_view == "class"));
        _tabS ctrlSetBackgroundColor ([[0.2, 0.2, 0.2, 0.8], [0.35, 0.5, 0.25, 1]] select (_view == "squads"));
        _tabB ctrlSetBackgroundColor ([[0.2, 0.2, 0.2, 0.8], [0.35, 0.5, 0.25, 1]] select (_view == "board"));
        _lastView = _view;
    };
    private _players = allPlayers select { side group _x == west };

    if (_view == "class") then {
        private _i = lbCurSel _classList;
        private _mine = player getVariable ["CQ_class", "Rifleman"];
        private _cls = if (_i >= 0) then { (CQ_classes select _i) select 1 } else { "" };
        private _near = player distance2D CQ_basePos <= CQ_classChangeRange;
        _classInfo ctrlSetStructuredText parseText format [
            "<t size='0.9' color='#c8e07a'>Your class: %1</t><br/><t size='0.7' color='#9a9a9a'>Right column: players in that class / limit</t><br/><br/><t size='0.8' color='#d0d0c0'>%2</t><br/><br/><t size='0.75' color='#9a9a9a'>%3</t>",
            _mine,
            if (_cls == "") then { "Pick a class on the left." } else {
                private _w = getArray (configFile >> "CfgVehicles" >> _cls >> "weapons") select { !(_x in ["Throw", "Put"]) };
                format ["%1<br/>Weapons: %2", getText (configFile >> "CfgVehicles" >> _cls >> "displayName"), (_w apply { getText (configFile >> "CfgWeapons" >> _x >> "displayName") }) joinString ", "]
            },
            ["You must be at the base to change class.", "Your loadout and traits change at once; the arsenal can customise it after."] select _near];
        // slots per class: used / limit
        {
            _x params ["_lbl", "", "", ["_max", 99]];
            private _used = { (_x getVariable ["CQ_class", "Rifleman"]) == _lbl } count _players;
            private _free = (_max - _used) max 0;
            _classList lbSetTextRight [_forEachIndex, format ["%1 / %2", _used, _max]];
            private _col = switch (true) do {
                case (_lbl == _mine): { [0.78, 0.88, 0.48, 1] };
                case (_free == 0):    { [0.6, 0.35, 0.35, 1] };
                default               { [1, 1, 1, 1] };
            };
            _classList lbSetColor [_forEachIndex, _col];
            _classList lbSetColorRight [_forEachIndex, _col];
        } forEach CQ_classes;
        _bTake ctrlEnable _near;
    };
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
        if (isNull _selG || { _selG getVariable ["CQ_solo", false] && { !(_selG isEqualTo group player) } }) then { _selG = group player };
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
        if (_squads isEqualTo []) then { _grpList lbSetValue [_grpList lbAdd "(no squad yet)", -1]; _grpList lbSetColor [0, [0.5, 0.5, 0.5, 1]] };

        // unassigned players, always listed
        private _solP = (_solos apply { leader _x }) select { isPlayer _x };
        private _solSel = lbCurSel _solList;
        private _solOld = uiNamespace getVariable ["CQ_sqSolos", []];
        private _solPick = if (_solSel >= 0) then { _solOld param [_solList lbValue _solSel, objNull] } else { objNull };
        uiNamespace setVariable ["CQ_sqSolos", _solP];
        lbClear _solList;
        {
            private _i = _solList lbAdd format ["%1  -  %2", name _x, [_x] call _role];
            _solList lbSetValue [_i, _forEachIndex];
            if (_x == player) then { _solList lbSetColor [_i, [0.55, 0.9, 0.45, 1]] };
            if (_x isEqualTo _solPick) then { _solList lbSetCurSel _i };
        } forEach _solP;
        if (_solP isEqualTo []) then { _solList lbSetValue [_solList lbAdd "(nobody)", -1]; _solList lbSetColor [0, [0.5, 0.5, 0.5, 1]] };
        _bInv ctrlEnable (!((group player) getVariable ["CQ_solo", false]) && { leader group player == player });
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
