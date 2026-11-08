/*
    CQ_fnc_fieldResupplyTry  (server, from CQ_fnc_logiTick)
    [_hq, _group] call CQ_fnc_fieldResupplyTry  ->  true if the HQ's field truck was sent
    A group short of ammo between CQ_fieldResupplyMin and CQ_fieldResupplyRange from its
    depot holds its position while the HQ drives its field supply truck out to it
    (CQ_fnc_fieldResupply). One run at a time per HQ; needs a standing depot with stock.
*/
params ["_hq", "_g"];

private _truck = _hq get "fieldTruck";
private _depot = _hq get "depot";
if (!(_hq get "buildDone") || { _hq get "fieldRun" } || { !alive _truck } || { !alive _depot }) exitWith { false };
if ((_hq get "stock") < 40) exitWith { false };

private _d = (leader _g) distance2D _depot;
if (_d < CQ_fieldResupplyMin || { _d > CQ_fieldResupplyRange }) exitWith { false };

private _load = CQ_fieldResupplyLoad min (_hq get "stock");
_hq set ["stock", (_hq get "stock") - _load];
_hq set ["fieldRun", true];

[_g] call CQ_fnc_clearWaypoints;
_g setVariable ["CQ_prevRole", _g getVariable ["CQ_role", "patrol"]];
_g setVariable ["CQ_role", "waitSupply"];
_g move (getPosATL leader _g);      // hold here

[_hq, _g, _load] spawn CQ_fnc_fieldResupply;
true
