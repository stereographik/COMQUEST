/*
    CQ_fnc_pilotGuard  (client)
    [_unit, _vehicle] call CQ_fnc_pilotGuard;
    Called from GetInMan / SeatSwitchedMan. Aircraft controls are for Falcon pilots only (class
    CQ_falconClass, or a unit of CQ_pilotClasses): anyone else in the pilot seat or the co-pilot
    seat (turret [0], it can take the controls) is moved out. Passenger seats stay open to everyone.
*/
params ["_unit", "_veh"];

if (!local _unit) exitWith {};
if !(_veh isKindOf "Air") exitWith {};
if ((_unit getVariable ["CQ_class", ""]) == CQ_falconClass || { typeOf _unit in CQ_pilotClasses }) exitWith {};

[_unit, _veh] spawn {
    params ["_unit", "_veh"];
    sleep 0.2;                                       // the seat is taken a moment after the event
    if (vehicle _unit != _veh) exitWith {};
    if (driver _veh == _unit || { (_veh unitTurret _unit) isEqualTo [0] }) then {
        moveOut _unit;
        hint "Aircraft controls are for Falcon pilots only. Take a passenger seat.";
    };
};
