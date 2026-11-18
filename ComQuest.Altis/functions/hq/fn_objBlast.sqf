/*
    CQ_fnc_objBlast  (server, spawned from the Killed handler of a destructible objective)
    [_hqId, _centre, _radius, _obj] spawn CQ_fnc_objBlast;
    The whole site goes up: one big blast at the centre, then a chain of CQ_blastCount blasts
    across the site in about 2-3 s (sound and fire, no lasting smoke). Each blast hurts
    everyone within CQ_blastDmgR m (more the closer). Afterwards the model's buildings stand
    as ruins and its barriers, crates and tanks are gone.
    Used by: supply depot, fuel tanker, HMG tower (AA pits are neutralised, not destroyed).
*/
params ["_hid", "_c", "_r", ["_obj", objNull]];
private _hq = CQ_hqs getOrDefault [_hid, createHashMap];
_c = [_c select 0, _c select 1, 0];

private _boom = {
    params ["_p", "_big"];
    createVehicle [["HelicopterExploSmall", "HelicopterExploBig"] select _big, _p, [], 0, "CAN_COLLIDE"];
    {
        private _d = _x distance2D _p;
        private _k = 1 - (_d / CQ_blastDmgR);
        if (_k > 0) then {
            if (_x isKindOf "CAManBase") then { _x setDamage ((damage _x) + _k * 1.1) } else { _x setDamage ((damage _x) + _k * 0.45) };
        };
    } forEach ((_p nearEntities [["CAManBase", "LandVehicle", "Air", "Ship"], CQ_blastDmgR]) select { alive _x });
};

[_c, true] call _boom;
sleep 0.3;
for "_i" from 1 to CQ_blastCount do {
    private _p = _c getPos [(_r * 0.75) * sqrt (random 1), random 360];
    [[_p select 0, _p select 1, 0], _i == CQ_blastCount] call _boom;
    sleep (0.3 + random 0.3);
};

// the model: buildings to ruins, the rest gone
private _site = ((_hq getOrDefault ["objects", []]) select { !isNull _x && { _x != _obj } && { _x distance2D _c <= _r } && { !(_x isKindOf "AllVehicles") } });
private _ruins = 0; private _gone = 0;
{
    if (_x isKindOf "House" && { (_x buildingPos -1) isNotEqualTo [] || { (toLowerANSI typeOf _x) find "cargo" > -1 } || { (toLowerANSI typeOf _x) find "hangar" > -1 } }) then {
        _x allowDamage true; _x setDamage 1; _ruins = _ruins + 1;
    } else {
        deleteVehicle _x; _gone = _gone + 1;
    };
} forEach _site;
["HQ #%1: objective at grid %2 blown up (%3 blasts, %4 ruins, %5 objects gone)", [_hid, mapGridPosition _c, CQ_blastCount + 1, _ruins, _gone]] call CQ_fnc_log;
