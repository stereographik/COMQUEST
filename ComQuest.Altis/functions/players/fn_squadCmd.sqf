/*
    CQ_fnc_squadCmd  (server, from the squad manager through remoteExec)
    ["join", _player, _group] / ["ungroup", _player] / ["disband", _player]
      join     the player joins that (friendly) squad
      ungroup  the player leaves his squad and stands alone ("Solo <name>")
      disband  squad leader only: every other member is put on his own
*/
params ["_cmd", "_p", ["_g", grpNull]];
if (!isServer || { isNull _p }) exitWith {};
private _solo = {
    params ["_u"];
    private _ng = createGroup [west, true];
    [_u] joinSilent _ng;
    _ng setGroupIdGlobal [format ["Solo %1 %2", name _u, floor random 1000]];
    _ng setVariable ["CQ_solo", true, true];
};
switch (_cmd) do {
    case "join": {
        if (isNull _g || { side _g != west } || { group _p isEqualTo _g }) exitWith {};
        private _old = group _p;
        [_p] joinSilent _g;
        if (count units _old == 0) then { deleteGroup _old };
        ["Squads: %1 joined %2", [name _p, groupId _g]] call CQ_fnc_log;
    };
    case "ungroup": {
        if (count units group _p <= 1) exitWith {};
        [_p] call _solo;
        ["Squads: %1 left his squad", [name _p]] call CQ_fnc_log;
    };
    case "disband": {
        private _grp = group _p;
        if (leader _grp != _p) exitWith {};
        { if (_x != _p) then { [_x] call _solo } } forEach units _grp;
        ["Squads: %1 disbanded %2", [name _p, groupId _grp]] call CQ_fnc_log;
    };
};
