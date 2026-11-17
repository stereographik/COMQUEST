/*
    CQ_fnc_aiSquads  (server, debug panel)
    ["spawn"] call CQ_fnc_aiSquads;    CQ_aiSqCount friendly AI squads (TASK FORCE 1..n), each
                                       8 men + an Ifrit HMG + a Strider HMG, outside the base
    ["delete"] call CQ_fnc_aiSquads;   removes them and their vehicles
    Spawn: a ring CQ_aiSqRing m around the base (outside the safe zone), centred on the
    direction of the nearest enemy HQ, squads at least CQ_aiSqGap m apart, on a road when one is
    close, on clear flat ground.
    Brain (every 20 s per squad): the nearest enemy RADIO TOWER still standing first, then the
    nearest other objective (command building, depot, fuel tanker, AA pits, HMG tower) -> rushes
    there at full speed without stopping to fight (AUTOCOMBAT off), then search & destroy; once the squad leader is within CQ_aiSqBlowR m of it, its engineer (or anyone) plants
    a charge: the objective blows up CQ_aiSqFuse s later. No objective left: hunt the nearest
    enemy group. Sharp skills, never flee.
*/
params ["_mode"];
if (!isServer) exitWith {};
if (isNil "CQ_aiSqGroups") then { CQ_aiSqGroups = [] };

