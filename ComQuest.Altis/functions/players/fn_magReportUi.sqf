/*
    CQ_fnc_magReportUi  (client)   U twice quickly, or MAGPIE REPORT in the U menu
    The last MAGPIE report on the field tablet (same picture as squads / class / stats), two tabs:
      LAST SEEN         what that report identified (new since the one before) + its HQ news
      GLOBAL SITUATION  every enemy MAGPIE knows and still alive, at the time of that report
    Contacts by category (INFANTRY one row per squad, STATIC, LIGHT VEHICLES, ARMOUR, AIR):
      type | heading | speed | HQ owner | in sight (when the report was made)
    Data: CQ_magReportPub = [serverTime, [news...], [[cat, type, hdg, spd, owner, inSight, new], ...]]
    (CQ_fnc_magTick, with every report). Refreshes every 2 s while open. U or Esc closes it.
*/
if (!hasInterface) exitWith {};
disableSerialization;
private _open = uiNamespace getVariable ["CQ_mrDisplay", displayNull];
if (!isNull _open) exitWith { _open closeDisplay 1 };
{ if (!isNull (uiNamespace getVariable [_x, displayNull])) then { (uiNamespace getVariable _x) closeDisplay 1 } } forEach ["CQ_menuDisplay", "CQ_sqDisplay", "CQ_shopDisplay", "CQ_depotDisplay"];

private _d = (findDisplay 46) createDisplay "RscDisplayEmpty";
uiNamespace setVariable ["CQ_mrDisplay", _d];
_d displayAddEventHandler ["KeyDown", { params ["_d", "_k"]; if (_k == 22) then { _d closeDisplay 1; true } else { false } }];

// the field tablet, laid out like CQ_fnc_squadUi
private _ph = safeZoneH * CQ_sqSize;
private _pw = (_ph / pixelH) * 1.6 * pixelW;
if (_pw > safeZoneW) then { _ph = _ph * safeZoneW / _pw; _pw = safeZoneW };
private _picX = safeZoneX + (safeZoneW - _pw) / 2;
private _picY = safeZoneY + (safeZoneH - _ph) / 2;
CQ_sqScreen params ["_fx0", "_fy0", "_fx1", "_fy1"];
private _X = _picX + _pw * _fx0 + 0.004;
private _Y = _picY + _ph * _fy0 + 0.004;
private _W = _pw * (_fx1 - _fx0) - 0.008;
private _H = _ph * (_fy1 - _fy0) - 0.008;
private _L = (0.042 * _H / (safeZoneH * 0.66)) max 0.03;
private _mk = {
    params ["_cls", "_pos", ["_txt", ""]];
    private _c = _d ctrlCreate [[_cls, "CQ_Button"] select (_cls == "RscButton"), -1];
    [_c, _cls] call CQ_fnc_uiStyle;
    if !(_cls in ["RscPicture", "RscStructuredText"]) then { _c ctrlSetFontHeight ((ctrlFontHeight _c) * CQ_sqFont) };
    _c ctrlSetPosition _pos;
    if (_txt != "") then { _c ctrlSetText _txt };
    _c ctrlCommit 0;
    _c
};
"CQ_mrBg" cutRsc ["RscTitleDisplayEmpty", "PLAIN", 0, false];
private _bg = uiNamespace getVariable ["RscTitleDisplayEmpty", displayNull];
private _pic = _bg ctrlCreate ["RscPicture", -1];
_pic ctrlSetPosition [_picX, _picY, _pw, _ph];
_pic ctrlCommit 0;
_pic ctrlSetText (getMissionPath "media\comtablet_ca.paa");
_d displayAddEventHandler ["Unload", { "CQ_mrBg" cutText ["", "PLAIN"] }];

(["RscText", [_X, _Y, _W, _H]] call _mk) ctrlSetBackgroundColor [0.02, 0.03, 0.02, CQ_mrTint];   // darker than the other windows: dense table
(["RscText", [_X, _Y, _W, _L * 1.1]] call _mk) ctrlSetBackgroundColor (CQ_ui get "header");
private _tabL = ["RscButton", [_X + 0.01, _Y + 0.004, _W * 0.22, _L], "LAST SEEN"] call _mk;
private _tabG = ["RscButton", [_X + 0.02 + _W * 0.22, _Y + 0.004, _W * 0.3, _L], "GLOBAL SITUATION"] call _mk;
uiNamespace setVariable ["CQ_mrTab", uiNamespace getVariable ["CQ_mrTab", "last"]];
_tabL ctrlAddEventHandler ["ButtonClick", { uiNamespace setVariable ["CQ_mrTab", "last"]; uiNamespace setVariable ["CQ_mrDirty", true] }];
_tabG ctrlAddEventHandler ["ButtonClick", { uiNamespace setVariable ["CQ_mrTab", "global"]; uiNamespace setVariable ["CQ_mrDirty", true] }];
private _close = ["RscButton", [_X + _W - 0.05, _Y + 0.004, 0.04, _L], "X"] call _mk;
_close ctrlAddEventHandler ["ButtonClick", { (uiNamespace getVariable ["CQ_mrDisplay", displayNull]) closeDisplay 1 }];

