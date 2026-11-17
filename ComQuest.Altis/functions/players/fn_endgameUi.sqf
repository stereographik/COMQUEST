/*
    CQ_fnc_endgameUi  (client)   DEBRIEF on the field tablet, at the end of the game (CQ_endPub,
    CQ_fnc_endgame). Opens by itself for every player once the game is over; U (or X) closes it,
    the U menu's DEBRIEF entry opens it again. Layout (scrolls when it does not fit):
      header      VICTORY / DEFEAT, why, game length, players, "next game in m:ss"
      numbers     HQs destroyed, enemy killed, our deaths, HQs sent by the carrier
      YOU         this player's card (points, kills, deaths, objectives, best weapon, longest
                  kill, heals, events, distances, his awards)   |   HQ timeline (landing ->
                  fall bars, a pip when it was found)
      AWARDS      one tile per award: icon, title, winner, the number that won it (yours framed
                  green, the fun ones grey)
*/
if (!hasInterface || { isNil "CQ_endPub" }) exitWith {};
disableSerialization;
private _open = uiNamespace getVariable ["CQ_endDisplay", displayNull];
if (!isNull _open) exitWith { _open closeDisplay 1 };
{ if (!isNull (uiNamespace getVariable [_x, displayNull])) then { (uiNamespace getVariable _x) closeDisplay 1 } } forEach ["CQ_menuDisplay", "CQ_sqDisplay", "CQ_mrDisplay", "CQ_shopDisplay", "CQ_depotDisplay", "CQ_gfxDisplay"];
CQ_endPub params ["_res", "_why", "_dur", "_endAt", "_np", "_hqN", "_enK", "_kia", "_sent", "_tl", "_rows", "_aw"];

private _d = (call CQ_fnc_uiParent) createDisplay "RscDisplayEmpty";
uiNamespace setVariable ["CQ_endDisplay", _d];
_d displayAddEventHandler ["KeyDown", { params ["_d", "_k"]; if (_k == 22) then { _d closeDisplay 1; true } else { false } }];

// the field tablet, laid out like CQ_fnc_squadUi
private _ph = safeZoneH * CQ_sqSize;
private _pw = (_ph / pixelH) * 1.6 * pixelW;
if (_pw > safeZoneW) then { _ph = _ph * safeZoneW / _pw; _pw = safeZoneW };
private _picX = safeZoneX + (safeZoneW - _pw) / 2;
private _picY = safeZoneY + (safeZoneH - _ph) / 2;
CQ_sqScreen params ["_fx0", "_fy0", "_fx1", "_fy1"];
private _wx = _picX + _pw * _fx0 + 0.004;
private _wy = _picY + _ph * _fy0 + 0.004;
private _ww = _pw * (_fx1 - _fx0) - 0.008;
private _wh = _ph * (_fy1 - _fy0) - 0.008;
private _rl = (0.042 * _wh / (safeZoneH * 0.66)) max 0.03;
[_d, [_picX, _picY, _pw, _ph], [
    [[_wx, _wy, _ww, _wh], [0, 0.04, 0, CQ_sqTint]],
    [[_wx, _wy, _ww, _rl * 1.1], CQ_ui get "header"]
]] call CQ_fnc_tabletBg;
uiNamespace setVariable ["CQ_endTab", "end"];
["create", [_d, [_picX, _picY, _pw, _ph], ([["tab_stats", "Debrief", "end"]] + ([[], [["tab_global", "Map: every group's way, replay the game", "map"]]] select (missionNamespace getVariable ["CQ_traceOn", false]))), "CQ_endTab", ""]] call CQ_fnc_tabletCol;

