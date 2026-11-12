/*
    CQ_fnc_squadUi  (client)   U key, or the scroll menu
    [_view] spawn CQ_fnc_squadUi;      _view: "squads" (default) or "board"
    One window, two views (tabs at the top):
      SQUADS       three columns: friendly squads | members of the selected squad | unassigned
                   players (always shown). Join / Create / Leave / Disband / Invite (the
                   squad leader invites the selected unassigned player, who gets an
                   accept / decline window, CQ_fnc_squadInvite)
      CLASS        every lobby slot is a Rifleman: take your class here (at the base)
      STATS        class filter | ranking sortable by score, kills, vehicles, objectives,
                   heals, longest kill, K/D, deaths, shots, distance, time | details of the
                   selected player. Data: CQ_statsPub (CQ_fnc_statsTick). Nothing is stored:
                   a server restart wipes it.
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

// the field tablet picture (media\comtablet_ca.paa, 1024 x 512 texture of a 1024 x 640 crop, background
// cut out), centred on screen and kept fully inside it; the window fills its green screen
// (CQ_sqScreen = [x0, y0, x1, y1] as fractions of the picture)
private _ph = safeZoneH * CQ_sqSize;
private _pw = (_ph / pixelH) * 1.6 * pixelW;                    // 1024 x 640 picture ratio, square pixels
if (_pw > safeZoneW) then { _ph = _ph * safeZoneW / _pw; _pw = safeZoneW };
private _picX = safeZoneX + (safeZoneW - _pw) / 2;
private _picY = safeZoneY + (safeZoneH - _ph) / 2;
CQ_sqScreen params ["_fx0", "_fy0", "_fx1", "_fy1"];
private _X = _picX + _pw * _fx0 + 0.004;
private _Y = _picY + _ph * _fy0 + 0.004;
private _W = _pw * (_fx1 - _fx0) - 0.008;
private _H = _ph * (_fy1 - _fy0) - 0.008;
private _L = (0.042 * _H / (safeZoneH * 0.66)) max 0.03;   // row height, scaled to the screen
private _mk = {
    params ["_cls", "_idc", "_pos", ["_txt", ""]];
    private _c = _d ctrlCreate [[_cls, "CQ_Button"] select (_cls == "RscButton"), _idc];
    [_c, _cls] call CQ_fnc_uiStyle;
    _c ctrlSetPosition _pos;
    if (_txt != "") then { _c ctrlSetText _txt };
    _c ctrlCommit 0;
    _c
};
private _pic = ["RscPicture", -1, [_picX, _picY, _pw, _ph]] call _mk;
_pic ctrlSetText (getMissionPath "media\comtablet_ca.paa");
["Squad window: tablet picture %1 (file found: %2), pos %3", [ctrlText _pic, fileExists (getMissionPath "media\comtablet_ca.paa"), ctrlPosition _pic]] call CQ_fnc_log;
// dark tint over the green screen: the screen glow shows through, text stays readable
(["RscText", -1, [_X, _Y, _W, _H]] call _mk) ctrlSetBackgroundColor [0, 0.04, 0, CQ_sqTint];
(["RscText", -1, [_X, _Y, _W, _L * 1.1]] call _mk) ctrlSetBackgroundColor (CQ_ui get "header");
private _tabS = ["RscButton", 7090, [_X + 0.01, _Y + 0.004, _W * 0.18, _L], "SQUADS"] call _mk;
private _tabC = ["RscButton", 7093, [_X + 0.02 + _W * 0.18, _Y + 0.004, _W * 0.16, _L], "CLASS"] call _mk;
private _tabB = ["RscButton", 7091, [_X + 0.03 + _W * 0.34, _Y + 0.004, _W * 0.22, _L], "STATS"] call _mk;
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
    _c ctrlSetTextColor (CQ_ui get "muted");
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

// --- stats view: class filter | ranking (sortable) | details of the selected player
private _cfW = _W * 0.17;
private _rkW = _W * 0.47;
private _dtW = _W - _cfW - _rkW - 0.04;
private _hdrB = {
    params ["_x0", "_w", "_txt"];
    private _c = ["RscText", -1, [_x0, _top, _w, _L * 0.75], _txt] call _mk;
    _c ctrlSetFont "PuristaMedium";
    _c ctrlSetTextColor (CQ_ui get "muted");
    _c
};
private _bh1 = [_X + 0.01, _cfW, "CLASS"] call _hdrB;
private _bh2 = [_X + 0.02 + _cfW, _rkW * 0.35, "RANKING  -  sort by"] call _hdrB;
private _bh3 = [_X + 0.03 + _cfW + _rkW, _dtW, "PLAYER DETAILS"] call _hdrB;
private _clsList = ["RscListBox", 7102, [_X + 0.01, _top + _L * 0.85, _cfW, _H - _L * 2.9]] call _mk;
private _sortCb = ["RscCombo", 7104, [_X + 0.02 + _cfW + _rkW * 0.36, _top, _rkW * 0.64, _L * 0.75]] call _mk;
private _board = ["RscListNBox", 7103, [_X + 0.02 + _cfW, _top + _L * 0.85, _rkW, _H - _L * 2.9]] call _mk;
private _detail = ["RscStructuredText", 7105, [_X + 0.03 + _cfW + _rkW, _top + _L * 0.85, _dtW, _H - _L * 2.9]] call _mk;
_detail ctrlSetBackgroundColor (CQ_ui get "inset");
_board lnbSetColumnsPos [0, 0.07, 0.36, 0.6, 0.72, 0.8, 0.88];
// sort options: [label, column title, value code on a stats row]
CQ_sqSorts = [
    ["Score",            "SCORE"],
    ["Kills",            "KILLS"],
    ["Vehicles",         "VEH."],
    ["Objectives",       "OBJ."],
    ["Heals given",      "HEALS"],
    ["Longest kill",     "LONGEST"],
    ["K/D ratio",        "K/D"],
    ["Deaths",           "DEATHS"],
    ["Shots fired",      "SHOTS"],
    ["Distance",         "KM"],
    ["Time played",      "TIME"]
];
{ _sortCb lbAdd (_x select 0) } forEach CQ_sqSorts;
_sortCb lbSetCurSel 0;
_clsList lbAdd "All classes (MVP)";
{ _clsList lbAdd (_x select 0) } forEach CQ_classes;
_clsList lbSetCurSel 0;
_board ctrlAddEventHandler ["LBSelChanged", {
    params ["_c", "_row"];
    private _uid = _c lnbData [_row, 0];
    if (_uid != "") then { uiNamespace setVariable ["CQ_sqStatSel", _uid] };
}];
uiNamespace setVariable ["CQ_sqStatSel", getPlayerUID player];
private _bdCtrls = [_bh1, _bh2, _bh3, _clsList, _sortCb, _board, _detail];

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
        [_tabC, _view == "class"] call CQ_fnc_uiSel;
        [_tabS, _view == "squads"] call CQ_fnc_uiSel;
        [_tabB, _view == "board"] call CQ_fnc_uiSel;
        _lastView = _view;
    };
    private _players = allPlayers select { side group _x == west };

    if (_view == "class") then {
        private _i = lbCurSel _classList;
        private _mine = player getVariable ["CQ_class", "Rifleman"];
        private _cls = if (_i >= 0) then { (CQ_classes select _i) select 1 } else { "" };
        private _near = player inArea [CQ_basePos, (CQ_compoundSize select 0) / 2 + CQ_classChangeRange, (CQ_compoundSize select 1) / 2 + CQ_classChangeRange, CQ_baseDir, true];
        _classInfo ctrlSetStructuredText parseText format [
            "<t size='0.9' color='#918C3B'>Your class: %1</t><br/><t size='0.7' color='#A6A381'>Right column: players in that class / limit</t><br/><br/><t size='0.8' color='#CFCDB3'>%2</t><br/><br/><t size='0.75' color='#A6A381'>%3</t>",
            _mine,
            if (_cls == "") then { "Pick a class on the left." } else {
                private _w = getArray (configFile >> "CfgVehicles" >> _cls >> "weapons") select { !(_x in ["Throw", "Put"]) };
                format ["%1<br/>Weapons: %2", getText (configFile >> "CfgVehicles" >> _cls >> "displayName"), (_w apply { getText (configFile >> "CfgWeapons" >> _x >> "displayName") }) joinString ", "]
            },
            ["You must be inside the HQ compound to change class.", "Your loadout and traits change at once; the arsenal can customise it after."] select _near];
        // slots per class: used / limit
        {
            _x params ["_lbl", "", "", ["_max", 99]];
            private _used = { (_x getVariable ["CQ_class", "Rifleman"]) == _lbl } count _players;
            private _free = (_max - _used) max 0;
            _classList lbSetTextRight [_forEachIndex, format ["%1 / %2", _used, _max]];
            private _col = switch (true) do {
                case (_lbl == _mine): { [0.729, 0.224, 0.173, 1] };
                case (_free == 0):    { [0.54, 0.53, 0.44, 1] };
                default               { (CQ_ui get "text") };
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
            "<t size='0.85' color='#918C3B'>%1 players</t><t size='0.85' color='#CFCDB3'>   |   %2 squads   |   %3 unassigned   |   %4 free slots   |   you: %5</t>",
            count _players, count _squads, count _solos, (_slots - count _players) max 0, [format ["in %1 (%2 squad pts)", groupId group player, (group player) getVariable ["CQ_sqPts", 0]], "unassigned"] select ((group player) getVariable ["CQ_solo", false])];
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
            _grpList lbSetTextRight [_i, format ["%1 pts", _g getVariable ["CQ_sqPts", 0]]];
            _grpList lbSetValue [_i, _all find _g];
            if (_g isEqualTo group player) then { _grpList lbSetColor [_i, [0.729, 0.224, 0.173, 1]] };
        } forEach _squads;
        if (_squads isEqualTo []) then { _grpList lbSetValue [_grpList lbAdd "(no squad yet)", -1]; _grpList lbSetColor [0, (CQ_ui get "dim")] };

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
            if (_x == player) then { _solList lbSetColor [_i, [0.729, 0.224, 0.173, 1]] };
            if (_x isEqualTo _solPick) then { _solList lbSetCurSel _i };
        } forEach _solP;
        if (_solP isEqualTo []) then { _solList lbSetValue [_solList lbAdd "(nobody)", -1]; _solList lbSetColor [0, (CQ_ui get "dim")] };
        _bInv ctrlEnable (!((group player) getVariable ["CQ_solo", false]) && { leader group player == player });
        private _want = _all find _selG;
        for "_i" from 0 to (lbSize _grpList) - 1 do { if ((_grpList lbValue _i) == _want && { _want > -1 }) exitWith { _grpList lbSetCurSel _i } };
        private _sg = _selG;
        lbClear _memList;
        if (!isNull _sg) then {
            {
                private _i = _memList lbAdd format ["%1%2  -  %3%4", ["", "* "] select (leader _sg == _x), name _x, [_x] call _role, ["  (AI)", ""] select (isPlayer _x)];
                if (_x == player) then { _memList lbSetColor [_i, [0.729, 0.224, 0.173, 1]] };
                if (!alive _x) then { _memList lbSetColor [_i, (CQ_ui get "dim")] };
            } forEach units _sg;
        };
    };
    if (_view == "board") then {
        // ---- STATS: one row per player (online, or seen this session)
        private _keys = CQ_statKeys;
        private _rows = createHashMap;    // uid -> [name, class, online, values HashMap]
        {
            _x params ["_uid", "_n", "_c", "_vals"];
            private _m = createHashMap;
            { _m set [_x, _vals param [_forEachIndex, 0]] } forEach _keys;
            _rows set [_uid, [_n, _c, false, _m]];
        } forEach (missionNamespace getVariable ["CQ_statsPub", []]);
        {
            private _uid = getPlayerUID _x;
            private _r = _rows getOrDefault [_uid, [name _x, "", true, createHashMap]];
            _r set [0, name _x];
            _r set [1, _x getVariable ["CQ_class", "Rifleman"]];
            _r set [2, true];
            _rows set [_uid, _r];
        } forEach _players;
        private _g = { params ["_m", "_k"]; _m getOrDefault [_k, 0] };
        private _score = {
            params ["_m"];
            private _t = 0;
            { _t = _t + ([_m, _x select 0] call _g) * (_x select 1) } forEach CQ_statWeights;
            _t
        };
        private _veh = { params ["_m"]; ([_m, "vehLight"] call _g) + ([_m, "vehArmor"] call _g) + ([_m, "vehAir"] call _g) + ([_m, "vehStatic"] call _g) };
        private _obj = { params ["_m"]; ([_m, "objTower"] call _g) + ([_m, "objDepot"] call _g) + ([_m, "objCmdKilled"] call _g) + ([_m, "objCmdCaptured"] call _g) };
        private _kd = { params ["_m"]; ([_m, "killsInf"] call _g) / (([_m, "deaths"] call _g) max 1) };
        private _sortI = (lbCurSel _sortCb) max 0;
        private _val = {
            params ["_m"];
            switch (_sortI) do {
                case 0: { [_m] call _score };
                case 1: { [_m, "killsInf"] call _g };
                case 2: { [_m] call _veh };
                case 3: { [_m] call _obj };
                case 4: { [_m, "heals"] call _g };
                case 5: { [_m, "longest"] call _g };
                case 6: { [_m] call _kd };
                case 7: { [_m, "deaths"] call _g };
                case 8: { [_m, "shots"] call _g };
                case 9: { (([_m, "distFoot"] call _g) + ([_m, "distVeh"] call _g)) / 1000 };
                default { [_m, "timePlayed"] call _g };
            }
        };
        private _fmt = {
            params ["_v"];
            switch (_sortI) do {
                case 5: { format ["%1 m", round _v] };
                case 6: { (_v toFixed 2) };
                case 9: { (_v toFixed 1) };
                case 10: { format ["%1:%2", floor (_v / 3600), [str (floor (_v % 3600 / 60)), "0" + str (floor (_v % 3600 / 60))] select ((floor (_v % 3600 / 60)) < 10)] };
                default { str round _v };
            }
        };
        private _ci = (lbCurSel _clsList) max 0;
        private _filter = if (_ci == 0) then { "" } else { (CQ_classes select (_ci - 1)) select 0 };
        // players per class in the filter list
        private _perCls = createHashMap;
        { if (_y select 2) then { _perCls set [_y select 1, (_perCls getOrDefault [_y select 1, 0]) + 1] } } forEach _rows;
        { _clsList lbSetTextRight [_forEachIndex + 1, str (_perCls getOrDefault [_x select 0, 0])] } forEach CQ_classes;
        _clsList lbSetTextRight [0, str count _players];
        private _list = [];
        { if (_filter == "" || { (_y select 1) == _filter }) then { _list pushBack [[_y select 3] call _val, _x] } } forEach _rows;
        _list sort false;
        private _selUid = uiNamespace getVariable ["CQ_sqStatSel", getPlayerUID player];
        lnbClear _board;
        _board lnbAddRow ["#", "NAME", "CLASS", (CQ_sqSorts select _sortI) select 1, "K", "D", "SCORE"];
        for "_c" from 0 to 6 do { _board lnbSetColor [[0, _c], (CQ_ui get "muted")] };
        private _selRow = -1;
        {
            _x params ["_v", "_uid"];
            (_rows get _uid) params ["_n", "_c", "_on", "_m"];
            private _row = _board lnbAddRow [str (_forEachIndex + 1), [_n, _n + "  (MVP)"] select (_forEachIndex == 0 && { _filter == "" } && { _sortI == 0 } && { _v > 0 }), _c,
                [_v] call _fmt, str ([_m, "killsInf"] call _g), str ([_m, "deaths"] call _g), str round ([_m] call _score)];
            _board lnbSetData [[_row, 0], _uid];
            private _col = switch (true) do {
                case (_uid == getPlayerUID player): { [0.729, 0.224, 0.173, 1] };
                case (!_on): { (CQ_ui get "dim") };
                default { (CQ_ui get "text") };
            };
            for "_cc" from 0 to 6 do { _board lnbSetColor [[_row, _cc], _col] };
            if (_uid == _selUid) then { _selRow = _row };
        } forEach _list;
        if (_selRow > 0) then { _board lnbSetCurSelRow _selRow };

        // details
        private _sel = _rows getOrDefault [_selUid, []];
        if (_sel isEqualTo []) then {
            _detail ctrlSetStructuredText parseText "<t size='0.85' color='#A6A381'>Select a player in the ranking.</t>";
        } else {
            _sel params ["_n", "_c", "_on", "_m"];
            private _rank = 1 + ((([_rows] call {
                params ["_rs"]; private _a = []; { _a pushBack [[_y select 3] call _score, _x] } forEach _rs; _a sort false; _a apply { _x select 1 }
            }) find _selUid) max 0);
            private _t = [_m, "timePlayed"] call _g;
            private _line = { params ["_l", "_v"]; format ["<t size='0.8' color='#A6A381'>%1:  </t><t size='0.8' color='#F2F1DF'>%2</t><br/>", _l, _v] };
            private _sec = { params ["_l"]; format ["<br/><t size='0.75' font='PuristaMedium' color='#7A7860'>%1</t><br/>", _l] };
            private _txt = format ["<t size='1.05' font='PuristaSemibold' color='#F2F1DF'>%1</t><br/><t size='0.8' color='#A6A381'>%2  -  %3</t><br/><t size='0.95' color='#F2F1DF'>SCORE %4</t><t size='0.8' color='#A6A381'>   overall rank #%5</t><br/>",
                _n, _c, ["offline", "online"] select _on, round ([_m] call _score), _rank];
            _txt = _txt + (["COMBAT"] call _sec)
                + (["Infantry kills", [_m, "killsInf"] call _g] call _line)
                + (["Vehicles: light / armour", format ["%1 / %2", [_m, "vehLight"] call _g, [_m, "vehArmor"] call _g]] call _line)
                + (["Vehicles: air / static", format ["%1 / %2", [_m, "vehAir"] call _g, [_m, "vehStatic"] call _g]] call _line)
                + (["Longest kill", format ["%1 m", [_m, "longest"] call _g]] call _line)
                + (["Deaths   -   K/D", format ["%1   -   %2", [_m, "deaths"] call _g, ([_m] call _kd) toFixed 2]] call _line)
                + (["Team kills", [_m, "teamkills"] call _g] call _line)
                + (["OBJECTIVES"] call _sec)
                + (["Radio towers / depots", format ["%1 / %2", [_m, "objTower"] call _g, [_m, "objDepot"] call _g]] call _line)
                + (["Commanders killed / captured", format ["%1 / %2", [_m, "objCmdKilled"] call _g, [_m, "objCmdCaptured"] call _g]] call _line)
                + (["Objective points", [_m, "objPoints"] call _g] call _line)
                + (["SUPPORT & ACTIVITY"] call _sec)
                + (["Heals given", [_m, "heals"] call _g] call _line)
                + (["Shots fired", [_m, "shots"] call _g] call _line)
                + (["On foot / in vehicles", format ["%1 km / %2 km", (([_m, "distFoot"] call _g) / 1000) toFixed 1, (([_m, "distVeh"] call _g) / 1000) toFixed 1]] call _line)
                + (["Time played", format ["%1 h %2 min", floor (_t / 3600), floor (_t % 3600 / 60)]] call _line);
            _detail ctrlSetStructuredText parseText _txt;
        };
    };
    sleep 1;
};
uiNamespace setVariable ["CQ_sqDisplay", displayNull];
