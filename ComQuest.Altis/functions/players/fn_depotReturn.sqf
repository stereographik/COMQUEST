/*
    CQ_fnc_depotReturn  (server, from the "Return vehicle" action through remoteExec)
    [_player, _vehicle] call CQ_fnc_depotReturn;
    A depot vehicle brought back next to a depot (CQ_depotReturnRange from the depot or its
    pad), stopped, with nobody else aboard, is put back in the stock at once.
*/
params ["_p", "_v"];
if (!isServer || { isNull _p } || { !alive _v } || { !(_v in CQ_depotVehs) }) exitWith {};
private _say = { params ["_t"]; [_t] remoteExec ["hint", _p] };
if ((CQ_depots findIf { _v distance2D (_x select 0) < CQ_depotReturnRange || { _v distance2D (_x select 1) < CQ_depotReturnRange } }) < 0) exitWith { ["Bring the vehicle next to a vehicle depot"] call _say };
if (speed _v > 3) exitWith { ["Stop the vehicle first"] call _say };
if (((crew _v) findIf { alive _x && { _x != _p } }) > -1) exitWith { ["Everybody else must get out first"] call _say };
[_p, _v] spawn {
    params ["_p", "_v"];
    if (vehicle _p == _v) then { [_p] remoteExec ["moveOut", _p]; sleep 1 };
    private _name = getText (configOf _v >> "displayName");
    CQ_depotVehs = CQ_depotVehs - [_v];
    publicVariable "CQ_depotVehs";
    deleteVehicle _v;
    [format ["%1 returned to the depot, back in stock", _name]] remoteExec ["hint", _p];
    ["Depot: %1 returned a %2", [name _p, _name]] call CQ_fnc_log;
};
