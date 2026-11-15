/*
    CQ_fnc_gfxUi  (client)   SETTINGS in the U menu: graphics of this player, on the field tablet
      PRESETS     Potato, Low, Balanced, High, Ultra, Pilot (CQ_gfxPresets); "Custom" once a value is moved
      sliders     view distance, object distance (never past the view), shadow distance (CQ_gfxRanges)
      GRASS       5 steps (CQ_gfxGrass, setTerrainGrid: Off = no grass)
      ANIMALS     ambient animals on / off (ambient sounds kept)
      FPS         live readout here, and on / off on the game screen
    Every change applies at once (CQ_fnc_gfx) and is saved on this PC when the window closes.
    U or Esc closes it.
*/
if (!hasInterface) exitWith {};
disableSerialization;
private _open = uiNamespace getVariable ["CQ_gfxDisplay", displayNull];
if (!isNull _open) exitWith { _open closeDisplay 1 };
{ if (!isNull (uiNamespace getVariable [_x, displayNull])) then { (uiNamespace getVariable _x) closeDisplay 1 } } forEach ["CQ_menuDisplay", "CQ_sqDisplay", "CQ_mrDisplay", "CQ_shopDisplay", "CQ_depotDisplay"];
if (isNil "CQ_gfx") then { ["load"] call CQ_fnc_gfx };

private _d = (call CQ_fnc_uiParent) createDisplay "RscDisplayEmpty";   // on the map while it is open
uiNamespace setVariable ["CQ_gfxDisplay", _d];
_d displayAddEventHandler ["KeyDown", { params ["_d", "_k"]; if (_k == 22) then { _d closeDisplay 1; true } else { false } }];
_d displayAddEventHandler ["Unload", { ["save"] call CQ_fnc_gfx }];

// the field tablet, laid out like CQ_fnc_squadUi (window box: _wx, _wy, _ww, _wh; row height _rl)
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
private _mk = {
    params ["_cls", "_pos", ["_txt", ""]];
    private _c = _d ctrlCreate [[_cls, "CQ_Button"] select (_cls == "RscButton"), -1];
    [_c, _cls] call CQ_fnc_uiStyle;
    if !(_cls in ["RscPicture", "RscStructuredText", "RscXSliderH"]) then { _c ctrlSetFontHeight ((ctrlFontHeight _c) * CQ_sqFont) };
    _c ctrlSetPosition _pos;
    if (_txt != "") then { _c ctrlSetText _txt };
    _c ctrlCommit 0;
    _c
};
// tablet picture, dark tint and header bar (CQ_fnc_tabletBg), then the icon column
[_d, [_picX, _picY, _pw, _ph], [
    [[_wx, _wy, _ww, _wh], [0, 0.04, 0, CQ_sqTint]],
    [[_wx, _wy, _ww, _rl * 1.1], CQ_ui get "header"]
]] call CQ_fnc_tabletBg;
uiNamespace setVariable ["CQ_gfxTab", "gfx"];
["create", [_d, [_picX, _picY, _pw, _ph], [["tab_graphics", "Graphics", "gfx"]], "CQ_gfxTab", ""]] call CQ_fnc_tabletCol;
[["RscButton", [_wx + 0.01, _wy + 0.004, _ww * 0.22, _rl], "GRAPHICS"] call _mk, true] call CQ_fnc_uiSel;
private _close = ["RscButton", [_wx + _ww - 0.05, _wy + 0.004, 0.04, _rl], "X"] call _mk;
_close ctrlAddEventHandler ["ButtonClick", { (uiNamespace getVariable ["CQ_gfxDisplay", displayNull]) closeDisplay 1 }];

