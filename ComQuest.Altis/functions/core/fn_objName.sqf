/*
    CQ_fnc_objName
    [_hqId] call CQ_fnc_objName  ->  "ROLLING THUNDER (HQ#3)"
    How messages, markers and the Operation tab name an enemy HQ: its codename (CQ_hqNames,
    given in order when the HQ is created) and its number. Player squads use Alpha / Bravo.
*/
params ["_id"];
private _hq = (missionNamespace getVariable ["CQ_hqs", createHashMap]) getOrDefault [_id, createHashMap];
private _n = _hq getOrDefault ["name", ""];
if (_n == "") then { format ["HOSTILES (HQ#%1)", _id] } else { format ["%1 (HQ#%2)", _n, _id] }
