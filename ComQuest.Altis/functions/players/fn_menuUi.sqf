/*
    CQ_fnc_menuUi  (client)   U key, or the scroll menu "Menu (U)"
    Small hub with every window of the mission:
      SQUADS / CLASS / STATS   -> CQ_fnc_squadUi (its three tabs)
      VEHICLE SHOP             -> CQ_fnc_shopUi (browse anywhere; buying needs the shop terminal)
      DEBUG PANEL              -> CQ_fnc_debugUi (debug missions, the host and logged-in admins)
    U or Esc closes it; U again inside a window closes that window.
*/
if (!hasInterface) exitWith {};
disableSerialization;
if (!isNull (uiNamespace getVariable ["CQ_menuDisplay", displayNull])) exitWith { (uiNamespace getVariable "CQ_menuDisplay") closeDisplay 1 };
{ if (!isNull (uiNamespace getVariable [_x, displayNull])) exitWith { (uiNamespace getVariable _x) closeDisplay 1 } } forEach ["CQ_sqDisplay", "CQ_shopDisplay"];

private _d = (findDisplay 46) createDisplay "RscDisplayEmpty";
uiNamespace setVariable ["CQ_menuDisplay", _d];
_d displayAddEventHandler ["KeyDown", { params ["_d", "_k"]; if (_k == 22) then { _d closeDisplay 1; true } else { false } }];

private _admin = CQ_debug || { isServer } || { (call BIS_fnc_admin) > 0 };
private _nearShop = !isNil "CQ_shopTerminal" && { player distance CQ_shopTerminal <= CQ_shopRange + 4 };
private _items = [
    ["SQUADS", "Join, create, invite, leave", { ["squads"] spawn CQ_fnc_squadUi }],
    ["CLASS", ["Only inside the HQ compound", "You are in the HQ compound: pick a class"] select (player inArea [CQ_basePos, (CQ_compoundSize select 0) / 2 + CQ_classChangeRange, (CQ_compoundSize select 1) / 2 + CQ_classChangeRange, CQ_baseDir, true]), { ["class"] spawn CQ_fnc_squadUi }],
    ["STATS", "Ranking and player details", { ["board"] spawn CQ_fnc_squadUi }],
    ["VEHICLE SHOP", ["Browse here, buy at the shop terminal", "You are at the shop terminal"] select _nearShop, { [] spawn CQ_fnc_shopUi }]
];
if (_admin) then { _items pushBack ["DEBUG PANEL", "Test commands (F3)", { [] spawn CQ_fnc_debugUi }] };

private _L = 0.05;
private _W = safeZoneW * 0.2;
private _H = _L * (1.6 + 1.15 * count _items) + 0.02;
private _X = safeZoneX + (safeZoneW - _W) / 2;
private _Y = safeZoneY + (safeZoneH - _H) / 2;
private _mk = {
    params ["_cls", "_pos", ["_txt", ""]];
    private _c = _d ctrlCreate [_cls, -1];
    _c ctrlSetPosition _pos;
    if (_txt != "") then { _c ctrlSetText _txt };
    _c ctrlCommit 0;
    _c
};
(["RscText", [_X, _Y, _W, _H]] call _mk) ctrlSetBackgroundColor [0.03, 0.04, 0.03, 0.9];
(["RscText", [_X, _Y, _W, _L * 1.1]] call _mk) ctrlSetBackgroundColor [0.12, 0.16, 0.1, 0.95];
(["RscText", [_X + 0.01, _Y + 0.005, _W - 0.07, _L], "COMQUEST"] call _mk) ctrlSetTextColor [0.78, 0.88, 0.48, 1];
private _xb = ["RscButton", [_X + _W - 0.05, _Y + 0.005, 0.04, _L], "X"] call _mk;
_xb ctrlAddEventHandler ["ButtonClick", { (uiNamespace getVariable ["CQ_menuDisplay", displayNull]) closeDisplay 1 }];

{
    _x params ["_label", "_tip", "_code"];
    private _b = ["RscButton", [_X + 0.01, _Y + _L * (1.4 + 1.15 * _forEachIndex), _W - 0.02, _L], _label] call _mk;
    _b ctrlSetTooltip _tip;
    _b setVariable ["CQ_code", _code];
    _b ctrlAddEventHandler ["ButtonClick", {
        params ["_b"];
        private _code = _b getVariable "CQ_code";
        (uiNamespace getVariable ["CQ_menuDisplay", displayNull]) closeDisplay 1;
        [] call _code;
    }];
} forEach _items;
