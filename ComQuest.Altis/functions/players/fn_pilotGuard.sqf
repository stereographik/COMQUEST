/*
    CQ_fnc_pilotGuard  (client)
    [_unit, _vehicle] call CQ_fnc_pilotGuard;
    Called from GetInMan / SeatSwitchedMan. Moves a non-pilot out of an aircraft's
    pilot seat or co-pilot seat (turret [0]). Passenger seats stay open to everyone.
*/
params ["_unit", "_veh"];

if (!local _unit) exitWith {};
if !(_veh isKindOf "Air") exitWith {};
if (typeOf _unit in CQ_pilotClasses) exitWith {};

private _role = assignedVehicleRole _unit;
private _inControl = (_role isEqualTo ["Driver"])
    || { (_role param [0, ""]) == "Turret" && { (_role param [1, []]) isEqualTo [0] } };

if (_inControl) then {
    moveOut _unit;
    hint "Only pilots can fly aircraft. Take a passenger seat.";
};
