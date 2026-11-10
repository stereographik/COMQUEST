/*
    CQ_fnc_rdfClient  (client, spawned once from initPlayerLocal)
    Radio direction finder: a compact signal panel, centred at the top of the screen
    (CQ_rdfTop px below the top edge), shown to any player carrying a radio.

    It listens to the CLOSEST active emitter only (CQ_rdfSources: fully built HQs with their
    radio tower standing). None within CQ_rdfRange -> "NO SIGNAL".
      signal = range falloff x direction factor, shown 0-100 %
    The antenna is directional: the signal peaks when you LOOK toward the HQ, so sweeping
    your view finds the bearing; walking toward it raises the level. No map position is given.
*/
if (!hasInterface) exitWith {};
waitUntil { sleep 0.5; !isNull findDisplay 46 };
private _d = findDisplay 46;

// --- layout, in pixels
private _pw = pixelW;
private _ph = pixelH;
private _W = 240;
private _H = 44;
private _pad = 12;
private _x0 = safezoneX + (safezoneW - _W * _pw) / 2;
private _y0 = safezoneY + CQ_rdfTop * _ph;

private _mk = {
    params ["_cls", "_rx", "_ry", "_rw", "_rh"];
    private _c = _d ctrlCreate [[_cls, "CQ_Button"] select (_cls == "RscButton"), -1];
    [_c, _cls] call CQ_fnc_uiStyle;
    _c ctrlSetPosition [_x0 + _rx * _pw, _y0 + _ry * _ph, _rw * _pw, _rh * _ph];
    _c ctrlCommit 0;
    _c
};

private _bg = ["RscText", 0, 0, _W, _H] call _mk;
_bg ctrlSetBackgroundColor [0.098, 0.094, 0.07, 0.75];
private _edge = ["RscText", 0, 0, 3, _H] call _mk;
_edge ctrlSetBackgroundColor (CQ_ui get "accent");

private _lbl = ["RscText", _pad - 2, 3, 120, 20] call _mk;
_lbl ctrlSetFont "PuristaMedium";
_lbl ctrlSetFontHeight (15 * _ph);
_lbl ctrlSetTextColor (CQ_ui get "muted");

private _pct = ["RscStructuredText", _W - 110, 3, 110 - _pad + 4, 22] call _mk;

// segmented meter
private _segs = 20;
private _gap = 2;
private _segW = (_W - 2 * _pad - (_segs - 1) * _gap) / _segs;
private _bars = [];
for "_i" from 0 to _segs - 1 do {
    private _b = ["RscText", _pad + _i * (_segW + _gap), _H - 14, _segW, 6] call _mk;
    _bars pushBack _b;
};
private _all = [_bg, _edge, _lbl, _pct] + _bars;

private _shown = -1;
private _disp = 0;
private _offColor = [0.2, 0.192, 0.122, 0.7];
while { true } do {
    sleep 0.2;
    private _has = alive player && { "ItemRadio" in assignedItems player || { (assignedItems player) findIf { "radio" in toLower _x } > -1 } };
    private _on = _has && { !visibleMap } && { isNull curatorCamera } && { isNull findDisplay 49 };
    if (_on != (_shown == 1)) then {
        { _x ctrlShow _on } forEach _all;
        _shown = [0, 1] select _on;
    };
    if (!_on) then { continue };

    // closest active emitter
    private _src = [];
    private _bestD = 1e10;
    {
        private _dd = player distance2D (_x select 0);
        if (_dd < _bestD) then { _bestD = _dd; _src = _x };
    } forEach (missionNamespace getVariable ["CQ_rdfSources", []]);

    private _target = -1;          // -1 = no signal
    if (_src isNotEqualTo [] && { _bestD <= CQ_rdfRange }) then {
        _src params ["_pos", "_pow"];
        private _view = getCameraViewDirection player;
        private _look = (_view select 0) atan2 (_view select 1);
        private _fall = (1 - _bestD / CQ_rdfRange) ^ 1.6;
        private _off = abs ((((player getDir _pos) - _look) + 540) % 360 - 180);
        private _dir = 0.25 + 0.75 * ((cos _off) max 0) ^ 2;
        _target = ((_pow * _fall * _dir + (random 0.03) - 0.015) max 0) min 1;
    };

    if (_target < 0) then {
        _disp = 0;
        _lbl ctrlSetText "NO SIGNAL";
        _lbl ctrlSetTextColor (CQ_ui get "dim");
        _edge ctrlSetBackgroundColor [0.478, 0.471, 0.376, 0.9];
        _pct ctrlSetStructuredText parseText "<t align='right' font='PuristaLight' size='1.05' color='#7A7860'>--</t>";
        { _x ctrlSetBackgroundColor _offColor } forEach _bars;
    } else {
        _disp = _disp + (_target - _disp) * 0.4;          // smooth the needle
        private _v = round (_disp * 100);
        _lbl ctrlSetText "SIGNAL";
        _lbl ctrlSetTextColor (CQ_ui get "muted");
        _edge ctrlSetBackgroundColor (CQ_ui get "accent");
        _pct ctrlSetStructuredText parseText format [
            "<t align='right'><t font='PuristaSemibold' size='1.25' color='#F2F1DF'>%1</t><t font='PuristaLight' size='0.85' color='#A6A381'> %%</t></t>", _v];
        private _n = round (_disp * _segs);
        {
            _x ctrlSetBackgroundColor ([_offColor, [0.949, 0.945, 0.875, 0.55 + 0.45 * (_forEachIndex / _segs)]] select (_forEachIndex < _n));
        } forEach _bars;
    };
};