private _mk = {
    params ["_cls", "_pos", ["_txt", ""], ["_grp", controlNull]];
    private _c = if (isNull _grp) then { _d ctrlCreate [[_cls, "CQ_Button"] select (_cls == "RscButton"), -1] } else { _d ctrlCreate [[_cls, "CQ_Button"] select (_cls == "RscButton"), -1, _grp] };
    [_c, _cls] call CQ_fnc_uiStyle;
    if !(_cls in ["RscPicture", "RscStructuredText"]) then { _c ctrlSetFontHeight ((ctrlFontHeight _c) * CQ_sqFont) };
    _c ctrlSetPosition _pos;
    if (_txt != "") then { _c ctrlSetText _txt };
    _c ctrlCommit 0;
    _c
};
private _st = {         // structured text control
    params ["_pos", "_txt", ["_grp", controlNull], ["_bg", []]];
    private _c = ["RscStructuredText", _pos, "", _grp] call _mk;
    _c ctrlSetStructuredText parseText _txt;
    if (_bg isNotEqualTo []) then { _c ctrlSetBackgroundColor _bg };
    // grow to the text's real height (never cut a line)
    private _p = ctrlPosition _c;
    private _th = ctrlTextHeight _c;
    if (_th > (_p select 3)) then { _p set [3, _th]; _c ctrlSetPosition _p; _c ctrlCommit 0 };
    _c
};
private _h = { (ctrlPosition _this) select 3 };
private _box = { params ["_pos", "_col", ["_grp", controlNull]]; private _c = ["RscText", _pos, "", _grp] call _mk; _c ctrlSetBackgroundColor _col; _c };
private _clock = { params ["_s"]; [_s max 0, "HH:MM"] call BIS_fnc_secondsToString };
private _win = _res == "win";
private _green = "#C0DD97"; private _amber = "#FAC775"; private _cream = "#E8E6D9"; private _muted = "#A6A381"; private _red = "#F09595";
private _tile = [0.149, 0.165, 0.125, 0.95];

// header bar: tab title + close
[["RscButton", [_wx + 0.01, _wy + 0.004, _ww * 0.22, _rl], "DEBRIEF"] call _mk, true] call CQ_fnc_uiSel;
private _close = ["RscButton", [_wx + _ww - 0.05, _wy + 0.004, 0.04, _rl], "X"] call _mk;
_close ctrlAddEventHandler ["ButtonClick", { (uiNamespace getVariable ["CQ_endDisplay", displayNull]) closeDisplay 1 }];
private _timer = [[_wx + _ww * 0.45, _wy + 0.002, _ww * 0.45, _rl * 1.05], ""] call _st;

// everything else in a scrolling group
private _gy = _wy + _rl * 1.25;
private _gh = _wh - _rl * 1.3;
private _g = _d ctrlCreate ["RscControlsGroup", -1];
_g ctrlSetPosition [_wx + 0.006, _gy, _ww - 0.012, _gh];
_g ctrlCommit 0;
private _iw = _ww - 0.012 - 0.02;        // inner width (scrollbar room)
private _y = 0;

// result
private _c = [[0, _y, _iw, _rl], format ["<t size='1.35' color='%1' font='PuristaBold'>%2</t>  <t size='0.8' color='%3'>%4</t><br/><t size='0.7' color='%3'>operation ComQuest · %5 · %6 player(s)</t>",
    [_red, _green] select _win, ["DEFEAT", "VICTORY"] select _win, _muted, _why, [_dur] call _clock, _np], _g] call _st;
_y = _y + (_c call _h) + _rl * 0.3;

// key numbers: each box fitted, the row as tall as the tallest
private _nw = (_iw - 3 * 0.006) / 4;
private _nb = [];
{
    _x params ["_lb", "_v"];
    _nb pushBack ([[_forEachIndex * (_nw + 0.006), _y, _nw, _rl], format ["<t size='0.65' color='%1'>%2</t><br/><t size='1.05' color='%3'>%4</t>", _muted, _lb, _cream, _v], _g, _tile] call _st);
} forEach [["HQs destroyed", format ["%1 / %2", _hqN select 0, _hqN select 1]], ["Enemy killed", _enK], ["Our deaths", _kia], ["Carrier sent", format ["%1 HQs", _sent]]];
private _rowH = 0; { _rowH = _rowH max (_x call _h) } forEach _nb;
{ private _p = ctrlPosition _x; _p set [3, _rowH]; _x ctrlSetPosition _p; _x ctrlCommit 0 } forEach _nb;
_y = _y + _rowH + _rl * 0.4;

