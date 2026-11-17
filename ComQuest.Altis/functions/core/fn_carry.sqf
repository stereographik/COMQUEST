/*
    CQ_fnc_carry  (server)   friendlies keep their stuff from one game to the next
      ["save"] call CQ_fnc_carry;        end of the game (CQ_fnc_endgame), just before the restart:
                                         saved on the server (profileNamespace "CQ_carry_v1")
                                           players  uid -> [class, loadout cleaned of loot]
                                           squads   [[name, leader uid, [member uids], points,
                                                      points refunded for bought vehicles], ...]
      ["load"] call CQ_fnc_carry;        server start: taken (once) when saved less than
                                         CQ_carryMaxAge min ago (real time), then wiped
      ["join", _player] call CQ_fnc_carry;   a player connects (after "unassign"): his class and
                                         loadout back, his squad re-created (same name, its points,
                                         bought vehicles refunded as points) or joined, the old
                                         leader gets command back
    Loot: the loadout keeps only what the player's class may take at the arsenal
    (CQ_arsenalGates: other classes' role gear, every UAV terminal...).
*/
params ["_mode", ["_p", objNull]];
if (!isServer) exitWith {};
private _minutes = { params ["_st"]; _st params ["_y", "_mo", "_d", "_h", "_mi"]; ((((_y * 12 + _mo) * 31 + _d) * 24 + _h) * 60 + _mi) };

