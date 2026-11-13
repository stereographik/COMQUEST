/*
    CQ_fnc_rspVeh  (server, from player actions through remoteExec)
    Squad respawn vehicle: the squad leader marks one vehicle as his squad's respawn point
    ("lock") or clears it ("unlock"). Squad members at the base (CQ_rspBaseRange from the
    muster point) teleport next to it. A respawn vehicle is locked: nobody can get in (or drive
    it away) until the leader unlocks it or its credits run out. A vehicle starts with
    CQ_rspCredits credits; each teleport costs one; at 0 it stops being a respawn point (its
    credits do not come back if it is marked again).
      ["lock",   _player, _vehicle] call CQ_fnc_rspVeh;
      ["unlock", _player] call CQ_fnc_rspVeh;
      ["use",    _player] call CQ_fnc_rspVeh;
      ["camp", _vehicle, true / false]          camp up / struck (below)
    While a vehicle is a squad respawn point it is a camp: a camo net over it, a tent and a
    campfire beside it (CQ_rspCamp*). Unlocked, out of credits or destroyed: the camp goes.
    State: group variable CQ_rspVeh (public), vehicle variable CQ_rspLeft (public).
*/
params ["_mode", "_p", ["_v", objNull]];
if (!isServer) exitWith {};
if (_mode == "camp") exitWith {
    // here _p is the vehicle, _v true (pitch) / false (strike)
    private _veh = _p;
    { deleteVehicle _x } forEach (_veh getVariable ["CQ_rspCampObjs", []]);
    _veh setVariable ["CQ_rspCampObjs", []];
    if (_v isEqualTo true && { alive _veh }) then {
        private _d = getDir _veh;
        private _vp = getPosATL _veh;
        private _net = createVehicle [CQ_rspCampNet, [0, 0, 0], [], 0, "CAN_COLLIDE"];
        _net setDir _d; _net setPosATL [_vp select 0, _vp select 1, 0];
        private _tp = _veh getPos [9, _d + 90];
        private _tent = createVehicle [CQ_rspCampTent, [0, 0, 0], [], 0, "CAN_COLLIDE"];
        _tent setDir (_d + 180); _tent setPosATL [_tp select 0, _tp select 1, 0]; _tent setVectorUp surfaceNormal _tp;
        private _fp = _veh getPos [8, _d + 135];
        private _fire = createVehicle [CQ_rspCampFire, [0, 0, 0], [], 0, "CAN_COLLIDE"];
        _fire setPosATL [_fp select 0, _fp select 1, 0];
        private _objs = [_net, _tent, _fire];
        { _x allowDamage false } forEach _objs;
        _veh setVariable ["CQ_rspCampObjs", _objs];
        if !(_veh getVariable ["CQ_rspCampEh", false]) then {
            _veh setVariable ["CQ_rspCampEh", true];
            _veh addEventHandler ["Killed", { ["camp", _this select 0, false] call CQ_fnc_rspVeh }];
        };
        ["Respawn vehicle camp pitched at grid %1 (%2)", [mapGridPosition _veh, typeOf _veh]] call CQ_fnc_log;
    };
};
if (isNull _p) exitWith {};
private _say = { params ["_t"]; [_t] remoteExec ["hint", _p] };
private _g = group _p;
private _toSquad = { params ["_t"]; [_t] remoteExec ["systemChat", units _g select { isPlayer _x }] };
private _vName = { params ["_x"]; getText (configOf _x >> "displayName") };