// YOU card (left): title, 4 numbers in a grid, details; framed green
private _me = _rows findIf { (_x select 0) == getPlayerUID player };
private _cw = _iw * 0.55;
private _cy = _y;
private _frame = [[0, _y, _cw, _rl], [0.75, 0.87, 0.59, 0.55], _g] call _box;
private _inner = [[0.0015, _y + 0.002, _cw - 0.003, _rl], [0.106, 0.118, 0.09, 1], _g] call _box;
private _myAw = (_aw select { (_x select 2) == getPlayerUID player }) apply { _x select 0 };
private _yy = _y + 0.006;
if (_me < 0) then {
    _c = [[0.008, _yy, _cw - 0.016, _rl], format ["<t size='0.8' color='%1'>YOU</t><br/><t size='0.7' color='%2'>no statistics for you this game</t>", _green, _muted], _g] call _st;
    _yy = _yy + (_c call _h);
} else {
    (_rows select _me) params ["", "_n", "_sq", "_cls", "_pts", "_k", "_de", "_ob", "_he", "_bw", "_bk", "_lg", "_ev", "_kmV", "_kmF"];
    _c = [[0.008, _yy, _cw - 0.016, _rl], format ["<t size='0.85' color='%1'>YOU · %2</t><br/><t size='0.65' color='%3'>%4 · %5</t>", _green, _n, _muted, _sq, _cls], _g] call _st;
    _yy = _yy + (_c call _h) + 0.004;
    private _qw = (_cw - 0.016) / 4;
    private _qs = [];
    { _qs pushBack ([[0.008 + _forEachIndex * _qw, _yy, _qw, _rl], format ["<t size='0.6' color='%1'>%2</t><br/><t size='1.0' color='%3'>%4</t>", _muted, _x select 0, _cream, _x select 1], _g] call _st) } forEach [["points", _pts], ["kills", _k], ["deaths", _de], ["objectives", _ob]];
    private _qh = 0; { _qh = _qh max (_x call _h) } forEach _qs;
    _yy = _yy + _qh + 0.004;
    _c = [[0.008, _yy, _cw - 0.016, _rl], format ["<t size='0.65' color='%1'>best weapon %2 (%3 kills) · longest %4 m<br/>heals %5 · events %6 · %7 km driven · %8 km on foot</t><br/><t size='0.7' color='%9'>%10</t>",
        _cream, _bw, _bk, _lg, _he, _ev, _kmV, _kmF, _green, ["no award this time", "your awards: " + (_myAw joinString " · ")] select (_myAw isNotEqualTo [])], _g] call _st;
    _yy = _yy + (_c call _h);
};
private _ch = (_yy - _y) + 0.006;
{ private _p = ctrlPosition _x; _p set [3, _ch - ([0, 0.004] select (_x == _inner))]; _x ctrlSetPosition _p; _x ctrlCommit 0 } forEach [_frame, _inner];

// HQ timeline (right)
private _tx = _cw + 0.012;
private _tw = _iw - _tx;
_c = [[_tx, _y, _tw, _rl], format ["<t size='0.8' color='%1'>HQ timeline</t><br/><t size='0.55' color='%2'>landing to fall · amber mark = found</t>", _amber, _muted], _g] call _st;
private _ty = _y + (_c call _h) + 0.006;
private _span = _dur max 1;
private _lw = _tw * 0.32;
private _bx = _tx + _lw;
private _bw2 = _tw - _lw - 0.004;
{
    _x params ["_n", "_b", "_f", "_fa"];
    private _lc = [[_tx, _ty, _lw, _rl * 0.6], format ["<t size='0.6' color='%1'>%2</t>", _cream, _n], _g] call _st;
    private _lh = _lc call _h;
    private _bh = _lh * 0.5;
    private _by = _ty + (_lh - _bh) / 2;
    [[_bx, _by, _bw2, _bh], [0.2, 0.216, 0.165, 1], _g] call _box;
    private _x0 = ((_b max 0) / _span) min 1;
    private _x1 = ([_fa, _span] select (_fa < 0)) / _span min 1;
    [[_bx + _bw2 * _x0, _by, (_bw2 * (_x1 - _x0)) max 0.002, _bh], [[0.73, 0.22, 0.17, 1], [0.57, 0.55, 0.23, 1]] select (_fa < 0), _g] call _box;
    if (_f >= 0) then { [[_bx + _bw2 * ((_f / _span) min 1) - 0.002, _by - _bh * 0.3, 0.004, _bh * 1.6], [0.98, 0.78, 0.46, 1], _g] call _box };
    _ty = _ty + _lh + 0.002;
} forEach _tl;
_y = (_y + _ch) max _ty;
_y = _y + _rl * 0.5;