switch (_mode) do {
    case "save": {
        // is this item barred from this class? (the arsenal's rule, CQ_fnc_arsenalOpen)
        private _barred = {
            params ["_n", "_cls"];
            if (_n == "") exitWith { false };
            private _ln = toLower _n;
            private _t = _n call BIS_fnc_itemType;
            private _tags = [_t select 0, _t select 1];
            private _c = configFile >> "CfgWeapons" >> _n;
            if (isClass _c && { (getArray (_c >> "muzzles")) findIf { !(_x in ["this", "SAFE"]) } > -1 } && { (_t select 1) in ["AssaultRifle", "Rifle"] }) then { _tags pushBack "GL" };
            (CQ_arsenalGates findIf {
                _x params ["_g", "_allowed"];
                !(_cls in _allowed) && { (_g findIf { if ((_x select [0, 1]) == "@") then { (_ln find toLower (_x select [1])) > -1 } else { _x in _tags } }) > -1 }
            }) > -1
        };
        private _clean = {
            params ["_lo", "_cls"];
            // weapons: primary, launcher, handgun, binocular
            { if ((_lo select _x) isNotEqualTo [] && { [(_lo select _x) select 0, _cls] call _barred }) then { _lo set [_x, []] } } forEach [0, 1, 2, 8];
            // uniform, vest, backpack: the container itself, then what is inside
            {
                private _ct = _lo select _x;
                if (_ct isNotEqualTo []) then {
                    if ([_ct select 0, _cls] call _barred) then { _lo set [_x, []] } else {
                        _ct set [1, (_ct select 1) select {
                            private _it = _x select 0;      // an item / magazine class, or a weapon array
                            if (_it isEqualType []) then { !([_it select 0, _cls] call _barred) } else { !([_it, _cls] call _barred) }
                        }];
                    };
                };
            } forEach [3, 4, 5];
            if ([_lo select 6, _cls] call _barred) then { _lo set [6, ""] };
            // map, terminal, radio, compass, watch, NVG
            private _li = _lo select 9;
            { if ([_x, _cls] call _barred) then { _li set [_forEachIndex, ""] } } forEach _li;
            _lo
        };
        private _pl = createHashMap;
        {
            if (side group _x == west) then {
                private _cls = _x getVariable ["CQ_class", "Rifleman"];
                _pl set [getPlayerUID _x, [_cls, [+(getUnitLoadout _x), _cls] call _clean]];
            };
        } forEach allPlayers;
        private _sq = [];
        {
            private _g = _x;
            private _m = (units _g) select { isPlayer _x };
            if (side _g == west && { !(_g getVariable ["CQ_solo", true]) } && { !(_g getVariable ["CQ_falcon", false]) } && { _m isNotEqualTo [] }) then {
                // bought vehicles alive when the game ended are refunded (counted then by CQ_fnc_endClear,
                // so a crash during the debrief costs nothing): their shop price goes back to the points
                private _ref = _g getVariable ["CQ_endRefund", 0];
                _sq pushBack [groupId _g, getPlayerUID (leader _g), _m apply { getPlayerUID _x }, (_g getVariable ["CQ_sqPts", 0]) + _ref, _ref];
            };
        } forEach allGroups;
        private _res = (missionNamespace getVariable ["CQ_endPub", ["", "", 0]]) select [0, 3];
        // (a plain array: a hashmap is not kept in the profile)
        profileNamespace setVariable ["CQ_carry_v1", [[systemTimeUTC] call _minutes, (keys _pl) apply { [_x, _pl get _x] }, _sq, _res, (missionNamespace getVariable ["CQ_gameNo", 1]) + 1]];
        saveProfileNamespace;
        ["CARRY: saved %1 player(s) and %2 squad(s) for the next game", [count _pl, count _sq]] call CQ_fnc_log;
    };
    case "load": {
        private _c = profileNamespace getVariable ["CQ_carry_v1", []];
        profileNamespace setVariable ["CQ_carry_v1", nil];
        saveProfileNamespace;
        if (_c isEqualTo []) exitWith {};
        _c params ["_t", "_pl", "_sq", ["_last", ["", "", 0]], ["_no", 1]];
        private _age = ([systemTimeUTC] call _minutes) - _t;
        if (_age < 0 || { _age > CQ_carryMaxAge }) exitWith { ["CARRY: last game's save is %1 min old, not used", [_age]] call CQ_fnc_log };
        _pl = createHashMapFromArray _pl;
        CQ_carryPl = _pl; CQ_carrySq = _sq;
        CQ_gameNo = _no;
        // returning players: no intro, no rules again (already accepted), a short NEXT GAME card
        // instead (CQ_fnc_intro); CQ_carryLast = [result, why, duration s, game number]
        if (isNil "CQ_rulesUids") then { CQ_rulesUids = [] };
        { CQ_rulesUids pushBackUnique _x } forEach (keys _pl);
        CQ_carryUids = keys _pl; publicVariable "CQ_carryUids";
        CQ_carryLast = _last + [_no]; publicVariable "CQ_carryLast";
        ["CARRY: %1 player(s) and %2 squad(s) carried over from the last game (%3 min ago)", [count _pl, count _sq, _age]] call CQ_fnc_log;
    };
    case "join": {
        if (isNull _p || { isNil "CQ_carryPl" }) exitWith {};
        private _uid = getPlayerUID _p;
        private _rec = CQ_carryPl getOrDefault [_uid, []];
        if (_rec isEqualTo []) exitWith {};
        CQ_carryPl deleteAt _uid;
        _rec params ["_cls", "_lo"];
        [_cls, _lo] remoteExec ["CQ_fnc_carryClient", _p];
        // his squad
        private _si = CQ_carrySq findIf { _uid in (_x select 2) };
        if (_si < 0 || { _cls == CQ_falconClass }) exitWith {};
        (CQ_carrySq select _si) params ["_name", "_lead", "_mem", "_pts", ["_ref", 0]];
        if !(_ref isEqualType 0) then { _ref = 0 };   // an older save kept vehicle classes here
        private _g = (allGroups select { side _x == west && { !(_x getVariable ["CQ_solo", true]) } && { (_x getVariable ["CQ_carryName", ""]) == _name } }) param [0, grpNull];
        if (isNull _g) then {
            // first one back: his own (unassigned) group becomes the squad, with its points and vehicles
            _g = group _p;
            // its name taken meanwhile by a new squad (after CQ_carryHold): the first free one instead
            if (((allGroups select { side _x == west && { _x != _g } }) apply { groupId _x }) find _name > -1) then {
                private _used = (allGroups select { side _x == west }) apply { groupId _x };
                _name = CQ_squadNames param [CQ_squadNames findIf { !(_x in _used) }, format ["Squad %1", floor random 100]];
            };
            _g setGroupIdGlobal [_name];
            _g setVariable ["CQ_solo", false, true];
            _g setVariable ["CQ_carryName", (CQ_carrySq select _si) select 0, true];   // teammates find it by its old name
            _g setVariable ["CQ_sqPts", _pts, true];
            _g setVariable ["CQ_sqBought", [], true];
            if (_ref > 0) then {
                [format ["Squad %1: your vehicle from the last game is refunded (+%2 points, %3 in all)", _name, _ref, _pts]] remoteExec ["systemChat", _p];
            };
            ["CARRY: %1 re-created squad %2 (%3 points, %4 refunded for vehicles)", [name _p, _name, _pts, _ref]] call CQ_fnc_log;
        } else {
            private _old = group _p;
            [_p] joinSilent _g;
            if (count units _old == 0) then { deleteGroup _old };
            ["CARRY: %1 back in squad %2", [name _p, _name]] call CQ_fnc_log;
        };
        if (_uid == _lead) then { [_g, _p] remoteExec ["selectLeader", groupOwner _g] };
        [format ["Welcome back: you are in %1 again (%2 points)", _name, _g getVariable ["CQ_sqPts", 0]]] remoteExec ["hint", _p];
    };
};
