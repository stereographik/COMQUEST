/*
    CQ_fnc_squadCmd  (server, from the squad manager through remoteExec)
    ["join", _player, _group] / ["ungroup", _player] / ["disband", _player]
    / ["unassign", _player] / ["create", _player]
      join      the player joins that (friendly) squad
      ungroup   the player leaves his squad and becomes unassigned
      disband   squad leader only: every other member becomes unassigned
      unassign  on connection: every player starts unassigned (no lobby squad)
      create    an unassigned player founds a new squad (first free name) and leads it
*/
params ["_cmd", "_p", ["_g", grpNull]];
if (!isServer || { isNull _p }) exitWith {};
private _solo = {
    params ["_u"];
    private _ng = createGroup [west, true];
    [_u] joinSilent _ng;
    _ng setGroupIdGlobal [format ["Unassigned %1 %2", name _u, floor random 1000]];
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
    case "unassign": {
        private _old = group _p;
        [_p] call _solo;
        if (count units _old == 0) then { deleteGroup _old };
    };
    case "create": {
        private _g = group _p;
        if !(_g getVariable ["CQ_solo", false]) exitWith {};
        private _used = (allGroups select { side _x == west }) apply { groupId _x };
        private _name = CQ_squadNames param [CQ_squadNames findIf { !(_x in _used) }, format ["Squad %1", floor random 100]];
        _g setGroupIdGlobal [_name];
        _g setVariable ["CQ_solo", false, true];
        ["Squads: %1 created squad %2", [name _p, _name]] call CQ_fnc_log;
    };
    case "disband": {
        private _grp = group _p;
        if (leader _grp != _p) exitWith {};
        { if (_x != _p) then { [_x] call _solo } } forEach units _grp;
        ["Squads: %1 disbanded %2", [name _p, groupId _grp]] call CQ_fnc_log;
    };
};