// AWARDS: tiles as tall as the tallest text
_c = [[0, _y, _iw, _rl], format ["<t size='0.85' color='%1' font='PuristaBold'>AWARDS</t>", _amber], _g] call _st;
_y = _y + (_c call _h) + 0.004;
private _cols = 4;
private _aw2 = (_iw - (_cols - 1) * 0.006) / _cols;
if (_aw isEqualTo []) then { [[0, _y, _iw, _rl], format ["<t size='0.7' color='%1'>no awards this game: nobody scored yet</t>", _muted], _g] call _st };
// first pass: the text heights
private _txts = _aw apply {
    _x params ["_title", "_icon", "_uid", "_n", "_stat", "_fun"];
    format ["<t size='0.7' color='%1'>%2</t><br/><t size='0.75' color='%3'>%4</t><br/><t size='0.55' color='%5'>%6</t>", [_amber, "#B4B2A9"] select _fun, _title, _cream, _n, _muted, _stat]
};
private _icw = _aw2 * 0.22;
private _ah = _rl * 1.5;
{
    private _t = [[0, _y, _aw2 - _icw - 0.006, _rl], _x, _g] call _st;
    _ah = _ah max ((_t call _h) + 0.006);
    ctrlDelete _t;
} forEach _txts;
{
    _x params ["_title", "_icon", "_uid", "_n", "_stat", "_fun"];
    private _cx = (_forEachIndex mod _cols) * (_aw2 + 0.006);
    private _cy = _y + floor (_forEachIndex / _cols) * (_ah + 0.006);
    private _mine = _uid == getPlayerUID player;
    if (_mine) then { [[_cx, _cy, _aw2, _ah], [0.75, 0.87, 0.59, 0.8], _g] call _box };
    [[_cx + ([0, 0.0015] select _mine), _cy + ([0, 0.002] select _mine), _aw2 - ([0, 0.003] select _mine), _ah - ([0, 0.004] select _mine)], _tile, _g] call _box;
    private _is = (_icw * 0.8) min (_ah * 0.7 * 3 / 4);
    private _ic = ["RscPicture", [_cx + 0.004, _cy + (_ah - _is * 4 / 3) / 2, _is, _is * 4 / 3], _icon, _g] call _mk;
    _ic ctrlSetTextColor ([[0.98, 0.78, 0.46, 1], [0.7, 0.7, 0.66, 1]] select _fun);
    [[_cx + _icw, _cy + 0.003, _aw2 - _icw - 0.006, _ah - 0.006], _txts select _forEachIndex, _g] call _st;
} forEach _aw;

// ---- MAP tab: each group's trace (friendlies white -> blue, enemies black -> red over the game),
//      the HQs, a slider to replay the game minute by minute
private _mapCtrls = [];
private _sh = _rl * 0.9;
private _lg = [[_wx + 0.006, _gy + _gh - _sh * 2.3, _ww - 0.012, _sh], format ["<t size='0.6' color='%1'>friendlies </t><t size='0.6' color='#FFFFFF'>start </t><t size='0.6' color='#2A6CFF'>end</t><t size='0.6' color='%1'>   ·   enemies </t><t size='0.6' color='#777777'>start </t><t size='0.6' color='#FF2A1A'>end</t><t size='0.6' color='%1'>   ·   crosses: HQs (amber = destroyed)</t>", _muted], controlNull, [0.1, 0.11, 0.08, 0.9]] call _st;
private _tlab = [[_wx + 0.006, _gy + _gh - _sh * 1.15, _ww * 0.2, _sh], format ["<t size='0.65' color='%1'>replay</t>", _muted]] call _st;
private _sl = _d ctrlCreate ["RscXSliderH", -1];
_sl ctrlSetPosition [_wx + _ww * 0.12, _gy + _gh - _sh * 1.05, _ww * 0.7, _sh * 0.8];
_sl ctrlCommit 0;
_sl sliderSetRange [0, _dur max 1];
_sl sliderSetPosition (_dur max 1);
private _tval = [[_wx + _ww * 0.83, _gy + _gh - _sh * 1.15, _ww * 0.16, _sh], ""] call _st;
private _map = _d ctrlCreate ["RscMapControl", -1];
_map ctrlSetPosition [_wx + 0.006, _gy, _ww - 0.012, _gh - _sh * 2.4];
_map ctrlCommit 0;
_map ctrlMapAnimAdd [0, 0.6, [worldSize / 2, worldSize / 2, 0]];
ctrlMapAnimCommit _map;
_mapCtrls = [_map, _lg, _tlab, _sl, _tval];
uiNamespace setVariable ["CQ_endMapCtrls", _mapCtrls];
uiNamespace setVariable ["CQ_endDebCtrl", _g];
uiNamespace setVariable ["CQ_endTval", _tval];
{ _x ctrlShow false } forEach _mapCtrls;

