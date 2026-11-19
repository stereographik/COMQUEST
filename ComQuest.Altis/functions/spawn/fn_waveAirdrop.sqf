/*
    CQ_fnc_waveAirdrop  (server)
    ["start", [_hq]] spawn CQ_fnc_waveAirdrop;          from CQ_fnc_hqTick, the moment the perimeter is secured
    ["drop", [_hqId, _vehicle]] call CQ_fnc_waveAirdrop; CQ_fnc_paraDropVehicle, as the vehicle leaves the Mohawk
    ["landed", [_hqId, _vehicle]] call CQ_fnc_waveAirdrop; CQ_fnc_paraDropVehicle, once it stands on the ground
    THE FIRST WAVE OF EVERY HQ, AIRDROPPED: when its perimeter is secured (the build starts), two
    Mohawks from the carrier drop the wave's armour and random vehicle (CQ_wavePools), each under
    its own parachute, CQ_airWaveDist m from the build truck (else from the site). The squad
    (as many as the HQ is short of CQ_garrisonTarget, CQ_waveMax at most, + the tide's extra) rides inside them during the drop: crew at their
    posts, soldiers in the cargo seats; any soldier with no seat left jumps on his own parachute
    next to the last vehicle. No damage until on the ground. Landed: the vehicles drive to the HQ,
    the soldiers dismount there and join its garrison (fresh reinforcements, CQ_role "reinf").
    The carrier pays a wave (CQ_lanceCost "wave"); the caps are not checked (it is the HQ's starting
    force). After the build, road convoys fill whatever the HQ is still short of (CQ_fnc_hqTick).
*/
params ["_mode", "_a"];
switch (_mode) do {
    case "start": {
        _a params ["_hq"];
        private _id = _hq get "id";
        if (_hq getOrDefault ["airWave", false]) exitWith {};
        _hq set ["airWave", true];
        if !(["wave", format ["airdropped first wave, HQ #%1", _id]] call CQ_fnc_carrierSpend) exitWith {
            _hq set ["airWave", false];   // not paid: the HQ calls its usual first wave after the build
            ["HQ #%1: no airdropped first wave (the carrier cannot pay)", [_id]] call CQ_fnc_log;
        };
        private _c = _hq get "pos";
        private _tr = _hq getOrDefault ["buildTruck", objNull];
        private _ctr = if (alive _tr) then { getPosATL _tr } else { _c };
        CQ_airWaveDist params ["_d0", "_d1"];
        private _lz = [];
        for "_i" from 1 to 30 do {
            private _p = _ctr getPos [_d0 + random (_d1 - _d0), random 360];
            if (!surfaceIsWater _p && { (_p isFlatEmpty [6, -1, 0.4, 6, 0, false, objNull]) isNotEqualTo [] }) exitWith { _lz = _p };
        };
        if (_lz isEqualTo []) then { _lz = _ctr getPos [_d0, _ctr getDir _c] };
        // the squad: its classes, waiting for seats (+ the tide's extra soldiers)
        private _squadCfg = configFile >> "CfgGroups" >> "East" >> "OPF_F" >> "Infantry" >> "OIA_InfSquad";
        private _cls = ("true" configClasses _squadCfg) apply { getText (_x >> "vehicle") };
        // GARRISON TARGET: as many as the new HQ is short of CQ_garrisonTarget (its colonists count)
        private _need = ((CQ_garrisonTarget - ([(_hq get "infantry")] call CQ_fnc_aliveCount)) max CQ_waveMin) min CQ_waveMax;
        _cls = _cls select [0, _need];
        while { count _cls < _need } do { _cls pushBack (selectRandom ["O_Soldier_F", "O_Soldier_AR_F", "O_Soldier_LAT_F", "O_Soldier_GL_F"]) };
        if (CQ_lanceOn) then { for "_k" from 1 to ((missionNamespace getVariable ["CQ_lanceTide", 0]) * CQ_lanceTideSoldiers) do { _cls pushBack (selectRandom ["O_Soldier_F", "O_Soldier_AR_F", "O_Soldier_LAT_F", "O_Soldier_GL_F"]) } };
        // the squad's group is made at the first drop: an empty "delete when empty" group made now
        // would be removed by the engine before the Mohawks get there (0 soldiers, 2026-11-19)
        private _pools = CQ_wavePools select { (_x select 0) in ["armour", "random"] };
        _hq set ["awGroup", grpNull];
        _hq set ["awPending", _cls];
        _hq set ["awVehs", []];
        _hq set ["awDrops", count _pools];
        _hq set ["awLanded", 0];
        {
            _x params ["_pool", "_classes"];
            private _vc = selectRandom _classes;
            [_vc, _lz getPos [60 * _forEachIndex, random 360],
                compile format ["['landed', [%1, _this select 0]] call CQ_fnc_waveAirdrop", _id], format ["HQ #%1 first wave (%2)", _id, _pool],
                compile format ["(_this select 0) setVariable ['CQ_pool', '%2']; ['drop', [%1, _this select 0]] call CQ_fnc_waveAirdrop", _id, _pool]] spawn CQ_fnc_paraDropVehicle;
            sleep 4;
        } forEach _pools;
        ["Enemy reinforcements airborne", format ["HQ #%1: the carrier airdrops its first wave (%2 soldiers in %3 vehicles) near grid %4",
            _id, count _cls, count _pools, mapGridPosition _lz]] call CQ_fnc_announce;

        // on the ground (or lost): drive to the HQ, dismount, join the garrison
        private _t0 = time;
        waitUntil { sleep 3; (_hq get "awLanded") >= (_hq get "awDrops") || { time - _t0 > 420 } || { !((_hq get "state") in CQ_activeStates) } };
        private _vehs = (_hq get "awVehs") select { alive _x };
        private _g = _hq get "awGroup";
        private _dest = _c getPos [70, _c getDir _lz];
        { if (canMove _x && { alive driver _x }) then { (group driver _x) move _dest } } forEach _vehs;
        if (({ alive _x && { vehicle _x == _x } } count units _g) > 0) then { _g move _dest };   // the ones who jumped walk in
        private _t1 = time;
        waitUntil {
            sleep 3;
            private _m = _vehs select { alive _x && { canMove _x } && { alive driver _x } };
            _m isEqualTo [] || { (_m findIf { _x distance2D _c > 220 }) == -1 } || { time - _t1 > 600 } || { !((_hq get "state") in CQ_activeStates) }
        };
        // never left invulnerable (a landing that was not reported)
        { _x allowDamage true; { _x allowDamage true } forEach crew _x } forEach (_hq get "awVehs");
        // the squad (its own group: the crews are in theirs) gets out at the HQ
        if (!isNull _g) then {
            { if (vehicle _x != _x) then { unassignVehicle _x; moveOut _x } } forEach units _g;
            { _g leaveVehicle _x } forEach _vehs;
            _g move (_c getPos [40, random 360]);
        };
        private _n = { alive _x } count units _g;
        // nobody made it: it does not count as the HQ's first wave (the usual one comes after the build)
        if (_n == 0) then { _hq set ["airWave", false] };
        if ((_hq get "state") in CQ_activeStates) then {
            if (_n > 0) then { (_hq get "infantry") pushBack _g; _g enableDynamicSimulation CQ_dynSimGarrison };
            (_hq get "vehicles") append _vehs;
        };
        ["Enemy reinforcements arrived", format ["HQ #%1: its airdropped first wave joined the garrison (%2 soldiers, %3 vehicles)", _id, _n, count (_vehs select { alive _x })]] call CQ_fnc_announce;
        CQ_balanceForceT = time + 10;
    };

    case "drop": {
        _a params ["_id", "_v"];
        private _hq = CQ_hqs getOrDefault [_id, createHashMap];
        if (count _hq == 0 || { !alive _v }) exitWith {};
        isNil {
            _v allowDamage false;
            private _cg = [_v] call CQ_fnc_crewVehicle;
            _cg setBehaviour "AWARE";
            [_v, CQ_vehSpawnAmmo] call CQ_fnc_vehAmmoInit;
            { _x allowDamage false } forEach crew _v;
            (_hq get "awVehs") pushBack _v;
            private _g = _hq get "awGroup";
            if (isNull _g) then {
                _g = createGroup [east, true];
                _g setVariable ["CQ_role", "reinf"];
                _hq set ["awGroup", _g];
            };
            private _pend = _hq get "awPending";
            private _n0 = count _pend;
            while { _pend isNotEqualTo [] && { (_v emptyPositions "cargo") > 0 } } do {
                private _u = _g createUnit [_pend deleteAt 0, getPosATL _v, [], 0, "CAN_COLLIDE"];
                [[_u]] call CQ_fnc_unitPrep;
                _u allowDamage false;
                _u moveInCargo _v;
                if (vehicle _u == _u) exitWith { deleteVehicle _u };
            };
            ["HQ #%1: first wave, %2 soldiers aboard the %3 (%4 still waiting for a seat)", [_id, _n0 - count _pend, typeOf _v, count _pend]] call CQ_fnc_log;
            // last vehicle out: the soldiers with no seat jump on their own parachutes next to it
            _hq set ["awDropped", (_hq getOrDefault ["awDropped", 0]) + 1];
            if ((_hq get "awDropped") >= (_hq get "awDrops") && { _pend isNotEqualTo [] }) then {
                private _p0 = getPosATL _v;
                {
                    private _u = _g createUnit [_x, [_p0 select 0, _p0 select 1, 0], [], 30, "CAN_COLLIDE"];
                    [[_u]] call CQ_fnc_unitPrep;
                    private _pp = (getPosATL _u) vectorAdd [0, 0, (_p0 select 2) max 150];
                    private _ch = createVehicle ["Steerable_Parachute_F", _pp, [], 0, "FLY"];
                    _ch setPosATL _pp;
                    _u moveInDriver _ch;
                } forEach _pend;
                ["HQ #%1: first wave, %2 soldiers with no seat jump on their own parachutes", [_id, count _pend]] call CQ_fnc_log;
                _hq set ["awPending", []];
            };
        };
    };

    case "landed": {
        _a params ["_id", "_v"];
        private _hq = CQ_hqs getOrDefault [_id, createHashMap];
        if (count _hq == 0) exitWith {};
        { _x allowDamage true } forEach crew _v;
        _hq set ["awLanded", (_hq getOrDefault ["awLanded", 0]) + 1];
    };
};
