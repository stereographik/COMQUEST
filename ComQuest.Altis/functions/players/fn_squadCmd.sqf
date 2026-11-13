/*
    CQ_fnc_squadCmd  (server, from the squad manager through remoteExec)
    ["join", _player, _group] / ["ungroup", _player] / ["disband", _player]
    / ["falcon", _player] / ["unfalcon", _player]   (pilot class taken / dropped: CQ_fnc_setClass)
    / ["unassign", _player] / ["create", _player]
      join      the player joins that (friendly) squad
      ungroup   the player leaves his squad and becomes unassigned
      disband   squad leader only: every member, leader included, becomes unassigned
      (ungroup / disband also work when the player is alone in his squad)
      unassign  on connection: every player starts unassigned (no lobby squad)
      create    an unassigned player founds a new squad (first free name) and leads it
    ["invite", _leader, _target]   squad leader invites an unassigned player: the target gets
                                   an accept / decline window (CQ_fnc_squadInvite)
    ["inviteReply", _target, _leader, _accepted]   answer; accepted -> the target joins
*/
params ["_cmd", "_p", ["_g", grpNull], ["_extra", false]];
if (!isServer || { isNull _p }) exitWith {};
// FALCON: pilots live in the one squad "Falcon"; nobody else joins it, they don't leave it
private _isPilot = (_p getVariable ["CQ_class", ""]) == CQ_falconClass;
private _inFalcon = (group _p) getVariable ["CQ_falcon", false];
if (_cmd in ["join", "ungroup", "create", "disband", "invite", "inviteReply"] && { _inFalcon || { _isPilot } }) exitWith {
    ["Pilots fly for every squad from Falcon: change class to leave it"] remoteExec ["hint", _p];
};
if (_cmd == "join" && { _g getVariable ["CQ_falcon", false] }) exitWith { ["Falcon is for pilots only"] remoteExec ["hint", _p] };
private _solo = {
    params ["_u"];
    private _ng = createGroup [west, true];
    [_u] joinSilent _ng;
    _ng setGroupIdGlobal [format ["Unassigned %1 %2", name _u, floor random 1000]];
    _ng setVariable ["CQ_solo", true, true];
};
private _toSolo = {
    params ["_grp"];
    private _u = leader _grp;
    _grp setGroupIdGlobal [format ["Unassigned %1 %2", name _u, floor random 1000]];
    _grp setVariable ["CQ_solo", true, true];
    _grp setVariable ["CQ_sqPts", 0, true];          // squad points are lost when the squad ends
};
switch (_cmd) do {
    // the player became a pilot: into Falcon (created when needed)
    case "falcon": {
        if (_inFalcon) exitWith {};
        private _fg = (allGroups select { side _x == west && { _x getVariable ["CQ_falcon", false] } && { units _x isNotEqualTo [] } }) param [0, grpNull];
        private _old = group _p;
        if (isNull _fg) then {
            _fg = createGroup [west, true];
            _fg setGroupIdGlobal [CQ_falconName];
            _fg setVariable ["CQ_falcon", true, true];
            _fg setVariable ["CQ_solo", false, true];
            _fg setVariable ["CQ_sqPts", 0, true];
            _fg setVariable ["CQ_sqBought", [], true];
        };
        [_p] joinSilent _fg;
        if (count units _old == 0) then { deleteGroup _old } else {
            if (leader _old == _p) then { _old selectLeader ((units _old) select 0) };
        };
        [format ["You fly for every squad now: you are in %1", CQ_falconName]] remoteExec ["hint", _p];
        ["Squads: %1 is a pilot, joined %2", [name _p, CQ_falconName]] call CQ_fnc_log;
    };
    // the player is no pilot any more: out of Falcon, unassigned
    case "unfalcon": {
        if (!_inFalcon) exitWith {};
        [_p] call _solo;
        ["Squads: %1 left %2 (no longer a pilot)", [name _p, CQ_falconName]] call CQ_fnc_log;
    };
    case "join": {
        if (isNull _g || { side _g != west } || { group _p isEqualTo _g }) exitWith {};
        private _old = group _p;
        [_p] joinSilent _g;
        if (count units _old == 0) then { deleteGroup _old };
        ["Squads: %1 joined %2", [name _p, groupId _g]] call CQ_fnc_log;
    };
    case "ungroup": {
        private _old = group _p;
        if (_old getVariable ["CQ_solo", false]) exitWith {};
        private _name = groupId _old;
        if (count units _old <= 1) then {
            // alone in his squad: the squad itself goes back to "unassigned"
            [_old] call _toSolo;
        } else {
            [_p] call _solo;
        };
        ["Squads: %1 left %2", [name _p, _name]] call CQ_fnc_log;
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
        _g setVariable ["CQ_sqPts", 0, true];
        _g setVariable ["CQ_sqBought", [], true];
        ["Squads: %1 created squad %2", [name _p, _name]] call CQ_fnc_log;
    };
    case "invite": {
        private _t = _g;                                   // target player
        if (isNull _t || { !isPlayer _t } || { _t == _p }) exitWith {};
        private _grp = group _p;
        if (_grp getVariable ["CQ_solo", false] || { leader _grp != _p }) exitWith {};
        if !((group _t) getVariable ["CQ_solo", false]) exitWith {
            [format ["%1 is already in a squad", name _t]] remoteExec ["hint", _p];
        };
        if (time < (_t getVariable ["CQ_inviteUntil", -1])) exitWith {
            [format ["%1 already has an invite pending", name _t]] remoteExec ["hint", _p];
        };
        _t setVariable ["CQ_inviteUntil", time + CQ_inviteTimeout];
        _t setVariable ["CQ_inviteGroup", _grp];
        [name _p, groupId _grp, _p] remoteExec ["CQ_fnc_squadInvite", _t];
        [format ["Invite sent to %1", name _t]] remoteExec ["hint", _p];
        ["Squads: %1 invited %2 to %3", [name _p, name _t, groupId _grp]] call CQ_fnc_log;
    };
    case "inviteReply": {
        private _leader = _g;
        private _grp = _p getVariable ["CQ_inviteGroup", grpNull];
        private _valid = time < (_p getVariable ["CQ_inviteUntil", -1]);
        _p setVariable ["CQ_inviteUntil", -1];
        _p setVariable ["CQ_inviteGroup", grpNull];
        if (!_extra || { !_valid } || { isNull _grp } || { units _grp isEqualTo [] } || { _grp getVariable ["CQ_solo", false] }) exitWith {
            if (!isNull _leader) then {
                [format ["%1 %2 your invite", name _p, ["declined", "could not accept"] select _extra]] remoteExec ["hint", _leader];
            };
            ["Squads: %1 declined the invite", [name _p]] call CQ_fnc_log;
        };
        private _old = group _p;
        [_p] joinSilent _grp;
        if (count units _old == 0) then { deleteGroup _old };
        if (!isNull _leader) then { [format ["%1 joined your squad", name _p]] remoteExec ["hint", _leader] };
        ["Squads: %1 accepted the invite and joined %2", [name _p, groupId _grp]] call CQ_fnc_log;
    };
    case "disband": {
        private _grp = group _p;
        if (leader _grp != _p || { _grp getVariable ["CQ_solo", false] }) exitWith {};
        private _name = groupId _grp;
        { if (_x != _p) then { [_x] call _solo } } forEach units _grp;
        // the leader is unassigned too: his group becomes a solo group again, the name is freed
        [_grp] call _toSolo;
        ["Squads: %1 disbanded %2", [name _p, _name]] call CQ_fnc_log;
    };
};
