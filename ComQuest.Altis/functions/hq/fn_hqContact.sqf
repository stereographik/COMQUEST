/*
    CQ_fnc_hqContact  (server)
    [_hq] call CQ_fnc_hqContact  ->  [perceivedPos, target] or []
    True when any group of this HQ has spotted a NATO unit (knowsAbout >= 1.5) within
    CQ_contactRadius of the HQ. The position is where the group THINKS the enemy is.
*/
params ["_hq"];

private _c = _hq get "pos";
private _groups = (_hq get "infantry") + [_hq get "cmdGroup"] + (_hq get "support")
    + ((_hq get "vehicles") apply { group effectiveCommander _x });

private _res = [];
{
    private _g = _x;
    if (isNull _g) then { continue };
    private _l = leader _g;
    if (!alive _l) then { continue };

    private _t = _l findNearestEnemy _l;
    if (!isNull _t && { side group _t == west } && { _l knowsAbout _t >= 1.5 } && { _t distance2D _c < CQ_contactRadius }) exitWith {
        private _seen = _l getHideFrom _t;
        if (_seen isEqualTo [0, 0, 0]) then { _seen = getPosATL _t };
        _res = [_seen, _t, _g];
    };
} forEach _groups;

_res