switch (_mode) do {
    case "lock": {
        if (_g getVariable ["CQ_solo", false] || { leader _g != _p }) exitWith { ["Only a squad leader can set the squad respawn vehicle"] call _say };
        if (!alive _v || { !(_v isKindOf "LandVehicle" || { _v isKindOf "Air" }) } || { side group effectiveCommander _v == east }) exitWith {};
        if (getNumber (configOf _v >> "side") == 0) exitWith { ["An enemy vehicle cannot be the squad respawn vehicle"] call _say };   // CSAT models
        if ((_v getVariable ["CQ_rspLeft", CQ_rspCredits]) <= 0) exitWith { [format ["This %1 has no respawn credits left", [_v] call _vName]] call _say };
        private _old = _g getVariable ["CQ_rspVeh", objNull];
        private _owner = (allGroups select { (_x getVariable ["CQ_rspVeh", objNull]) == _v && { _x != _g } }) param [0, grpNull];
        if (!isNull _owner) exitWith { [format ["This vehicle is already the respawn point of %1", groupId _owner]] call _say };
        if (isNil { _v getVariable "CQ_rspLeft" }) then { _v setVariable ["CQ_rspLeft", CQ_rspCredits, true] };
        if (!isNull _old && { _old != _v }) then { [_old, 0] remoteExec ["lock", _old]; ["camp", _old, false] call CQ_fnc_rspVeh };
        _g setVariable ["CQ_rspVeh", _v, true];
        [_v, 2] remoteExec ["lock", _v];                 // nobody gets in while it is a respawn point
        ["camp", _v, true] call CQ_fnc_rspVeh;
        [format ["%1: squad respawn vehicle set to a %2 at %3 (%4 credits)%5", groupId _g, [_v] call _vName, mapGridPosition _v, _v getVariable "CQ_rspLeft",
            ["", " - the previous one is unlocked"] select (!isNull _old && { _old != _v })]] call _toSquad;
        ["Respawn vehicle: %1 locked a %2 (%3 credits)", [groupId _g, typeOf _v, _v getVariable "CQ_rspLeft"]] call CQ_fnc_log;
    };
    case "unlock": {
        if (leader _g != _p) exitWith { ["Only a squad leader can unlock the squad respawn vehicle"] call _say };
        private _rv = _g getVariable ["CQ_rspVeh", objNull];
        if (isNull _rv) exitWith {};
        [_rv, 0] remoteExec ["lock", _rv];
        ["camp", _rv, false] call CQ_fnc_rspVeh;
        _g setVariable ["CQ_rspVeh", objNull, true];
        [format ["%1: squad respawn vehicle unlocked", groupId _g]] call _toSquad;
    };
    case "use": {
        private _rv = _g getVariable ["CQ_rspVeh", objNull];
        if (!alive _rv) exitWith { _g setVariable ["CQ_rspVeh", objNull, true]; ["Your squad has no respawn vehicle"] call _say };
        if (_p distance2D CQ_musterPos > CQ_rspBaseRange) exitWith { ["Teleports leave from the base"] call _say };
        private _left = _rv getVariable ["CQ_rspLeft", 0];
        if (_left <= 0) exitWith { _g setVariable ["CQ_rspVeh", objNull, true]; ["The respawn vehicle has no credits left"] call _say };
        // on the ground next to it (it is locked: nobody sits in it), only when it stands still
        if (speed _rv > 5 || { ((getPosATL _rv) select 2) > 3 }) exitWith { ["The respawn vehicle is moving: try again in a moment"] call _say };
        _left = _left - 1;
        _rv setVariable ["CQ_rspLeft", _left, true];
        private _pos = (_rv getPos [5 + random 2, getDir _rv + 180 + random 40 - 20]);
        _p setPosATL [_pos select 0, _pos select 1, 0];
        [format ["%1 deployed to the squad %2 (%3 credits left)", name _p, [_rv] call _vName, _left]] call _toSquad;
        ["Respawn vehicle: %1 deployed to %2 (%3 left)", [name _p, typeOf _rv, _left]] call CQ_fnc_log;
        if (_left <= 0) then {
            _g setVariable ["CQ_rspVeh", objNull, true];
            [_rv, 0] remoteExec ["lock", _rv];
            ["camp", _rv, false] call CQ_fnc_rspVeh;
            [format ["%1: the squad respawn vehicle has used all its credits", groupId _g]] call _toSquad;
        };
    };
};
