/*
    CQ_fnc_eventTechnical  (server)
    private _v = [_center] call CQ_fnc_eventTechnical;
    A crewed armed pickup (CQ_eventTechnical, DLC classes skipped) parked CQ_eventTechR m from a
    side event's objective, facing out, alert and holding: the driver stays put, the gunner covers.
    Returns the vehicle (objNull if none could be placed); its crew goes with it at cleanup.
*/
params ["_center"];
private _cls = CQ_eventTechnical;
if (!isClass (configFile >> "CfgVehicles" >> _cls) || { getText (configFile >> "CfgVehicles" >> _cls >> "DLC") != "" }) exitWith { objNull };
CQ_eventTechR params ["_r0", "_r1"];
private _a = random 360;
private _p = (_center getPos [_r0 + random (_r1 - _r0), _a]) findEmptyPosition [0, 40, _cls];
if (_p isEqualTo [] || { surfaceIsWater _p }) exitWith { ["Event technical: no room near %1", [mapGridPosition _center]] call CQ_fnc_log; objNull };
private _v = createVehicle [_cls, _p, [], 0, "NONE"];
_v setDir (_center getDir _p);
private _g = createVehicleCrew _v;
[units _g] call CQ_fnc_unitPrep;
_g setBehaviour "COMBAT"; _g setCombatMode "RED";
_g enableDynamicSimulation false;
(driver _v) disableAI "PATH";
_v setVariable ["CQ_eventTech", true, true];
_v
