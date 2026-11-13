/*
    CQ_fnc_heavyLift
    Heavy lift: the heavy-lift helicopters (CQ_hlClasses, the CH-49 Mohawk) hook any vehicle up
    to CQ_hlMax kg with their own actions, past their vanilla limit (5 t), at any height
    (setSlingLoad puts the cargo under the helicopter itself).
      client  [] spawn CQ_fnc_heavyLift             the pilot's nearest liftable vehicle within
                                                    CQ_hlRadius m (CQ_hlCand) for his actions
                                                    "Hook <vehicle>" / "Release cargo"
                                                    (added in CQ_fnc_playerSetup)
      server  ["hook", [_heli, _cargo, _unit]]      cargo heavier than the helicopter's limit:
                                                    made light enough (real mass kept in
                                                    CQ_hlMass), then setSlingLoad
      server  ["release", [_heli, _unit]]           setSlingLoad objNull (the "Release cargo" action, or
                                                    automatic once the cargo has sat on the ground
                                                    CQ_hlAutoRelease s with the helicopter nearly
                                                    still)
      server  ["tick"]                              director task "heavyLift": a lightened
                                                    vehicle no longer slung, on the ground,
                                                    gets its real mass back (CQ_hlGrace s after
                                                    it was lightened at the earliest)
    setSlingLoad runs on the server only (called elsewhere, a dedicated server can never release
    the cargo); setMass runs where the cargo is local (remoteExec to it).
*/
params [["_mode", "client"], ["_a", []]];

switch (_mode) do {
    case "hook": {
        if (!isServer) exitWith {};
        _a params ["_h", "_c", "_u"];
        if (!alive _h || { !alive _c } || { !isNull getSlingLoad _h } || { _h distance _c > CQ_hlRadius + 10 }) exitWith {};
        private _m = _c getVariable ["CQ_hlMass", getMass _c];
        if (_m > CQ_hlMax) exitWith { [format ["Too heavy to lift (%1 t, max %2 t)", (_m / 1000) toFixed 1, CQ_hlMax / 1000]] remoteExec ["hint", _u] };
        private _lim = getNumber (configOf _h >> "slingLoadMaxCargoMass");
        [_h, _c, _u, _m, _lim] spawn {
            params ["_h", "_c", "_u", "_m", "_lim"];
            if (_m > _lim * 0.9 && { isNil { _c getVariable "CQ_hlMass" } }) then {
                _c setVariable ["CQ_hlMass", _m, true];
                _c setVariable ["CQ_hlT", time];
                [_c, _lim * 0.9] remoteExec ["setMass", _c];
                private _t = time;
                waitUntil { sleep 0.2; getMass _c <= _lim || { time - _t > 4 } };
            };
            if (_h setSlingLoad _c) then {
                [format ["%1 hooked (%2 t)", getText (configOf _c >> "displayName"), (_m / 1000) toFixed 1]] remoteExec ["hint", _u];
                ["Heavy lift: %1 hooked %2 (%3 kg) at grid %4", [name _u, getText (configOf _c >> "displayName"), round _m, mapGridPosition _c]] call CQ_fnc_log;
            } else {
                ["Can't hook it from here"] remoteExec ["hint", _u];
                ["Heavy lift: %1 failed to hook %2 (mass now %3 kg)", [name _u, typeOf _c, round getMass _c]] call CQ_fnc_log;
            };
        };
    };
    case "release": {
        if (!isServer) exitWith {};
        _a params ["_h", "_u"];
        private _c = getSlingLoad _h;
        if (isNull _c) exitWith {};
        _h setSlingLoad objNull;
        ["Heavy lift: %1 released %2 at grid %3, %4 m above the ground", [name _u, getText (configOf _c >> "displayName"), mapGridPosition _c, round ((getPosATL _c) select 2)]] call CQ_fnc_log;
    };
    case "tick": {
        if (!isServer) exitWith {};
        private _slung = (vehicles select { _x isKindOf "Helicopter" }) apply { getSlingLoad _x };
        {
            private _v = _x;
            private _m = _v getVariable ["CQ_hlMass", -1];
            if (_m > 0 && { alive _v } && { !(_v in _slung) } && { time - (_v getVariable ["CQ_hlT", -1e6]) > CQ_hlGrace }
                && { isTouchingGround _v || { ((getPosATL _v) select 2) < 1.5 } }) then {
                [_v, _m] remoteExec ["setMass", _v];
                _v setVariable ["CQ_hlMass", nil, true];
                ["Heavy lift: %1 back to %2 kg at grid %3", [getText (configOf _v >> "displayName"), round _m, mapGridPosition _v]] call CQ_fnc_log;
            };
        } forEach (vehicles select { !isNil { _x getVariable "CQ_hlMass" } });
    };
    default {
        // client: the pilot's candidate for the "Hook" action
        if (!hasInterface) exitWith {};
        CQ_hlCand = objNull;
        private _downT = -1;
        private _carried = objNull;
        private _lifted = false;
        while { true } do {
            sleep 0.5;
            private _h = vehicle player;
            // auto release: the cargo set down on the ground, helicopter nearly still, CQ_hlAutoRelease s
            private _sl = if (_h != player && { driver _h == player }) then { getSlingLoad _h } else { objNull };
            // only a load that has been carried (off the ground since it was hooked)
            if (_sl != _carried) then { _carried = _sl; _lifted = false };
            if (!isNull _sl && { ((getPosATL _sl) select 2) > 3 }) then { _lifted = true };
            if (CQ_hlAutoRelease > 0 && { _lifted } && { !isNull _sl } && { isTouchingGround _sl || { ((getPosATL _sl) select 2) < 0.5 } } && { speed _h < 8 }) then {
                if (_downT < 0) then { _downT = time };
                if (time - _downT >= CQ_hlAutoRelease) then {
                    _downT = -1;
                    ["release", [_h, player]] remoteExec ["CQ_fnc_heavyLift", 2];
                    hint format ["%1 set down and released", getText (configOf _sl >> "displayName")];
                    sleep 2;
                };
            } else { _downT = -1 };
            CQ_hlCand = if (_h != player && { driver _h == player } && { (typeOf _h) in CQ_hlClasses } && { isNull getSlingLoad _h }) then {
                private _c = (_h nearEntities [["LandVehicle", "Ship"], CQ_hlRadius]) select {
                    alive _x && { _x != _h } && { (_x getVariable ["CQ_hlMass", getMass _x]) <= CQ_hlMax }
                };
                if (_c isEqualTo []) then { objNull } else { ([_c, [], { _x distance _h }, "ASCEND"] call BIS_fnc_sortBy) select 0 };
            } else { objNull };
        };
    };
};