private _lx = _wx + 0.015;                       // labels
private _lw = _ww * 0.22;
private _cx = _lx + _lw;                         // controls
private _cw = _ww - _lw - 0.03 - _ww * 0.12;     // control width (value column on the right)
private _vx = _cx + _cw + 0.01;
private _row = _rl * 1.45;
private _ry = _wy + _rl * 1.6;
private _hdr = {
    params ["_txt", "_hy"];
    private _c = ["RscText", [_lx, _hy, _ww * 0.6, _rl], _txt] call _mk;
    _c ctrlSetTextColor (CQ_ui get "muted");
    _c
};
private _ctl = createHashMap;

// presets
["PRESETS", _ry] call _hdr;
private _pbw = (_ww - 0.03 - 5 * 0.006) / 6;
private _pbs = [];
{
    private _b = ["RscButton", [_lx + _forEachIndex * (_pbw + 0.006), _ry + _rl * 1.05, _pbw, _rl * 1.1], toUpper (_x select 0)] call _mk;
    _b setVariable ["CQ_preset", _x select 0];
    _b ctrlAddEventHandler ["ButtonClick", { ["preset", (_this select 0) getVariable "CQ_preset"] call CQ_fnc_gfx; call (uiNamespace getVariable "CQ_gfxRefresh") }];
    _pbs pushBack _b;
} forEach CQ_gfxPresets;
_ctl set ["presets", _pbs];
private _pname = ["RscStructuredText", [_lx, _ry + _rl * 2.25, _ww - 0.03, _rl]] call _mk;
_ctl set ["pname", _pname];
_ry = _ry + _rl * 3.6;

// sliders: view, objects, shadows
private _sl = [];
{
    _x params ["_label", "_i"];
    (["RscText", [_lx, _ry, _lw, _rl], _label] call _mk);
    private _s = ["RscXSliderH", [_cx, _ry + _rl * 0.15, _cw, _rl * 0.7]] call _mk;
    (CQ_gfxRanges select (_i - 1)) params ["_mn", "_mx", "_st"];
    _s sliderSetRange [_mn, _mx];
    _s sliderSetSpeed [_st, _st * 5];
    _s setVariable ["CQ_gfxI", _i];
    _s setVariable ["CQ_gfxStep", _st];
    _s ctrlAddEventHandler ["SliderPosChanged", {
        params ["_c", "_v"];
        private _st = _c getVariable "CQ_gfxStep";
        private _i = _c getVariable "CQ_gfxI";
        _v = round (_v / _st) * _st;
        if (_v == (CQ_gfx select _i)) exitWith {};
        ["set", [_i, _v]] call CQ_fnc_gfx;
        // objects never past the view distance
        if (_i == 1 && { (CQ_gfx select 2) > _v }) then { CQ_gfx set [2, _v]; ["apply"] call CQ_fnc_gfx };
        if (_i == 2 && { _v > (CQ_gfx select 1) }) then { CQ_gfx set [2, CQ_gfx select 1]; ["apply"] call CQ_fnc_gfx };
        call (uiNamespace getVariable "CQ_gfxRefresh");
    }];
    private _val = ["RscText", [_vx, _ry, _ww * 0.12, _rl]] call _mk;
    _sl pushBack [_s, _val, _i];
    _ry = _ry + _row;
} forEach [["View distance", 1], ["Objects (trees, buildings)", 2], ["Shadows", 3]];
_ctl set ["sliders", _sl];

// grass
(["RscText", [_lx, _ry, _lw, _rl], "Grass"] call _mk);
private _gbw = (_cw - 4 * 0.006) / 5;
private _gbs = [];
{
    private _b = ["RscButton", [_cx + _forEachIndex * (_gbw + 0.006), _ry, _gbw, _rl], toUpper (_x select 0)] call _mk;
    _b setVariable ["CQ_grid", _x select 1];
    _b ctrlAddEventHandler ["ButtonClick", { ["set", [4, (_this select 0) getVariable "CQ_grid"]] call CQ_fnc_gfx; call (uiNamespace getVariable "CQ_gfxRefresh") }];
    _gbs pushBack _b;
} forEach CQ_gfxGrass;
_ctl set ["grass", _gbs];
_ry = _ry + _row;

