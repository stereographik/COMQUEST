/*
    CQ_fnc_heavyLift
    Heavy lift: the heavy-lift helicopters (CQ_hlClasses, the CH-49 Mohawk) sling load any
    vehicle up to CQ_hlMax kg, past their vanilla limit (5 t), with the game's own hook /
    release (sling load assistant: right Ctrl + B).
      client  [] spawn CQ_fnc_heavyLift         while the player flies a heavy lifter low
                                                (< CQ_hlAlt m) over a vehicle heavier than the
                                                helicopter's vanilla limit but not over CQ_hlMax,
                                                the vehicle is made light enough to hook
                                                (its real mass kept in CQ_hlMass)
      server  ["tick"] call CQ_fnc_heavyLift    director task "heavyLift": a lightened vehicle
                                                no longer hooked, back on the ground and with no
                                                heavy lifter hovering over it gets its real
                                                mass back
    setMass runs where the vehicle is local (remoteExec to the vehicle).
*/
params [["_mode", "client"]];

if (_mode == "tick") exitWith {
    if (!isServer) exitWith {};
    {
        private _v = _x;
        private _m = _v getVariable ["CQ_hlMass", -1];
        if (_m > 0 && { alive _v } && { isNull ropeAttachedTo _v } && { ((getPosATL _v) select 2) < 2 || { isTouchingGround _v } }
            && { (_v nearEntities [CQ_hlClasses, CQ_hlRadius + 15]) findIf { alive _x && { ((getPosATL _x) select 2) < CQ_hlAlt + 10 } } == -1 }) then {
            [_v, _m] remoteExec ["setMass", _v];
            _v setVariable ["CQ_hlMass", nil, true];
            ["Heavy lift: %1 back to %2 kg at grid %3", [getText (configOf _v >> "displayName"), round _m, mapGridPosition _v]] call CQ_fnc_log;
        };
    } forEach (vehicles select { !isNil { _x getVariable "CQ_hlMass" } });
};

if (!hasInterface) exitWith {};
while { true } do {
    sleep 0.5;
    private _h = vehicle player;
    if (_h != player && { driver _h == player } && { (typeOf _h) in CQ_hlClasses } && { alive _h } && { isNull getSlingLoad _h }
        && { ((getPosATL _h) select 2) < CQ_hlAlt }) then {
        private _lim = getNumber (configOf _h >> "slingLoadMaxCargoMass");
        private _cands = (_h nearEntities [["LandVehicle", "Ship"], CQ_hlRadius]) select {
            alive _x && { _x != _h } && { isNil { _x getVariable "CQ_hlMass" } } && { (getMass _x) > _lim } && { (getMass _x) <= CQ_hlMax }
        };
        {
            private _m = getMass _x;
            _x setVariable ["CQ_hlMass", _m, true];
            [_x, _lim * 0.9] remoteExec ["setMass", _x];
            hint format ["Heavy lift: %1 (%2 t) can be hooked.", getText (configOf _x >> "displayName"), (_m / 1000) toFixed 1];
        } forEach _cands;
    };
};
