/*
    CQ_fnc_objName
    [_hqId] call CQ_fnc_objName  ->  "ROLLING THUNDER (root)" / "OVERLORD (P1)" / "KILLER (P2)"
    How messages, markers and the Operation tab name an enemy HQ: its codename (picked at random
    from CQ_hqNames when the HQ is created, never twice in a game) and its rank in the network:
    "root" for an HQ landed from the carrier, "P1" for a child of a root, "P2" for a grandchild...
*/
params ["_id"];
private _hqs = missionNamespace getVariable ["CQ_hqs", createHashMap];
private _hq = _hqs getOrDefault [_id, createHashMap];
private _n = _hq getOrDefault ["name", format ["HOSTILES %1", _id]];
private _depth = 0;
private _p = _hq getOrDefault ["parent", -1];
while { _p > -1 && { _depth < 20 } } do {
    _depth = _depth + 1;
    _p = (_hqs getOrDefault [_p, createHashMap]) getOrDefault ["parent", -1];
};
format ["%1 (%2)", _n, ["root", format ["P%1", _depth]] select (_depth > 0)]
