/*
    CQ_fnc_depotUi  (client, from a vehicle depot action or the U menu)
    Vehicle depot: free vehicles from the global stock (CQ_baseVehicles quotas) | details.
    Shows, per type, how many are left; the squad's depot vehicles out (CQ_depotMaxPerSquad)
    and the player's cooldown. REQUEST works at a depot (CQ_depots); elsewhere it only browses.
    Esc or X closes it.
*/
if (!hasInterface) exitWith {};
disableSerialization;
if (!isNull (uiNamespace getVariable ["CQ_depotDisplay", displayNull])) exitWith {};
private _d = (findDisplay 46) createDisplay "RscDisplayEmpty";
uiNamespace setVariable ["CQ_depotDisplay", _d];

private _items = CQ_baseVehicles select {
    private _c = configFile >> "CfgVehicles" >> (_x select 0);
    isClass _c && { getText (_c >> "DLC") == "" }
};
// Falcon pilots: aircraft only (CQ_fnc_depotSpawn checks it again)
if ((player getVariable ["CQ_class", ""]) == CQ_falconClass) then { _items = _items select { (_x select 0) isKindOf "Air" } };
private _cat = { params ["_c"]; [["light", "truck"] select (_c isKindOf "Truck_F"), "air"] select (_c isKindOf "Air") };
private _cdOf = { params ["_c"]; private _k = [_c] call _cat; (CQ_depotCooldown select (CQ_depotCooldown findIf { (_x select 0) == _k })) select 1 };

private _W = safeZoneW * 0.46;
private _H = safeZoneH * 0.56;
private _X = safeZoneX + (safeZoneW - _W) / 2;
private _Y = safeZoneY + (safeZoneH - _H) / 2;
private _L = 0.042;
private _mk = {
    params ["_cls", "_idc", "_pos", ["_txt", ""]];
    private _c = _d ctrlCreate [[_cls, "CQ_Button"] select (_cls == "RscButton"), _idc];
    [_c, _cls] call CQ_fnc_uiStyle;
    _c ctrlSetPosition _pos;
    if (_txt != "") then { _c ctrlSetText _txt };
    _c ctrlCommit 0;
    _c
};
(["RscText", -1, [_X, _Y, _W, _H]] call _mk) ctrlSetBackgroundColor (CQ_ui get "panel");
(["RscText", -1, [_X, _Y, 0.004, _H]] call _mk) ctrlSetBackgroundColor (CQ_ui get "accent");
private _title = ["RscText", -1, [_X + 0.015, _Y + 0.005, _W * 0.6, _L], "VEHICLE DEPOT"] call _mk;
_title ctrlSetFont "PuristaMedium";
private _close = ["RscButton", -1, [_X + _W - 0.05, _Y + 0.005, 0.04, _L], "X"] call _mk;
_close ctrlAddEventHandler ["ButtonClick", { (uiNamespace getVariable ["CQ_depotDisplay", displayNull]) closeDisplay 1 }];
private _head = ["RscStructuredText", -1, [_X + 0.015, _Y + _L * 1.2, _W - 0.03, _L * 1.1]] call _mk;
private _list = ["RscListBox", 7401, [_X + 0.015, _Y + _L * 2.5, _W * 0.45, _H - _L * 4.2]] call _mk;
private _info = ["RscStructuredText", -1, [_X + 0.025 + _W * 0.45, _Y + _L * 2.5, _W * 0.55 - 0.04, _H - _L * 4.2]] call _mk;
_info ctrlSetBackgroundColor (CQ_ui get "inset");
private _req = ["RscButton", 7402, [_X + _W - 0.015 - _W * 0.3, _Y + _H - _L * 1.4, _W * 0.3, _L * 1.1], "REQUEST"] call _mk;
[_req, true] call CQ_fnc_uiSel;
_req ctrlSetTextColor (CQ_ui get "text");
{
    private _i = _list lbAdd getText (configFile >> "CfgVehicles" >> (_x select 0) >> "displayName");
    _list lbSetData [_i, _x select 0];
} forEach _items;
_list lbSetCurSel 0;
_req ctrlAddEventHandler ["ButtonClick", {
    private _lb = (uiNamespace getVariable ["CQ_depotDisplay", displayNull]) displayCtrl 7401;
    private _i = lbCurSel _lb;
    if (_i < 0) exitWith {};
    [player, _lb lbData _i] remoteExec ["CQ_fnc_depotSpawn", 2];
}];

