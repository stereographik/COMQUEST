/*
    CQ_fnc_rdfClient  (client, spawned once from initPlayerLocal)
    Threat compass: a compact panel centred at the top of the screen (CQ_rdfTop px below the top
    edge), for a player carrying a radio AND inside the data link's coverage (a linked node of
    CQ_linkPub within its range: base, relays, relay vehicle, vehicles, drones). Outside: hidden.
    It shows the CLOSEST danger the network knows: an enemy a linked MAGPIE drone sees
    (CQ_magVisible), remembered CQ_threatMemory s at its last seen spot, within CQ_threatRange:
      type (INF xN, VEH, ARMOR, AIR, AA, STATIC), an arrow relative to where you look, the
      distance, and a proximity meter. Nothing known: CLEAR. Near the outpost jammer: JAMMED.
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
private _arw = ["RscPicture", (_W - 22) / 2, 3, 22, 22] call _mk;
_arw ctrlSetText "\A3\ui_f\data\map\markers\military\arrow2_CA.paa";
_arw ctrlSetTextColor [0.729, 0.224, 0.173, 1];

// segmented meter
private _segs = 20;
private _gap = 2;
private _segW = (_W - 2 * _pad - (_segs - 1) * _gap) / _segs;
private _bars = [];
for "_i" from 0 to _segs - 1 do {
    private _b = ["RscText", _pad + _i * (_segW + _gap), _H - 14, _segW, 6] call _mk;
    _bars pushBack _b;
};
private _all = [_bg, _edge, _lbl, _pct, _arw] + _bars;
// crash event: "enemy securing device" under the panel while the hidden countdown runs (CQ_crashAlarm)
private _alBg = ["RscText", 0, _H + 4, _W, 24] call _mk;
_alBg ctrlSetBackgroundColor [0.098, 0.094, 0.07, 0.75];
private _alIc = ["RscPicture", 8, _H + 6, 20, 20] call _mk;
_alIc ctrlSetText "\A3\ui_f\data\igui\cfg\simpleTasks\types\danger_ca.paa";
_alIc ctrlSetTextColor [0.729, 0.224, 0.173, 1];
private _alTx = ["RscText", 32, _H + 6, _W - 36, 20] call _mk;
_alTx ctrlSetFont "PuristaMedium";
_alTx ctrlSetFontHeight (14 * _ph);
_alTx ctrlSetTextColor [0.729, 0.224, 0.173, 1];
_alTx ctrlSetText "ENEMY SECURING DEVICE";
private _al = [_alBg, _alIc, _alTx];
{ _x ctrlShow false } forEach _al;
private _alShown = false;

private _shown = -1;
private _disp = 0;
private _offColor = [0.2, 0.192, 0.122, 0.7];
private _lastV = -2;
private _cov = false;
private _covT = 0;
private _mem = createHashMap;     // netId -> [object, last seen position, time]
while { true } do {
    sleep 0.2;
    private _has = alive player && { "ItemRadio" in assignedItems player || { (assignedItems player) findIf { "radio" in toLower _x } > -1 } };
    // data link coverage: inside the range of a linked node (checked once a second)
    if (time >= _covT) then {
        _covT = time + 1;
        private _pp = getPosATL player;
        _cov = (((missionNamespace getVariable ["CQ_linkPub", []]) param [0, []]) findIf { (_x select 2) && { _pp distance2D (_x select 0) < (_x select 1) } }) > -1;
    };
    private _on = _has && { _cov } && { !visibleMap } && { isNull curatorCamera } && { isNull findDisplay 49 };
    if (_on != (_shown == 1)) then {
        { _x ctrlShow _on } forEach _all;
        _shown = [0, 1] select _on;
        _lastV = -2;                                       // redraw once shown again
    };
    private _alOn = _has && { !visibleMap } && { missionNamespace getVariable ["CQ_crashAlarm", false] };
    if (_alOn != _alShown) then { _alShown = _alOn; { _x ctrlShow _alOn } forEach _al };
    if (!_on) then { continue };

    // corridor outpost jammer: noise instead of a reading near it
    private _jp = missionNamespace getVariable ["CQ_opJamPos", []];
    if ((missionNamespace getVariable ["CQ_opJam", false]) && { _jp isNotEqualTo [] } && { player distance2D _jp < CQ_opJamRadius * 1.5 }) then {
        _lastV = -3;
        _lbl ctrlSetText "JAMMED";
        _lbl ctrlSetTextColor [0.729, 0.224, 0.173, 1];
        _edge ctrlSetBackgroundColor [0.729, 0.224, 0.173, 0.9];
        _pct ctrlSetStructuredText parseText "<t align='right' font='PuristaLight' size='0.6' color='#BA392C'>??</t>";
        _arw ctrlShow false;
        { _x ctrlSetBackgroundColor ([_offColor, [0.729, 0.224, 0.173, 0.4 + random 0.5]] select (random 1 < 0.5)) } forEach _bars;
        continue;
    };

    // what the network sees, remembered CQ_threatMemory s at the last seen spot
    {
        if (alive _x) then { _mem set [netId _x, [_x, getPosATLVisual _x, time]] };
    } forEach (missionNamespace getVariable ["CQ_magVisible", []]);
    private _pp = getPosATL player;
    private _best = [];
    private _bestD = CQ_threatRange;
    {
        _y params ["_o", "_p", "_t"];
        if (time - _t > CQ_threatMemory || { !alive _o }) then { _mem deleteAt _x; continue };
        private _dd = _pp distance2D _p;
        if (_dd < _bestD) then { _bestD = _dd; _best = _y };
    } forEach +_mem;

    if (_best isEqualTo []) then {
        if (_lastV == -1) then { continue };               // already showing CLEAR
        _lastV = -1;
        _disp = 0;
        _lbl ctrlSetText "CLEAR";
        _lbl ctrlSetTextColor (CQ_ui get "dim");
        _edge ctrlSetBackgroundColor (CQ_ui get "accent");
        _pct ctrlSetStructuredText parseText "<t align='right' font='PuristaLight' size='0.6' color='#7A7860'>--</t>";
        _arw ctrlShow false;
        { _x ctrlSetBackgroundColor _offColor } forEach _bars;
        continue;
    };
    _best params ["_o", "_p", "_t"];
    private _v = vehicle _o;
    private _cls = toUpper typeOf _v;
    private _type = switch (true) do {
        case (_v isKindOf "Air"): { "AIR" };
        case ((_cls find "_AA" > -1) || { _cls find "AA_F" > -1 }): { "AA" };
        case (_v isKindOf "StaticWeapon"): { "STATIC" };
        case (_v isKindOf "Tank" || { _v isKindOf "Wheeled_APC_F" }): { "ARMOR" };
        case (_v isKindOf "LandVehicle"): { "VEH" };
        default {
            private _n = { (_x select 1) distance2D _p < 75 && { (_x select 0) isKindOf "CAManBase" } } count (values _mem);
            format ["INF x%1", _n max 1]
        };
    };
    private _age = round (time - _t);
    _lastV = -4;
    _lbl ctrlSetText (if (_age > 5) then { format ["%1  %2s", _type, _age] } else { _type });
    _lbl ctrlSetTextColor ([[0.949, 0.945, 0.875, 1], (CQ_ui get "muted")] select (_age > 5));
    _edge ctrlSetBackgroundColor [0.729, 0.224, 0.173, 0.9];
    private _view = getCameraViewDirection player;
    private _look = (_view select 0) atan2 (_view select 1);
    _arw ctrlShow true;
    _arw ctrlSetAngle [((_pp getDir _p) - _look + 360) % 360, 0.5, 0.5];
    _pct ctrlSetStructuredText parseText format [
        "<t align='right'><t font='PuristaSemibold' size='0.65' color='#F2F1DF'>%1</t><t font='PuristaLight' size='0.5' color='#A6A381'> m</t></t>", round _bestD];
    _disp = _disp + ((1 - _bestD / CQ_threatRange) - _disp) * 0.4;
    private _n = round (_disp * _segs);
    {
        _x ctrlSetBackgroundColor ([_offColor, [0.729, 0.224, 0.173, 0.45 + 0.55 * (_forEachIndex / _segs)]] select (_forEachIndex < _n));
    } forEach _bars;
};
