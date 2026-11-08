/*
    CQ_fnc_truckRun  (server, spawned by CQ_fnc_logiTick)
    [_hub, _target, _load] spawn CQ_fnc_truckRun;
    A HEMTT ammo truck leaves the main HQ with _load ammo points (already taken from the hub),
    drives to the target HQ's depot, unloads for 20 s, then drives back and returns what is
    left. Destroyed on the way = the load is lost. A prime target for players.
*/
params ["_hub", "_target", "_load", ["_fuelLoad", 0]];

private _tid = _target get "id";
private _hid = _hub get "id";
private _depot = _hub get "depot";
private _from = if (alive _depot) then { getPosATL _depot } else { _hub get "pos" };

private _p = [_from getPos [18, random 360], 6, 30] call CQ_fnc_clearPos;
if (_p isEqualTo []) then { _p = _from getPos [25, random 360] };
private _truck = createVehicle [CQ_truckClass, _p, [], 0, "NONE"];
_truck setAmmoCargo 0;                      // players can't use it to rearm
private _cg = [_truck] call CQ_fnc_crewVehicle;
_cg setBehaviour "SAFE";
_cg setSpeedMode "NORMAL";
[_truck, CQ_vehSpawnAmmo] call CQ_fnc_vehAmmoInit;

["Enemy supply truck dispatched", format ["A HEMTT leaves main HQ #%1 for HQ #%2 with %3 ammo and %4 fuel", _hid, _tid, round _load, round _fuelLoad]] call CQ_fnc_announce;

private _phase = "out";
private _t0 = time;
while { true } do {
    sleep 3;
    if (_phase == "home") exitWith {};
    if (!alive _truck || { !alive driver _truck }) exitWith { _phase = "lost" };

    if (_phase == "out") then {
        private _tDepot = _target get "depot";
        if (!((_target get "state") in CQ_activeStates) || { !alive _tDepot }) then {
            _phase = "back";
            _cg move _from;
        } else {
            if (_truck distance2D _tDepot < 60) then {
                sleep 20;
                if (alive _truck && { alive _tDepot }) then {
                    private _give = (_load min ((_target get "cap") - (_target get "stock"))) max 0;
                    _target set ["stock", (_target get "stock") + _give];
                    _load = _load - _give;
                    private _giveF = if (alive (_target get "tanker")) then { (_fuelLoad min ((_target get "cap") - (_target get "fuel"))) max 0 } else { 0 };
                    _target set ["fuel", (_target get "fuel") + _giveF];
                    _fuelLoad = _fuelLoad - _giveF;
                    ["Enemy supplies delivered", format ["HQ #%1 received %2 ammo and %3 fuel", _tid, round _give, round _giveF]] call CQ_fnc_announce;
                    ["truckSupply", [[_tid] call CQ_fnc_objName], _target] call CQ_fnc_say;
                };
                _phase = "back";
                _t0 = time;
                _cg move _from;
            } else {
                _cg move (getPosATL _tDepot);
                if (time - _t0 > 1200) then { _phase = "back"; _t0 = time; _cg move _from };
            };
        };
    } else {
        if (_truck distance2D _from < 80 || { time - _t0 > 900 }) then { _phase = "home" };   // loop ends next pass
    };
};

_target set ["truckInbound", false];
CQ_trucksActive = (CQ_trucksActive - 1) max 0;

if (_phase == "lost") then {
    ["Enemy supply truck destroyed", format ["The truck bound for HQ #%1 is lost with %2 ammo and %3 fuel", _tid, round _load, round _fuelLoad]] call CQ_fnc_announce;
} else {
    if ((_hub get "state") in CQ_activeStates) then {
        if (alive (_hub get "depot")) then { _hub set ["stock", ((_hub get "stock") + _load) min (_hub get "cap")] };
        if (alive (_hub get "tanker")) then { _hub set ["fuel", ((_hub get "fuel") + _fuelLoad) min (_hub get "cap")] };
    };
    { deleteVehicle _x } forEach crew _truck;
    deleteVehicle _truck;
};
