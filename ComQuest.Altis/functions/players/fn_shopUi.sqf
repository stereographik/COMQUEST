/*
    CQ_fnc_shopUi  (client, from the shop terminal action)
    Vehicle shop: catalog (CQ_shopCatalog, base-game classes only) | details. Shows the squad
    points; BUY is enabled for the squad leader when the squad can afford it and has no
    bought vehicle alive (CQ_shopMaxPerSquad). Esc or X closes it.
*/
if (!hasInterface) exitWith {};
disableSerialization;
if (!isNull (uiNamespace getVariable ["CQ_shopDisplay", displayNull])) exitWith {};
private _d = (findDisplay 46) createDisplay "RscDisplayEmpty";
uiNamespace setVariable ["CQ_shopDisplay", _d];

private _items = CQ_shopCatalog select {
    private _c = configFile >> "CfgVehicles" >> (_x select 0);
    isClass _c && { getText (_c >> "DLC") == "" }
};
uiNamespace setVariable ["CQ_shopItems", _items];

private _W = safeZoneW * 0.46;
private _H = safeZoneH * 0.56;
private _X = safeZoneX + (safeZoneW - _W) / 2;
private _Y = safeZoneY + (safeZoneH - _H) / 2;
private _L = 0.042;
private _mk = {
    params ["_cls", "_idc", "_pos", ["_txt", ""]];
    private _c = _d ctrlCreate [_cls, _idc];
    [_c, _cls] call CQ_fnc_uiStyle;
    _c ctrlSetPosition _pos;
    if (_txt != "") then { _c ctrlSetText _txt };
    _c ctrlCommit 0;
    _c
};
(["RscText", -1, [_X, _Y, _W, _H]] call _mk) ctrlSetBackgroundColor (CQ_ui get "panel");
(["RscText", -1, [_X, _Y, 0.004, _H]] call _mk) ctrlSetBackgroundColor (CQ_ui get "accent");
private _title = ["RscText", -1, [_X + 0.015, _Y + 0.005, _W * 0.6, _L], "VEHICLE SHOP"] call _mk;
_title ctrlSetFont "PuristaMedium";
private _close = ["RscButton", -1, [_X + _W - 0.05, _Y + 0.005, 0.04, _L], "X"] call _mk;
_close ctrlAddEventHandler ["ButtonClick", { (uiNamespace getVariable ["CQ_shopDisplay", displayNull]) closeDisplay 1 }];
private _head = ["RscStructuredText", -1, [_X + 0.015, _Y + _L * 1.2, _W - 0.03, _L * 1.1]] call _mk;
private _list = ["RscListBox", 7301, [_X + 0.015, _Y + _L * 2.5, _W * 0.45, _H - _L * 4.2]] call _mk;
private _info = ["RscStructuredText", -1, [_X + 0.025 + _W * 0.45, _Y + _L * 2.5, _W * 0.55 - 0.04, _H - _L * 4.2]] call _mk;
_info ctrlSetBackgroundColor (CQ_ui get "inset");
private _buy = ["RscButton", 7302, [_X + _W - 0.015 - _W * 0.3, _Y + _H - _L * 1.4, _W * 0.3, _L * 1.1], "BUY"] call _mk;
_buy ctrlSetBackgroundColor (CQ_ui get "buttonOn");
_buy ctrlSetTextColor (CQ_ui get "text");
{
    private _i = _list lbAdd (_x select 2);
    _list lbSetTextRight [_i, format ["%1 pts", _x select 1]];
    _list lbSetData [_i, _x select 0];
} forEach _items;
_list lbSetCurSel 0;
_buy ctrlAddEventHandler ["ButtonClick", {
    private _lb = (uiNamespace getVariable ["CQ_shopDisplay", displayNull]) displayCtrl 7301;
    private _i = lbCurSel _lb;
    if (_i < 0) exitWith {};
    [player, _lb lbData _i] remoteExec ["CQ_fnc_shopBuy", 2];
}];

while { !isNull _d } do {
    private _g = group player;
    private _solo = _g getVariable ["CQ_solo", false];
    private _pts = _g getVariable ["CQ_sqPts", 0];
    private _owned = (_g getVariable ["CQ_sqBought", []]) select { alive _x };
    private _lead = !_solo && { leader _g == player };
    _head ctrlSetStructuredText parseText format [
        "<t size='0.9' color='#8CB7BD'>%1   </t><t size='1' color='#D9F7FF'>%2</t><t size='0.9' color='#8CB7BD'> squad points   |   %3</t>",
        if (_solo) then { "No squad" } else { groupId _g }, _pts,
        if (_owned isEqualTo []) then { "no bought vehicle" } else { "bought vehicle in service: " + getText (configOf (_owned select 0) >> "displayName") }];
    private _i = lbCurSel _list;
    private _it = _items param [_i, []];
    private _why = "";
    if (_it isNotEqualTo []) then {
        _it params ["_cls", "_cost", "_name", "_desc"];
        private _cfg = configFile >> "CfgVehicles" >> _cls;
        _why = switch (true) do {
            case (_solo): { "Join or create a squad first." };
            case (!_lead): { "Only your squad leader can buy." };
            case (count _owned >= CQ_shopMaxPerSquad): { "Your squad already has a bought vehicle in service." };
            case (_pts < _cost): { format ["Your squad needs %1 more points.", _cost - _pts] };
            default { "" };
        };
        _info ctrlSetStructuredText parseText format [
            "<t size='1.05' font='PuristaSemibold' color='#D9F7FF'>%1</t><br/><t size='0.8' color='#8CB7BD'>%2</t><br/><br/><t size='0.85' color='#B8D6DB'>%3</t><br/><br/><t size='0.8' color='#8CB7BD'>Seats: </t><t size='0.8' color='#D9F7FF'>%4</t><br/><t size='0.8' color='#8CB7BD'>Cost: </t><t size='0.8' color='#D9F7FF'>%5 squad points</t><br/><br/><t size='0.8' color='#FF8C7A'>%6</t><br/><br/><t size='0.7' color='#5E7F84'>Squad points come from your squad's kills, destroyed vehicles and objectives. Bought vehicles spawn on the shop pad and do not respawn.</t>",
            _name, getText (_cfg >> "displayName"), _desc, ([_cls, true] call BIS_fnc_crewCount), _cost, _why];
    };
    _buy ctrlEnable (_it isNotEqualTo [] && { _why == "" });
    sleep 0.5;
};
uiNamespace setVariable ["CQ_shopDisplay", displayNull];
