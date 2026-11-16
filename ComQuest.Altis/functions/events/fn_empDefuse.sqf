/*
    CQ_fnc_empDefuse  (server, from the device's hold action, or the debug panel)
    [_player] remoteExec ["CQ_fnc_empDefuse", 2];
    The device is ours: CQ_empPtsDefuse points to the defuser and CQ_empPtsSquad to each member of
    his squad; the terminal prop on the table becomes a real UAV terminal anyone can take (a
    targeting token, CQ_fnc_empClient: it connects to nothing; "Program EMP target" while carried);
    the guards left go CQ_eventCleanup s later; the Stomper comes for the device (CQ_fnc_empStomper).
*/
params [["_p", objNull]];
if (!isServer || { isNil "CQ_empState" } || { CQ_empPhase != "armed" }) exitWith {};
private _s = CQ_empState;
CQ_empPhase = "defused"; publicVariable "CQ_empPhase";
private _who = if (isNull _p) then { "Command" } else { name _p };
if (!isNull _p) then {
    [_p, CQ_empPtsDefuse, "EMP defused"] call CQ_fnc_scoreAdd;
    { if (_x != _p && { isPlayer _x }) then { [_x, CQ_empPtsSquad, "EMP defused (squad)"] call CQ_fnc_scoreAdd } } forEach units group _p;
};
// the terminal: prop out, a real one on the table
private _table = _s get "table";
private _prop = _s get "prop";
private _tp = if (isNull _prop) then { (getPosATL _table) vectorAdd [0, 0, 0.8] } else { ASLToATL getPosASL _prop };
if (!isNull _prop) then { deleteVehicle _prop };
private _h = createVehicle ["GroundWeaponHolder", [0, 0, 0], [], 0, "CAN_COLLIDE"];
_h addItemCargoGlobal ["B_UavTerminal", 1];
_h setPosATL _tp;
_s set ["holder", _h];
CQ_empCaptured = true; publicVariable "CQ_empCaptured";
{ deleteMarker _x } forEach ["cq_emp", "cq_emp_t"];
// the guards and the pickup left go later (the device and the table stay for the Stomper)
["EMP event", _s get "men"] call CQ_fnc_eventCleanup;
["EMP event: device defused by %1 (%2 s left), terminal on the table, Stomper on its way", [_who, round ((_s get "endT") - time)]] call CQ_fnc_log;
["EMP defused", format ["%1 defused the EMP. Take the terminal on the table to program its target.", _who]] call CQ_fnc_announce;
["empDefused", [_who]] call CQ_fnc_say;
if (!isNil "CQ_empKey") then { [CQ_empKey, 1, "EMP device", "defused, waiting for the Stomper", _p] call CQ_fnc_opSide };
[] spawn CQ_fnc_empStomper;
