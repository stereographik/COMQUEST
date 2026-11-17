/*
    CQ_fnc_carryClient  (client, from CQ_fnc_carry "join")
    [_class, _loadout] remoteExec ["CQ_fnc_carryClient", _player];
    Last game's class and loadout back (already cleaned of loot on the server): kept through
    respawns like an arsenal loadout, class traits applied, pilots go back to Falcon.
*/
params ["_cls", "_lo"];
[_cls, _lo] spawn {
    params ["_cls", "_lo"];
    waitUntil { sleep 0.5; !isNull player && { alive player } };
    sleep 1;
    private _i = CQ_classes findIf { (_x select 0) == _cls };
    if (_i < 0) then { _cls = "Rifleman"; _i = CQ_classes findIf { (_x select 0) == "Rifleman" } };
    player setUnitLoadout _lo;
    CQ_savedLoadout = _lo;
    CQ_myClass = _cls;
    player setVariable ["CQ_class", _cls, true];
    if (_i > -1) then { [(CQ_classes select _i) select 2] call CQ_fnc_applyTraits };
    if (_cls == CQ_falconClass) then { ["falcon", player] remoteExec ["CQ_fnc_squadCmd", 2] };
    systemChat format ["Welcome back: your %1 kit from the last game", _cls];
};
