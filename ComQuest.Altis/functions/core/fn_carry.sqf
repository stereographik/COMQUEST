/*
    CQ_fnc_carry  (server)   friendlies keep their stuff from one game to the next
      ["save"] call CQ_fnc_carry;        end of the game (CQ_fnc_endgame), just before the restart:
                                         saved on the server (profileNamespace "CQ_carry_v1")
                                           players  uid -> [class, loadout cleaned of loot]
                                           squads   [[name, leader uid, [member uids], points,
                                                      [bought vehicle classes]], ...]
      ["load"] call CQ_fnc_carry;        server start: taken (once) when saved less than
                                         CQ_carryMaxAge min ago (real time), then wiped
      ["join", _player] call CQ_fnc_carry;   a player connects (after "unassign"): his class and
                                         loadout back, his squad re-created (same name, its points,
                                         its bought vehicles on the shop pad) or joined, the old
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
                private _vs = ((_g getVariable ["CQ_sqBought", []]) select { alive _x }) apply { typeOf _x };
                _sq pushBack [groupId _g, getPlayerUID (leader _g), _m apply { getPlayerUID _x }, _g getVariable ["CQ_sqPts", 0], _vs];
            };
        } forEach allGroups;
        profileNamespace setVariable ["CQ_carry_v1", [[systemTimeUTC] call _minutes, _pl, _sq]];
        saveProfileNamespace;
        ["CARRY: saved %1 player(s) and %2 squad(s) for the next game", [count _pl, count _sq]] call CQ_fnc_log;
    };
    case "load": {
        private _c = profileNamespace getVariable ["CQ_carry_v1", []];
        profileNamespace setVariable ["CQ_carry_v1", nil];
        saveProfileNamespace;
        if (_c isEqualTo []) exitWith {};
        _c params ["_t", "_pl", "_sq"];
        private _age = ([systemTimeUTC] call _minutes) - _t;
        if (_age < 0 || { _age > CQ_carryMaxAge }) exitWith { ["CARRY: last game's save is %1 min old, not used", [_age]] call CQ_fnc_log };
        CQ_carryPl = _pl; CQ_carrySq = _sq;
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
        (CQ_carrySq select _si) params ["_name", "_lead", "_mem", "_pts", "_vs"];
        private _g = (allGroups select { side _x == west && { !(_x getVariable ["CQ_solo", true]) } && { (_x getVariable ["CQ_carryName", ""]) == _name } }) param [0, grpNull];
        if (isNull _g) then {
            // first one back: his own (unassigned) group becomes the squad, with its points and vehicles
            _g = group _p;
            _g setGroupIdGlobal [_name];
            _g setVariable ["CQ_solo", false, true];
            _g setVariable ["CQ_carryName", _name, true];
            _g setVariable ["CQ_sqPts", _pts, true];
            _g setVariable ["CQ_sqBought", [], true];
            [_g, _vs] spawn {
                params ["_g", "_vs"];
                {
                    private _cls = _x;
                    waitUntil { sleep 2; ((nearestObjects [CQ_shopLZ, ["LandVehicle", "Air"], 9]) select { alive _x }) isEqualTo [] };
                    if (isNull _g) exitWith {};
                    private _v = createVehicle [_cls, CQ_shopLZ, [], 0, "NONE"];
                    _v setDir CQ_shopDir;
                    _v allowDamage false;
                    [_v] spawn { params ["_v"]; sleep 8; if (alive _v) then { _v allowDamage true } };
                    clearWeaponCargoGlobal _v; clearMagazineCargoGlobal _v; clearItemCargoGlobal _v; clearBackpackCargoGlobal _v;
                    _v addItemCargoGlobal ["FirstAidKit", 4];
                    _v setVariable ["CQ_boughtBy", groupId _g, true];
                    if !(_v isKindOf "Air") then { _v setVariable ["CQ_squadGroup", _g, true] };
                    _g setVariable ["CQ_sqBought", (_g getVariable ["CQ_sqBought", []]) + [_v], true];
                    [format ["Your squad's %1 is back on the shop pad", getText (configOf _v >> "displayName")]] remoteExec ["systemChat", (units _g) select { isPlayer _x }];
                } forEach _vs;
            };
            ["CARRY: %1 re-created squad %2 (%3 points, %4 vehicle(s))", [name _p, _name, _pts, count _vs]] call CQ_fnc_log;
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
