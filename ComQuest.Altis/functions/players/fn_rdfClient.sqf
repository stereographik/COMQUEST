/*
    CQ_fnc_rdfClient  (client, spawned once from initPlayerLocal)
    Radio direction finder: a small signal-strength panel (right side of the screen) for any
    player carrying a radio. It shows the strongest enemy emitter (CQ_rdfSources):
      strength = power x range falloff (CQ_rdfRange) x direction factor
    The antenna is directional: the signal peaks when you LOOK toward the emitter, so
    sweeping your view finds the bearing; walking toward it raises the level.
    No map position is ever given.
*/
if (!hasInterface) exitWith {};
waitUntil { sleep 0.5; !isNull findDisplay 46 };
private _d = findDisplay 46;

private _w = 0.13 * safezoneW;
private _px = safezoneX + safezoneW - _w - 0.012 * safezoneW;
private _py = safezoneY + 0.6 * safezoneH;
private _h = 0.075 * safezoneH;

private _bg = _d ctrlCreate ["RscText", -1];
_bg ctrlSetPosition [_px, _py, _w, _h];
_bg ctrlSetBackgroundColor [0.02, 0.03, 0.02, 0.6];
_bg ctrlCommit 0;
private _lbl = _d ctrlCreate ["RscStructuredText", -1];
_lbl ctrlSetPosition [_px + 0.004 * safezoneW, _py + 0.003 * safezoneH, _w, 0.03 * safezoneH];
_lbl ctrlCommit 0;
private _bars = [];
private _bw = (_w - 0.012 * safezoneW) / 10;
for "_i" from 0 to 9 do {
    private _b = _d ctrlCreate ["RscText", -1];
    private _bh = (0.012 + 0.0028 * _i) * safezoneH;
    _b ctrlSetPosition [_px + 0.006 * safezoneW + _i * _bw, _py + _h - 0.008 * safezoneH - _bh, _bw * 0.7, _bh];
    _b ctrlSetBackgroundColor [0.3, 0.3, 0.3, 0.5];
    _b ctrlCommit 0;
    _bars pushBack _b;
};
private _all = [_bg, _lbl] + _bars;

private _shown = -1;
while { true } do {
    sleep 0.25;
    private _has = alive player && { "ItemRadio" in assignedItems player || { (assignedItems player) findIf { "radio" in toLower _x } > -1 } };
    private _on = _has && { !visibleMap } && { isNull curatorCamera };
    if (_on != (_shown == 1)) then {
        { _x ctrlShow _on } forEach _all;
        _shown = [0, 1] select _on;
    };
    if (!_on) then { continue };

    private _view = getCameraViewDirection player;
    private _look = (_view select 0) atan2 (_view select 1);
    private _best = 0;
    {
        _x params ["_pos", "_pow"];
        private _dist = player distance2D _pos;
        if (_dist > CQ_rdfRange) then { continue };
        private _fall = (1 - _dist / CQ_rdfRange) ^ 1.6;
        private _brg = player getDir _pos;
        private _off = abs (((_brg - _look) + 540) % 360 - 180);
        private _dir = 0.25 + 0.75 * ((cos _off) max 0) ^ 2;
        _best = _best max (_pow * _fall * _dir);
    } forEach (missionNamespace getVariable ["CQ_rdfSources", []]);
    // receiver noise
    private _s = ((_best + (random 0.04) - 0.02) max 0) min 1;
    private _n = round (_s * 10);
    {
        private _c = if (_forEachIndex < _n) then {
            [[0.9, 0.35, 0.2, 0.95], [0.95, 0.75, 0.3, 0.95], [0.45, 0.85, 0.4, 0.95]] select (floor (_forEachIndex / 3.4))
        } else { [0.3, 0.3, 0.3, 0.45] };
        _x ctrlSetBackgroundColor _c;
    } forEach _bars;
    _lbl ctrlSetStructuredText parseText format [
        "<t font='EtelkaMonospaceProBold' size='0.75' color='#e3cf7a'>RDF</t><t font='EtelkaMonospacePro' size='0.7' color='#d0d0c0'>  %1</t>",
        if (_s < 0.03) then { "no signal" } else { format ["%1%%", round (_s * 100)] }
    ];
};