while { !isNull _d } do {
    private _vehs = (missionNamespace getVariable ["CQ_depotVehs", []]) select { alive _x };
    private _g = group player;
    private _sq = { (_x getVariable ["CQ_depotGroup", grpNull]) == _g } count _vehs;
    private _left = ((missionNamespace getVariable ["CQ_depotReady", createHashMap]) getOrDefault [getPlayerUID player, 0]) - serverTime;
    private _at = (missionNamespace getVariable ["CQ_depots", []]) findIf { player distance (_x select 0) <= CQ_depotRange + 4 } > -1;
    _head ctrlSetStructuredText parseText format [
        "<t size='0.9' color='#A6A381'>%1   </t><t size='1' color='#F2F1DF'>%2 / %3</t><t size='0.9' color='#A6A381'> squad vehicles out   |   %4</t>",
        groupId _g, _sq, CQ_depotMaxPerSquad,
        if (_left > 0) then { "next request in " + ([_left, "MM:SS"] call BIS_fnc_secondsToString) } else { "you can request a vehicle" }];
    {
        private _c = _x select 0;
        private _free = (_x param [2, 1]) - ({ typeOf _x == _c } count _vehs);
        _list lbSetTextRight [_forEachIndex, format ["%1 / %2", _free, _x param [2, 1]]];
        _list lbSetColorRight [_forEachIndex, [[0.73, 0.22, 0.17, 1], [0.95, 0.95, 0.87, 1]] select (_free > 0)];
    } forEach _items;
    private _it = _items param [lbCurSel _list, []];
    private _why = "";
    if (_it isNotEqualTo []) then {
        _it params ["_cls", "", ["_quota", 1]];
        private _cfg = configFile >> "CfgVehicles" >> _cls;
        private _free = _quota - ({ typeOf _x == _cls } count _vehs);
        _why = switch (true) do {
            case (!_at): { "Go to a vehicle depot (repair station) to request it." };
            case (_free <= 0): { "None left in stock: wait for one to be returned, abandoned or destroyed." };
            case (_sq >= CQ_depotMaxPerSquad): { format ["Your squad already has %1 vehicles out: return one at a depot.", CQ_depotMaxPerSquad] };
            case (_left > 0): { format ["Your next request is in %1.", [_left, "MM:SS"] call BIS_fnc_secondsToString] };
            default { "" };
        };
        _info ctrlSetStructuredText parseText format [
            "<t size='1.05' font='PuristaSemibold' color='#F2F1DF'>%1</t><br/><br/><t size='0.8' color='#A6A381'>Seats: </t><t size='0.8' color='#F2F1DF'>%2</t><br/><t size='0.8' color='#A6A381'>In stock: </t><t size='0.8' color='#F2F1DF'>%3 / %4</t><br/><t size='0.8' color='#A6A381'>Cooldown after the request: </t><t size='0.8' color='#F2F1DF'>%5 min</t><br/><br/><t size='0.8' color='#BA392C'>%6</t><br/><br/><t size='0.7' color='#7A7860'>Free vehicles from a shared stock. A vehicle is back in stock as soon as it is destroyed, returned at a depot, or abandoned %7 min. Your squad can have %8 out at once.</t>",
            getText (_cfg >> "displayName"), ([_cls, true] call BIS_fnc_crewCount), _free, _quota, round (([_cls] call _cdOf) / 60), _why,
            round (CQ_vehAbandonDelay / 60), CQ_depotMaxPerSquad];
    };
    _req ctrlEnable (_it isNotEqualTo [] && { _why == "" });
    sleep 0.5;
};
uiNamespace setVariable ["CQ_depotDisplay", displayNull];
