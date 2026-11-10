/*
    CQ_fnc_menuUi  (client)   U key, or the scroll menu "Menu (U)"
    Hub with every window of the mission, shown on the screen of a field transceiver picture:
      SQUADS / CLASS / STATS   -> CQ_fnc_squadUi (its three tabs)
      VEHICLE SHOP             -> CQ_fnc_shopUi (browse anywhere; buying needs the shop terminal)
      VEHICLE DEPOT            -> CQ_fnc_depotUi (browse anywhere; requests need a depot)
      DEBUG PANEL              -> CQ_fnc_debugUi (debug missions, the host and logged-in admins)
    U or Esc closes it; U again inside a window closes that window (debug panel included).
*/
if (!hasInterface) exitWith {};
disableSerialization;
if (!isNull (uiNamespace getVariable ["CQ_menuDisplay", displayNull])) exitWith { (uiNamespace getVariable "CQ_menuDisplay") closeDisplay 1 };
{ if (!isNull (uiNamespace getVariable [_x, displayNull])) exitWith { (uiNamespace getVariable _x) closeDisplay 1 } } forEach ["CQ_sqDisplay", "CQ_shopDisplay", "CQ_depotDisplay", "CQ_dbgDisplay"];

private _d = (findDisplay 46) createDisplay "RscDisplayEmpty";
uiNamespace setVariable ["CQ_menuDisplay", _d];
_d displayAddEventHandler ["KeyDown", { params ["_d", "_k"]; if (_k == 22) then { _d closeDisplay 1; true } else { false } }];

private _admin = CQ_debug || { isServer } || { (call BIS_fnc_admin) > 0 };
private _nearShop = !isNil "CQ_shopTerminal" && { player distance CQ_shopTerminal <= CQ_shopRange + 4 };
private _items = [
    ["SQUADS", "Join, create, invite, leave", { ["squads"] spawn CQ_fnc_squadUi }],
    ["CLASS", ["Only inside the HQ compound", "You are in the HQ compound: pick a class"] select (player inArea [CQ_basePos, (CQ_compoundSize select 0) / 2 + CQ_classChangeRange, (CQ_compoundSize select 1) / 2 + CQ_classChangeRange, CQ_baseDir, true]), { ["class"] spawn CQ_fnc_squadUi }],
    ["STATS", "Ranking and player details", { ["board"] spawn CQ_fnc_squadUi }],
    ["VEHICLE SHOP", ["Browse here, buy at the shop terminal", "You are at the shop terminal"] select _nearShop, { [] spawn CQ_fnc_shopUi }],
    ["VEHICLE DEPOT", "Free vehicles: browse here, request at a depot (repair station)", { [] spawn CQ_fnc_depotUi }]
];
if (_admin) then { _items pushBack ["DEBUG PANEL", "Test commands (F3)", { [] spawn CQ_fnc_debugUi }] };

// the field transceiver picture (media\comdevice_ca.paa, 1024 x 1024, background cut out); the
// choices are laid out in its screen (blue zone, CQ_menuScreen = [x0, y0, x1, y1] as fractions
// of the picture)
private _npx = (safeZoneH * CQ_menuSize) / pixelH;              // picture size in screen pixels
private _pw = _npx * pixelW; private _ph = _npx * pixelH;
private _picX = safeZoneX + (safeZoneW - _pw) / 2;
private _picY = safeZoneY + (safeZoneH - _ph) / 2;
private _mk = {
    params ["_cls", "_pos", ["_txt", ""]];
    private _c = _d ctrlCreate [[_cls, "CQ_Button"] select (_cls == "RscButton"), -1];
    [_c, _cls] call CQ_fnc_uiStyle;
    _c ctrlSetPosition _pos;
    if (_txt != "") then { _c ctrlSetText _txt };
    _c ctrlCommit 0;
    _c
};
private _pic = ["RscPicture", [_picX, _picY, _pw, _ph]] call _mk;
_pic ctrlSetText (getMissionPath "media\comdevice_ca.paa");
CQ_menuScreen params ["_fx0", "_fy0", "_fx1", "_fy1"];
private _sx = _picX + _pw * _fx0; private _sy = _picY + _ph * _fy0;
private _sw = _pw * (_fx1 - _fx0); private _sh = _ph * (_fy1 - _fy0);
// two columns of choices filling the screen
private _cols = 2;
private _rows = ceil (count _items / _cols);
private _gx = _sw * 0.03; private _gy = _sh * 0.05;
private _bw = (_sw - _gx * (_cols + 1)) / _cols;
private _bh = (_sh - _gy * (_rows + 1)) / _rows;
{
    _x params ["_label", "_tip", "_code"];
    private _c = _forEachIndex mod _cols; private _r = floor (_forEachIndex / _cols);
    private _b = ["RscButton", [_sx + _gx + _c * (_bw + _gx), _sy + _gy + _r * (_bh + _gy), _bw, _bh], _label] call _mk;
    _b ctrlSetFontHeight (_bh * 0.42);
    _b ctrlSetFont "PuristaMedium";
    _b ctrlSetBackgroundColor (CQ_ui get "button");
    _b ctrlSetActiveColor (CQ_ui get "buttonActive");
    _b ctrlSetTextColor (CQ_ui get "text");
    _b ctrlSetTooltip _tip;
    _b setVariable ["CQ_code", _code];
    _b ctrlAddEventHandler ["ButtonClick", {
        params ["_b"];
        private _code = _b getVariable "CQ_code";
        (uiNamespace getVariable ["CQ_menuDisplay", displayNull]) closeDisplay 1;
        [] call _code;
    }];
} forEach _items;