switch (_mode) do {
    case "delete": {
        private _n = 0;
        {
            private _g = _x;
            { deleteVehicle _x } forEach (_g getVariable ["CQ_aiSqVehs", []]);
            { _n = _n + 1; deleteVehicle _x } forEach units _g;
            deleteGroup _g;
        } forEach CQ_aiSqGroups;
        CQ_aiSqGroups = [];
        ["AI task force: deleted (%1 men)", [_n]] call CQ_fnc_log;
        _n
    };

    case "spawn": {
        private _active = (values CQ_hqs) select { (_x get "state") in CQ_activeStates };
        private _dir = if (_active isEqualTo []) then { random 360 } else {
            CQ_basePos getDir ((([_active, [], { (_x get "pos") distance2D CQ_basePos }, "ASCEND"] call BIS_fnc_sortBy) select 0) get "pos")
        };
        // spawn spots: on the ring, toward the enemy, spread over +/- 60 degrees, CQ_aiSqGap apart
        private _spots = [];
        for "_try" from 0 to 80 do {
            if (count _spots >= CQ_aiSqCount) exitWith {};
            private _a = _dir + (random 120) - 60;
            private _p = CQ_basePos getPos [(CQ_aiSqRing select 0) + random ((CQ_aiSqRing select 1) - (CQ_aiSqRing select 0)), _a];
            if (surfaceIsWater _p) then { continue };
            private _rd = [_p, 150] call BIS_fnc_nearestRoad;
            if (!isNull _rd) then { _p = getPosATL _rd };
            _p = [_p, 12, 60] call CQ_fnc_clearPos;
            if (_p isEqualTo [] || { surfaceIsWater _p }) then { continue };
            if ((_spots findIf { _x distance2D _p < CQ_aiSqGap }) > -1) then { continue };
            _spots pushBack _p;
        };
        {
            private _p = _x;
            private _k = count CQ_aiSqGroups + 1;
            private _g = createGroup [west, true];
            _g setGroupIdGlobal [format ["TASK FORCE %1", _k]];
            _g setVariable ["CQ_aiSquad", true, true];
            {
                private _u = _g createUnit [_x, _p getPos [5 + random 5, random 360], [], 0, "NONE"];
                _u setSkill 0.85;
                { _u setSkill [_x select 0, _x select 1] } forEach [["aimingAccuracy", 0.55], ["aimingShake", 0.7], ["spotDistance", 0.9], ["spotTime", 0.85], ["courage", 1], ["commanding", 1], ["general", 0.9]];
                _u allowFleeing 0;
                _u addItemToBackpack "FirstAidKit"; _u addItemToBackpack "FirstAidKit";
            } forEach CQ_aiSqUnits;
            _g setBehaviour "AWARE";
            _g setCombatMode "RED";
            _g setFormation "WEDGE";
            // vehicles: Ifrit HMG + Strider HMG, side by side on clear ground
            private _vehs = [];
            {
                private _vp = [_p getPos [18 + 14 * _forEachIndex, _dir + 90], 7, 40] call CQ_fnc_clearPos;
                if (_vp isEqualTo []) then { _vp = _p getPos [20 + 14 * _forEachIndex, _dir + 90] };
                private _v = createVehicle [_x, _vp, [], 0, "NONE"];
                _v setDir _dir;
                _v lock 0;
                _v setVariable ["CQ_aiSquadVeh", true, true];
                _g addVehicle _v;
                _vehs pushBack _v;
            } forEach CQ_aiSqVehs;
            _g setVariable ["CQ_aiSqVehs", _vehs];
            // crews: driver + gunner in each, the rest in the back
            private _men = units _g;
            private _i = 0;
            {
                private _v = _x;
                if (_i < count _men) then { (_men select _i) moveInDriver _v; _i = _i + 1 };
                if (_i < count _men) then { (_men select _i) moveInGunner _v; _i = _i + 1 };
            } forEach _vehs;
            for "_j" from _i to (count _men - 1) do {
                private _u = _men select _j;
                private _v = _vehs select (_j mod (count _vehs));
                if ((_v emptyPositions "cargo") > 0) then { _u moveInCargo _v } else { _u moveInCargo (_vehs select ((_j + 1) mod (count _vehs))) };
            };
            CQ_aiSqGroups pushBack _g;
            ["AI task force: %1 spawned at grid %2 (%3 m from the base)", [groupId _g, mapGridPosition _p, round (_p distance2D CQ_basePos)]] call CQ_fnc_log;

            // ---- brain
            [_g] spawn {
                params ["_g"];
                private _cur = objNull;
                private _plantT = -1;
                while { ({ alive _x } count units _g) > 0 } do {
                    private _l = leader _g;
                    // objectives of every active HQ, still standing: RADIO TOWERS FIRST (they cut the net),
                    // then the rest
                    private _act = (values CQ_hqs) select { (_x get "state") in CQ_activeStates };
                    private _objs = (_act apply { _x get "radio" }) select { !isNull _x && { alive _x } };
                    if (_objs isEqualTo []) then {
                        {
                            private _h = _x;
                            { if (!isNull _x && { alive _x }) then { _objs pushBack _x } } forEach ([_h get "building", _h get "depot", _h get "tanker"] + (_h getOrDefault ["installations", []]));
                        } forEach _act;
                        _objs = _objs arrayIntersect _objs;
                    };
                    if (_objs isNotEqualTo []) then {
                        private _t = ([_objs, [], { _x distance2D _l }, "ASCEND"] call BIS_fnc_sortBy) select 0;
                        if (_t != _cur) then {
                            _cur = _t; _plantT = -1;
                            // rush there: full speed, no stopping to fight on the way (they still shoot back),
                            // then search & destroy around it
                            [_g] call CQ_fnc_clearWaypoints;
                            _g setSpeedMode "FULL";
                            { _x disableAI "AUTOCOMBAT" } forEach units _g;
                            private _w = _g addWaypoint [getPosATL _t, 25];
                            _w setWaypointType "MOVE";
                            _w setWaypointBehaviour "AWARE";
                            _w setWaypointCombatMode "RED";
                            _w setWaypointSpeed "FULL";
                            private _w2 = _g addWaypoint [getPosATL _t, 60];
                            _w2 setWaypointType "SAD";
                            _w2 setWaypointCombatMode "RED";
                            ["AI task force: %1 goes for %2 at grid %3", [groupId _g, (_t getVariable ["CQ_objType", typeOf _t]), mapGridPosition _t]] call CQ_fnc_log;
                        };
                        // close enough: plant a charge on it
                        if (_l distance2D _cur < CQ_aiSqBlowR && { _plantT < 0 }) then {
                            _plantT = time;
                            private _eng = ((units _g) select { alive _x && { _x getUnitTrait "explosiveSpecialist" } }) param [0, _l];
                            _eng doMove (getPosATL _cur);
                            [_cur, _g] spawn {
                                params ["_o", "_g"];
                                sleep CQ_aiSqFuse;
                                if (alive _o) then {
                                    createVehicle ["DemoCharge_Remote_Ammo_Scripted", getPosATL _o, [], 0, "CAN_COLLIDE"] setDamage 1;
                                    _o setDamage 1;
                                    ["AI task force: %1 blew up %2 at grid %3", [groupId _g, (_o getVariable ["CQ_objType", typeOf _o]), mapGridPosition _o]] call CQ_fnc_log;
                                };
                            };
                        };
                    } else {
                        // nothing left to blow up: hunt the nearest enemy group
                        private _en = (allGroups select { side _x == east && { ({ alive _x } count units _x) > 0 } });
                        if (_en isNotEqualTo []) then {
                            private _e = ([_en, [], { (leader _x) distance2D _l }, "ASCEND"] call BIS_fnc_sortBy) select 0;
                            if ((waypoints _g) isEqualTo [] || { currentWaypoint _g >= count waypoints _g } || { ((waypointPosition [_g, currentWaypoint _g]) distance2D (leader _e)) > 300 }) then {
                                [_g] call CQ_fnc_clearWaypoints;
                                private _w = _g addWaypoint [getPosATL leader _e, 80];
                                _w setWaypointType "SAD";
                            };
                        };
                        _cur = objNull;
                    };
                    sleep 20;
                };
                ["AI task force: %1 wiped out", [groupId _g]] call CQ_fnc_log;
            };
        } forEach _spots;
        count _spots
    };
};
