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
["create", [_d, [_picX, _picY, _pw, _ph], [["tab_stats", "Debrief", "end"]], "CQ_endTab", ""]] call CQ_fnc_tabletCol;

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
    _c
};
private _box = { params ["_pos", "_col", ["_grp", controlNull]]; private _c = ["RscText", _pos, "", _grp] call _mk; _c ctrlSetBackgroundColor _col; _c };
private _clock = { params ["_s"]; [_s max 0, "HH:MM"] call BIS_fnc_secondsToString };
private _win = _res == "win";
private _green = "#C0DD97"; private _amber = "#FAC775"; private _cream = "#E8E6D9"; private _muted = "#A6A381"; private _red = "#F09595";
private _tile = [0.149, 0.165, 0.125, 0.95];

// header bar: tab title + close
[["RscButton", [_wx + 0.01, _wy + 0.004, _ww * 0.22, _rl], "DEBRIEF"] call _mk, true] call CQ_fnc_uiSel;
private _close = ["RscButton", [_wx + _ww - 0.05, _wy + 0.004, 0.04, _rl], "X"] call _mk;
_close ctrlAddEventHandler ["ButtonClick", { (uiNamespace getVariable ["CQ_endDisplay", displayNull]) closeDisplay 1 }];
private _timer = [[_wx + _ww * 0.5, _wy + 0.004, _ww * 0.45, _rl], ""] call _st;

// everything else in a scrolling group
private _gy = _wy + _rl * 1.25;
private _gh = _wh - _rl * 1.3;
private _g = _d ctrlCreate ["RscControlsGroup", -1];
_g ctrlSetPosition [_wx + 0.006, _gy, _ww - 0.012, _gh];
_g ctrlCommit 0;
private _iw = _ww - 0.012 - 0.02;        // inner width (scrollbar room)
private _y = 0;

// result
[[0, _y, _iw, _rl * 1.6], format ["<t size='1.6' color='%1' font='PuristaBold'>%2</t>   <t color='%3'>%4</t><br/><t size='0.85' color='%3'>operation ComQuest · %5 · %6 player(s)</t>",
    [_red, _green] select _win, ["DEFEAT", "VICTORY"] select _win, _muted, _why, [_dur] call _clock, _np], _g] call _st;
_y = _y + _rl * 2.1;

// key numbers
private _nw = (_iw - 3 * 0.006) / 4;
{
    _x params ["_lb", "_v"];
    [[_forEachIndex * (_nw + 0.006), _y, _nw, _rl * 1.7], format ["<t size='0.75' color='%1'>%2</t><br/><t size='1.3' color='%3'>%4</t>", _muted, _lb, _cream, _v], _g, _tile] call _st;
} forEach [["HQs destroyed", format ["%1 / %2", _hqN select 0, _hqN select 1]], ["Enemy killed", _enK], ["Our deaths", _kia], ["Carrier sent", format ["%1 HQs", _sent]]];
_y = _y + _rl * 2.0;

// YOU card
private _me = _rows findIf { (_x select 0) == getPlayerUID player };
private _cw = _iw * 0.53;
private _ch = _rl * 5.2;
[[0, _y, _cw, _ch], [0.75, 0.87, 0.59, 0.55], _g] call _box;
[[0.0015, _y + 0.002, _cw - 0.003, _ch - 0.004], [0.106, 0.118, 0.09, 1], _g] call _box;
private _myAw = (_aw select { (_x select 2) == getPlayerUID player }) apply { _x select 0 };
private _you = if (_me < 0) then { format ["<t color='%1'>YOU</t><br/><t color='%2'>no statistics for you this game</t>", _green, _muted] } else {
    (_rows select _me) params ["", "_n", "_sq", "_cls", "_pts", "_k", "_de", "_ob", "_he", "_bw", "_bk", "_lg", "_ev", "_kmV", "_kmF"];
    format ["<t color='%1'>YOU · %2</t>   <t color='%3'>%4 · %5</t><br/><t size='0.75' color='%3'>points   kills   deaths   objectives</t><br/><t size='1.2' color='%6'>%7      %8      %9      %10</t><br/><t size='0.85' color='%6'>best weapon %11 (%12 kills) · longest %13 m<br/>heals %14 · events %15 · %16 km driven · %17 km on foot</t><br/><t size='0.85' color='%1'>%18</t>",
        _green, _n, _muted, _sq, _cls, _cream, _pts, _k, _de, _ob, _bw, _bk, _lg, _he, _ev, _kmV, _kmF,
        ["no award this time", "your awards: " + (_myAw joinString " · ")] select (_myAw isNotEqualTo [])]
};
[[0.006, _y + 0.004, _cw - 0.012, _ch - 0.008], _you, _g] call _st;

