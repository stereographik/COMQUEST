/*
    CQ_fnc_chargeHit  (server, from the charge's Explode handler on the placing player's machine)
    [_posAGL, _unit] call CQ_fnc_chargeHit;
    Objectives destroyed by a number of engineer charges (CQ_chargeNeed): each charge that goes
    off AT the objective counts once; when the count is reached, the objective is destroyed
    (its Killed handler then announces it and blows the site up, CQ_fnc_objBlast).
      Depot: against or inside the Cargo House (its box + CQ_chargeReach m)
      Fuel tanker: INSIDE the hangar (its box), only there
    A charge from a non-engineer does not count (the player is told).
*/
params ["_pos", "_u"];
if (!isServer) exitWith {};
private _eng = typeOf _u in CQ_engineerClasses || { (_u getVariable ["CQ_class", ""]) == "Engineer" };
// inside an object's box (model space), with a margin
private _inBox = {
    params ["_o", "_m"];
    private _mp = _o worldToModel _pos;
    (boundingBoxReal _o) params ["_a", "_b"];
    (_mp select 0) > (_a select 0) - _m && { (_mp select 0) < (_b select 0) + _m } &&
    { (_mp select 1) > (_a select 1) - _m } && { (_mp select 1) < (_b select 1) + _m } &&
    { (_mp select 2) > (_a select 2) - 1 } && { (_mp select 2) < (_b select 2) + 1 }
};
{
    private _hq = _y;
    {
        private _o = _x;
        if (isNull _o || { !alive _o }) then { continue };
        private _zone = _o getVariable ["CQ_chargeZone", objNull];
        private _hit = if (isNull _zone) then { [_o, CQ_chargeReach] call _inBox } else { [_zone, 0] call _inBox };
        if (!_hit) then { continue };
        private _what = _o getVariable ["CQ_objType", "objective"];
        if (!_eng) exitWith {
            [format ["%1: your charge does not count, only an engineer's charges do", _what]] remoteExec ["systemChat", _u];
        };
        private _need = CQ_chargeNeed getOrDefault [_what, 1];
        private _n = (_o getVariable ["CQ_charges", 0]) + 1;
        _o setVariable ["CQ_charges", _n];
        _o setVariable ["CQ_charger", _u];
        ["HQ #%1: %2 charge %3/%4 by %5", [_hq get "id", _what, _n, _need, name _u]] call CQ_fnc_log;
        if (_n >= _need) then {
            _o allowDamage true;
            _o setDamage 1;
        } else {
            [format ["%1: charge %2/%3", _what, _n, _need]] remoteExec ["systemChat", 0];
        };
    } forEach [_hq getOrDefault ["depot", objNull], _hq getOrDefault ["tanker", objNull]];
} forEach CQ_hqs;