// segments [p1, p2, t, side] and the colour list for a replay time (rebuilt when the slider moves)
private _segs = [];
{
    _x params ["_side", "_pts"];
    for "_i" from 1 to (count _pts - 1) do {
        private _a = _pts select (_i - 1); private _b = _pts select _i;
        _segs pushBack [[_a select 0, _a select 1, 0], [_b select 0, _b select 1, 0], _b select 2, _side];
    };
} forEach ((missionNamespace getVariable ["CQ_endTrace", [[], []]]) select 0);
uiNamespace setVariable ["CQ_endSegs", _segs];
CQ_endBuild = {
    params ["_T"];
    private _T1 = _T max 1;
    private _out = [];
    {
        _x params ["_a", "_b", "_t", "_side"];
        if (_t <= _T) then {
            private _f = (_t / _T1) min 1;
            _out pushBack [_a, _b, [[1 - 0.835 * _f, 1 - 0.576 * _f, 1, 0.9], [_f, 0.165 * _f, 0.1 * _f, 0.9]] select (_side == 1)];
        };
    } forEach (uiNamespace getVariable ["CQ_endSegs", []]);
    uiNamespace setVariable ["CQ_endDraw", _out];
    uiNamespace setVariable ["CQ_endT", _T];
    (uiNamespace getVariable ["CQ_endTval", controlNull]) ctrlSetStructuredText parseText format ["<t size='0.7' align='right' color='#FAC775'>%1</t>", [_T, "HH:MM"] call BIS_fnc_secondsToString];
};
[_dur] call CQ_endBuild;
_sl ctrlAddEventHandler ["SliderPosChanged", { params ["_c", "_v"]; [round _v] call CQ_endBuild }];
_map ctrlAddEventHandler ["Draw", {
    params ["_m"];
    { _m drawLine _x } forEach (uiNamespace getVariable ["CQ_endDraw", []]);
    private _T = uiNamespace getVariable ["CQ_endT", 0];
    _m drawIcon ["\A3\ui_f\data\map\markers\nato\b_hq.paa", [0.3, 0.55, 1, 1], CQ_basePos, 24, 24, 0, "BASE", 1, 0.045, "PuristaMedium", "right"];
    {
        _x params ["_p", "_dead", "_n", "_fa"];
        private _gone = _dead && { _fa >= 0 } && { _fa <= _T };
        _m drawIcon ["\A3\ui_f\data\map\markers\military\destroy_CA.paa", [[1, 0.42, 0.35, 1], [0.98, 0.78, 0.46, 1]] select _gone, _p, 22, 22, 0, _n, 1, 0.045, "PuristaMedium", "right"];
    } forEach ((missionNamespace getVariable ["CQ_endTrace", [[], []]]) select 1);
}];

// the countdown to the next game, and the tab switch (DEBRIEF / MAP)
[_d, _timer, _endAt] spawn {
    disableSerialization;
    params ["_d", "_timer", "_endAt"];
    private _shown = "end";
    while { !isNull _d } do {
        private _left = (_endAt - serverTime) max 0;
        _timer ctrlSetStructuredText parseText format ["<t align='right' size='0.8' color='#FAC775'>next game in %1</t>", [_left, "MM:SS"] call BIS_fnc_secondsToString];
        private _tab = uiNamespace getVariable ["CQ_endTab", "end"];
        if (_tab != _shown) then {
            _shown = _tab;
            (uiNamespace getVariable ["CQ_endDebCtrl", controlNull]) ctrlShow (_tab == "end");
            { _x ctrlShow (_tab == "map") } forEach (uiNamespace getVariable ["CQ_endMapCtrls", []]);
            ["sel", ["CQ_endTab", _tab]] call CQ_fnc_tabletCol;
        };
        sleep 0.1;
    };
};
