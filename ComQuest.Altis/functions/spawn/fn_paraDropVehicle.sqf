/*
    CQ_fnc_paraDropVehicle  (server, spawned)
    [_class, _lz, _onLanded, _tag] spawn CQ_fnc_paraDropVehicle;
    A Blackfish (CQ_dropPlaneClass) leaves the carrier with the vehicle in its cargo bay
    (Vehicle-in-Vehicle; hidden + own parachute if it does not fit), flies to _lz (pushed
    inland until CQ_dropCoastGap from water), paradrops it over safe ground and goes home.
    _onLanded is called with [vehicle] once it stands on the ground (not if it is lost).
*/
params ["_class", "_lz", ["_onLanded", {}], ["_tag", "Paradrop"]];

private _start = if (!isNil "CQ_carrierPos") then { CQ_carrierPos getPos [400, CQ_carrierPos getDir _lz] } else { _lz getPos [6000, 90] };
private _away = _start getDir _lz;
// Never spawn two planes on the same point (two drops at once collided and both blew up):
// each plane starts on its own free slot, 250 m apart sideways, 300 m apart in altitude bands
if (isNil "CQ_dropSlot") then { CQ_dropSlot = 0 };
CQ_dropSlot = (CQ_dropSlot + 1) % 4;
_start = _start getPos [250 * (CQ_dropSlot - 1.5), _away + 90];
private _alt = CQ_heightDrop + 40 * CQ_dropSlot;
for "_k" from 1 to 12 do {
    if ([_lz, CQ_dropCoastGap] call CQ_fnc_coastSafe) exitWith {};
    _lz = _lz getPos [100, _away];
};

private _pl = createVehicle [CQ_dropPlaneClass, [_start select 0, _start select 1, 1500 + 50 * CQ_dropSlot], [], 0, "FLY"];
_pl setPosASL [_start select 0, _start select 1, (getTerrainHeightASL _start max 0) + _alt];
_pl setDir _away;
_pl setVelocityModelSpace [0, 60, 0];
private _pg = [_pl] call CQ_fnc_crewVehicle;
_pg setBehaviourStrong "CARELESS";
_pg setCombatMode "BLUE";
_pl flyInHeight _alt;

private _cargo = objNull;
private _viv = false;
isNil {
    _cargo = createVehicle [_class, [500 * CQ_dropSlot, 0, 2000], [], 0, "CAN_COLLIDE"];
    _cargo allowDamage false;
    if (((_pl canVehicleCargo _cargo) param [0, false])) then { _viv = _pl setVehicleCargo _cargo };
    if (!_viv) then {
        _cargo hideObjectGlobal true;
        _cargo enableSimulationGlobal false;
        _cargo attachTo [_pl, [0, 0, -6]];
    };
};
_pl doMove _lz;
["%1: Blackfish with %2 airborne (%3)", [_tag, _class, ["own parachute", "cargo bay"] select _viv]] call CQ_fnc_log;

private _t0 = time;
private _minD = 1e9;
private _dropped = false;
waitUntil {
    sleep 1;
    if (!alive _pl) exitWith { true };
    private _d = _pl distance2D _lz;
    if (_d < 900) then { _pl limitSpeed 220 };
    if (_d < _minD) then { _minD = _d };
    private _safe = [getPosATL _pl, CQ_dropCoastGap] call CQ_fnc_coastSafe;
    if ((_d < CQ_dropLead && _safe) || { _d < 80 } || { _minD < CQ_dropLead && { _d > _minD + 40 } && _safe } || { time - _t0 > 500 && _safe }) then {
        if (_viv) then { _pl setVehicleCargo objNull } else {
            detach _cargo;
            _cargo hideObjectGlobal false;
            _cargo enableSimulationGlobal true;
            _cargo setPosASL ((getPosASL _pl) vectorAdd [0, 0, -12]);
            private _chute = createVehicle ["B_Parachute_02_F", [0, 0, 1000], [], 0, "FLY"];
            _chute setPosASL (getPosASL _cargo);
            _cargo attachTo [_chute, [0, 0, -1.5]];
            [_cargo, _chute] spawn {
                params ["_c", "_p"];
                waitUntil { sleep 0.5; isNull _p || { (getPosATL _c select 2) < 4 } };
                detach _c;
                if (!isNull _p) then { deleteVehicle _p };
            };
        };
        _dropped = true;
    };
    _dropped
};

// plane home
if (alive _pl) then {
    _pl limitSpeed 500;
    _pl flyInHeight 200;
    _pl doMove _start;
    [_pl, _pg, _start] spawn {
        params ["_pl", "_pg", "_home"];
        private _t = time;
        waitUntil { sleep 5; !alive _pl || { _pl distance2D _home < 700 } || { time - _t > 300 } };
        { deleteVehicle _x } forEach crew _pl;
        deleteVehicle _pl;
        deleteGroup _pg;
    };
};
if (!_dropped) exitWith {
    ["%1: Blackfish lost before the drop (alive %2, damage %3, at grid %4)", [_tag, alive _pl, damage _pl, mapGridPosition _pl]] call CQ_fnc_log;
    if (!_viv) then { deleteVehicle _cargo };
};

private _t = time;
waitUntil { sleep 1; !alive _cargo || { isTouchingGround _cargo && { speed _cargo < 3 } } || { time - _t > 120 } };
if (!alive _cargo) exitWith { ["%1: %2 lost on the way down", [_tag, _class]] call CQ_fnc_log };
_cargo allowDamage true;
["%1: %2 landed at grid %3", [_tag, _class, mapGridPosition _cargo]] call CQ_fnc_log;
[_cargo] call _onLanded;
