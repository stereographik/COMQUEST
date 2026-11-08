/*
    CQ_fnc_objName
    [_hqId] call CQ_fnc_objName  ->  "ALPHA", "BRAVO"... ("ALPHA-2" after ZULU)
*/
params ["_id"];
private _i = (_id - 1) max 0;
private _n = CQ_objNames select (_i mod count CQ_objNames);
if (_i >= count CQ_objNames) then { _n = format ["%1-%2", _n, floor (_i / count CQ_objNames) + 1] };
_n