// HQ timeline
private _tx = _cw + 0.012;
private _tw = _iw - _tx;
[[_tx, _y, _tw, _rl], format ["<t color='%1'>HQ timeline</t>   <t size='0.75' color='%2'>landing -> fall · pip = found</t>", _amber, _muted], _g] call _st;
private _span = _dur max 1;
private _lw = _tw * 0.3;
private _bx = _tx + _lw;
private _bw2 = _tw - _lw;
private _bh = _rl * 0.45;
{
    _x params ["_n", "_b", "_f", "_fa"];
    private _ry = _y + _rl * (1.05 + _forEachIndex * 0.62);
    if (_ry > _y + _ch) then { break };
    [[_tx, _ry - _rl * 0.15, _lw, _rl * 0.7], format ["<t size='0.75' color='%1'>%2</t>", _cream, _n], _g] call _st;
    [[_bx, _ry, _bw2, _bh], [0.2, 0.216, 0.165, 1], _g] call _box;
    private _x0 = ((_b max 0) / _span) min 1;
    private _x1 = ([_fa, _span] select (_fa < 0)) / _span min 1;
    [[_bx + _bw2 * _x0, _ry, (_bw2 * (_x1 - _x0)) max 0.002, _bh], [[0.73, 0.22, 0.17, 1], [0.57, 0.55, 0.23, 1]] select (_fa < 0), _g] call _box;
    if (_f >= 0) then { [[_bx + _bw2 * ((_f / _span) min 1) - 0.002, _ry - _bh * 0.3, 0.004, _bh * 1.6], [0.98, 0.78, 0.46, 1], _g] call _box };
} forEach _tl;
_y = _y + _ch + _rl * 0.5;

// AWARDS
[[0, _y, _iw, _rl], format ["<t color='%1' font='PuristaBold'>AWARDS</t>", _amber], _g] call _st;
_y = _y + _rl * 1.1;
private _cols = 4;
private _aw2 = (_iw - (_cols - 1) * 0.006) / _cols;
private _ah = _rl * 1.9;
{
    _x params ["_title", "_icon", "_uid", "_n", "_stat", "_fun"];
    private _cx = (_forEachIndex mod _cols) * (_aw2 + 0.006);
    private _cy = _y + floor (_forEachIndex / _cols) * (_ah + 0.006);
    private _mine = _uid == getPlayerUID player;
    if (_mine) then { [[_cx, _cy, _aw2, _ah], [0.75, 0.87, 0.59, 0.8], _g] call _box };
    [[_cx + ([0, 0.0015] select _mine), _cy + ([0, 0.002] select _mine), _aw2 - ([0, 0.003] select _mine), _ah - ([0, 0.004] select _mine)], _tile, _g] call _box;
    private _ic = ["RscPicture", [_cx + 0.004, _cy + _ah * 0.18, _ah * 0.62 * 3 / 4, _ah * 0.62], _icon, _g] call _mk;
    _ic ctrlSetTextColor ([[0.98, 0.78, 0.46, 1], [0.7, 0.7, 0.66, 1]] select _fun);
    [[_cx + _ah * 0.55, _cy + 0.002, _aw2 - _ah * 0.57, _ah - 0.004], format ["<t size='0.85' color='%1'>%2</t><br/><t size='0.9' color='%3'>%4</t><br/><t size='0.7' color='%5'>%6</t>",
        [_amber, "#B4B2A9"] select _fun, _title, _cream, _n, _muted, _stat], _g] call _st;
} forEach _aw;
if (_aw isEqualTo []) then { [[0, _y, _iw, _rl], format ["<t color='%1'>no awards this game</t>", _muted], _g] call _st };

// the countdown to the next game
[_d, _timer, _endAt] spawn {
    disableSerialization;
    params ["_d", "_timer", "_endAt"];
    while { !isNull _d } do {
        private _left = (_endAt - serverTime) max 0;
        _timer ctrlSetStructuredText parseText format ["<t align='right' color='#FAC775'>next game in %1</t>", [_left, "MM:SS"] call BIS_fnc_secondsToString];
        sleep 1;
    };
};
