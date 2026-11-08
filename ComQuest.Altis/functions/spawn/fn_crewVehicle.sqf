/*
    CQ_fnc_crewVehicle  (server)
    [_vehicle] call CQ_fnc_crewVehicle  ->  group
    Seats a CSAT crew (driver + every turret) in any vehicle, whatever its faction.
    createVehicleCrew would put a NATO/AAF crew in a HEMTT, Mora or Nyx.
*/
params ["_veh"];

private _g = createGroup [east, true];
private _cls = ["O_Soldier_F", "O_crew_F"] select (_veh isKindOf "Tank" || { _veh isKindOf "Wheeled_APC_F" });
if (_veh isKindOf "Air") then { _cls = "O_helipilot_F" };

if ((_veh emptyPositions "driver") > 0) then {
    private _u = _g createUnit [_cls, getPosATL _veh, [], 5, "NONE"];
    _u moveInDriver _veh;
};
{
    private _u = _g createUnit [_cls, getPosATL _veh, [], 5, "NONE"];
    _u moveInTurret [_veh, _x];
} forEach (allTurrets [_veh, false]);

_g addVehicle _veh;
_g