// animals
(["RscText", [_lx, _ry, _lw, _rl], "Ambient animals"] call _mk);
private _anim = ["RscButton", [_cx, _ry, _gbw * 2, _rl]] call _mk;
_anim ctrlAddEventHandler ["ButtonClick", { ["set", [5, !(CQ_gfx select 5)]] call CQ_fnc_gfx; call (uiNamespace getVariable "CQ_gfxRefresh") }];
_ctl set ["anim", _anim];
_ry = _ry + _row;

// FPS
(["RscText", [_lx, _ry, _lw, _rl], "FPS"] call _mk);
private _fpsT = ["RscStructuredText", [_cx, _ry, _gbw * 1.5, _rl]] call _mk;
private _fpsB = ["RscButton", [_cx + _gbw * 2 + 0.012, _ry, _gbw * 3, _rl]] call _mk;
_fpsB ctrlAddEventHandler ["ButtonClick", { ["set", [6, !(CQ_gfx select 6)]] call CQ_fnc_gfx; call (uiNamespace getVariable "CQ_gfxRefresh") }];
_ctl set ["fpsB", _fpsB];
_ry = _ry + _row * 1.2;

private _note = ["RscStructuredText", [_lx, _ry, _ww - 0.03, _rl * 2.2]] call _mk;
_note ctrlSetStructuredText parseText "<t size='0.8' color='#A6A381'>Changes apply at once and are saved on this PC (your next games start with them). Objects never go past the view distance. Grass Off and few objects help most on a slow PC; Pilot sees far but keeps the ground light.</t>";

uiNamespace setVariable ["CQ_gfxCtrls", _ctl];
uiNamespace setVariable ["CQ_gfxRefresh", {
    disableSerialization;
    private _ctl = uiNamespace getVariable ["CQ_gfxCtrls", createHashMap];
    if (count _ctl == 0) exitWith {};
    CQ_gfx params ["_pre", "_vd", "_ovd", "_sh", "_grid", "_anim", "_fps"];
    { [_x, (_x getVariable ["CQ_preset", ""]) == _pre] call CQ_fnc_uiSel } forEach (_ctl get "presets");
    (_ctl get "pname") ctrlSetStructuredText parseText format ["<t size='0.85' color='#B4B2A9'>Current: </t><t size='0.9' color='#F2F1DF'>%1</t>", _pre];
    {
        _x params ["_s", "_val", "_i"];
        private _v = CQ_gfx select _i;
        _s sliderSetPosition _v;
        _val ctrlSetText format ["%1 m", _v];
    } forEach (_ctl get "sliders");
    { [_x, (_x getVariable ["CQ_grid", -1]) == _grid] call CQ_fnc_uiSel } forEach (_ctl get "grass");
    (_ctl get "anim") ctrlSetText (["OFF", "ON"] select _anim);
    [_ctl get "anim", _anim] call CQ_fnc_uiSel;
    (_ctl get "fpsB") ctrlSetText (["SHOW ON SCREEN: OFF", "SHOW ON SCREEN: ON"] select _fps);
    [_ctl get "fpsB", _fps] call CQ_fnc_uiSel;
}];
call (uiNamespace getVariable "CQ_gfxRefresh");

// live FPS while the window is open
[_d, _fpsT] spawn {
    disableSerialization;
    params ["_d", "_t"];
    while { !isNull _d } do {
        private _f = round diag_fps;
        private _ci = [0, [1, 2] select (_f >= 45)] select (_f >= 30);
        _t ctrlSetStructuredText parseText format ["<t size='0.95' color='%1'>%2</t><t size='0.8' color='#B4B2A9'> fps</t>", ["#F09595", "#FAC775", "#C0DD97"] select _ci, _f];
        uiSleep 0.5;
    };
};