private _top = _Y + _L * 1.5;
private _info = ["RscStructuredText", [_X + 0.01, _top, _W - 0.02, _L * 2.6]] call _mk;
private _ly = _top + _L * 2.8;
private _list = ["RscListNBox", [_X + 0.01, _ly, _W - 0.02, _H - (_ly - _Y) - 0.01]] call _mk;
_list lnbSetColumnsPos [0, 0.42, 0.54, 0.66, 0.88];

private _fill = {
    params ["_info", "_list", "_tabL", "_tabG"];
    (missionNamespace getVariable ["CQ_magReportPub", []]) params [["_t", -1], ["_news", []], ["_rows", []]];
    private _last = (uiNamespace getVariable ["CQ_mrTab", "last"]) == "last";
    // active tab highlighted
    _tabL ctrlSetBackgroundColor (CQ_ui get (["button", "buttonOn"] select _last));
    _tabG ctrlSetBackgroundColor (CQ_ui get (["buttonOn", "button"] select _last));
    lnbClear _list;
    if (_t < 0) exitWith { _info ctrlSetStructuredText parseText "<t size='0.9' color='#F2F1DF'>No MAGPIE report yet.</t>" };
    if (_last) then { _rows = _rows select { _x param [6, false] } };
    private _age = round ((serverTime - _t) / 60);
    private _txt = format ["<t size='0.9' color='#F2F1DF'>%1  ·  report of %2 min ago  ·  %3 contacts</t>",
        ["Every enemy MAGPIE knows", "New in the last report"] select _last, _age, count _rows];
    if (_last) then {
        { _txt = _txt + format ["<br/><t size='0.85' color='#F2F1DF'>%1</t>", _x] } forEach (_news select [0, 2]);
        if (count _news > 2) then { _txt = _txt + format ["<br/><t size='0.8' color='#F2F1DF'>+%1 more HQ news</t>", count _news - 2] };
    };
    _info ctrlSetStructuredText parseText _txt;
    private _muted = [0.85, 0.84, 0.7, 1];   // column titles
    private _r = _list lnbAddRow ["CONTACT", "HDG", "SPD", "HQ", "IN SIGHT"];
    for "_c" from 0 to 4 do { _list lnbSetColor [[_r, _c], _muted] };
    {
        _x params ["_cat", "_name"];
        private _sel = _rows select { (_x select 0) == _cat };
        if (_sel isEqualTo []) then { continue };
        _r = _list lnbAddRow [format ["%1 (%2)", _name, count _sel], "", "", "", ""];
        _list lnbSetColor [[_r, 0], [1, 0.78, 0.3, 1]];   // category: bright amber
        {
            _x params ["", ["_type", "?"], ["_hdg", 0], ["_spd", 0], ["_own", "-"], ["_vis", false], ["_isNew", false]];
            if (isNil "_own" || { !(_own isEqualType "") }) then { _own = "-" };
            private _hx = str (round _hdg);
            while { count _hx < 3 } do { _hx = "0" + _hx };
            _r = _list lnbAddRow ["   " + _type, _hx, format ["%1 km/h", round _spd], _own, ["no", "YES"] select _vis];
            for "_c" from 0 to 3 do { _list lnbSetColor [[_r, _c], [0.95, 0.95, 0.9, 1]] };
            _list lnbSetColor [[_r, 4], [[0.75, 0.75, 0.7, 1], [1, 0.35, 0.3, 1]] select _vis];
        } forEach _sel;
    } forEach [["inf", "INFANTRY"], ["static", "STATIC"], ["light", "LIGHT VEHICLES"], ["armour", "ARMOUR"], ["air", "AIR"]];
};
[_info, _list, _tabL, _tabG] call _fill;
[_d, _info, _list, _tabL, _tabG, _fill] spawn {
    params ["_d", "_info", "_list", "_tabL", "_tabG", "_fill"];
    disableSerialization;
    private _last = (missionNamespace getVariable ["CQ_magReportPub", []]) param [0, -1];
    uiNamespace setVariable ["CQ_mrDirty", false];
    while { !isNull _d } do {
        sleep 0.2;
        if (isNull _d) exitWith {};
        private _t = (missionNamespace getVariable ["CQ_magReportPub", []]) param [0, -1];
        // a new report or another tab: redraw (the list keeps its place otherwise)
        if (_t != _last || { uiNamespace getVariable ["CQ_mrDirty", false] }) then {
            _last = _t; uiNamespace setVariable ["CQ_mrDirty", false];
            [_info, _list, _tabL, _tabG] call _fill;
        };
    };
};
