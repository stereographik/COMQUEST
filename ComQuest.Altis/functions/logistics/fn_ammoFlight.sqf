/*
    CQ_fnc_ammoFlight  (server, spawned by CQ_fnc_logiTick)
    [_hub] spawn CQ_fnc_ammoFlight;
    A Taru with an ammo pod, escorted by 2 Orcas + 1 Kajman, flies to the main HQ, lands on its
    delivery pad, unloads CQ_ammoFlightLoad ammo points (capped by the depot), waits 3 s, then
    joins the fleet parked at the main HQ (or leaves if the fleet is full).
*/
params ["_hub"];

private _hid = _hub get "id";
private _dest = _hub get "pos";
private _start = _dest getPos [CQ_insertionSpawnDistance, (_dest getDir CQ_basePos) + 180];
private _heading = _start getDir _dest;

([CQ_ammoFlightClass, [_start select 0, _start select 1, 0], _heading] call CQ_fnc_spawnHeli) params ["_heli", "_hg"];
private _escorts = [_start, _heading, _dest] call CQ_fnc_spawnEscorts;
private _pad = [_hub] call CQ_fnc_hqAirPad;
_heli doMove (getPosATL _pad);

["Enemy supply flight inbound", format ["A Taru with an ammo pod and 3 escorts is heading for main HQ #%1 (ammo + fuel)", _hid]] call CQ_fnc_announce;

private _delivered = false;
private _landing = false;
private _t0 = time;
while { true } do {
    sleep 2;
    if (!alive _heli || { !alive driver _heli }) exitWith {};
    if (time - _t0 > 900) exitWith { ["Ammo flight timed out", []] call CQ_fnc_log };
    if (!((_hub get "state") in CQ_activeStates)) exitWith { ["Ammo flight: main HQ #%1 fell, aborting", [_hid]] call CQ_fnc_log };

    if (_heli distance2D _pad > 400) then {
        _heli doMove (getPosATL _pad);
    } else {
        if (!_landing) then { _heli land "LAND"; _landing = true };
        if (isTouchingGround _heli) exitWith {
            sleep 20;
            if (alive _heli && { alive (_hub get "depot") }) then {
                private _give = (CQ_ammoFlightLoad min ((_hub get "cap") - (_hub get "stock"))) max 0;
                _hub set ["stock", (_hub get "stock") + _give];
                private _giveF = if (alive (_hub get "tanker")) then { (CQ_flightFuelLoad min ((_hub get "cap") - (_hub get "fuel"))) max 0 } else { 0 };
                _hub set ["fuel", (_hub get "fuel") + _giveF];
                _delivered = true;
                ["Enemy supplies delivered by air", format ["Main HQ #%1 received %2 ammo and %3 fuel (now %4 / %5, cap %6)",
                    _hid, round _give, round _giveF, round (_hub get "stock"), round (_hub get "fuel"), _hub get "cap"]] call CQ_fnc_announce;
            };
        };
    };
    if (_delivered) exitWith {};
};

if (!alive _heli) then {
    ["Enemy supply flight shot down", format ["The supply Taru for main HQ #%1 is down: %2 ammo and %3 fuel lost", _hid, CQ_ammoFlightLoad, CQ_flightFuelLoad]] call CQ_fnc_announce;
};

sleep 3;
// Everything still flying joins the fleet, or leaves when it is full
private _leave = {
    params ["_h", "_g"];
    [_g] call CQ_fnc_clearWaypoints;
    _h doMove _start;
    [_h, _g, _start] spawn {
        params ["_h", "_g", "_s"];
        private _t = time;
        waitUntil { sleep 5; !alive _h || { _h distance2D _s < 800 } || { time - _t > 300 } };
        { deleteVehicle _x } forEach crew _h;
        deleteVehicle _h;
    };
};
if (alive _heli) then {
    _heli engineOn true;
    if !([_heli, _hg, "transport", -1, objNull, _dest] call CQ_fnc_airRegister) then { [_heli, _hg] call _leave };
};
{
    _x params ["_h", "_g"];
    if (alive _h) then {
        if !([_h, _g, "armed", -1, objNull, _dest] call CQ_fnc_airRegister) then { [_h, _g] call _leave };
    };
} forEach _escorts;

CQ_ammoFlightActive = false;
