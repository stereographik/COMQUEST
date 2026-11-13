/*
    CQ_fnc_buildTruck  (server)
    [_mode, _args] call CQ_fnc_buildTruck;   ("request" is spawned)

    The build truck: a Zamak with a full squad on board that carries the men and the materials of
    an HQ. CQ_fnc_hqBuild drives it from one objective site to the next; each stage only goes up
    once the truck stopped there (CQ_btStopDist), the squad got out and CQ_btSpawnDelay s passed.

      "assign"  [_hq, _truck, _squad]   the truck (and its squad) now serves this HQ
      "landed"  [_truck, _hqId]         a paradropped replacement touched down: crew, squad, assign
      "escort"  [_vehicle, _hqId]       a paradropped escort touched down: joins the truck's group
      "request" [_hq]                   (spawned) the carrier paradrops a new truck after
                                        CQ_btReplaceDelay s, with one escort more per truck this HQ
                                        lost (CQ_btEscortMax at most); CQ_btMaxDrops for the whole game
      "board"   [_hq]                   the squad gets back in (waits up to CQ_btBoardTime s)
      "kajman"  [_hq]                   (spawned) a Kajman scouts around the truck while the HQ is built

    HQ keys: "buildTruck" (object), "btSquad" (group), "btKills" (trucks lost), "btPending".
    The truck is never in the HQ's "vehicles": nothing else (roaming, convoys, colonists) takes it.
    When the HQ founds a child, the truck leaves for the child (CQ_fnc_hqSplit) and the carrier
    sends the parent a new one.
*/
params ["_mode", ["_args", []]];
if (!isServer) exitWith {};

switch (_mode) do {

    case "assign": {
        _args params ["_hq", "_tr", ["_sg", grpNull]];
        if (!alive _tr) exitWith {};
        _hq set ["buildTruck", _tr];
        _hq set ["btSquad", _sg];
        _tr setVariable ["CQ_btHq", _hq get "id", true];   // public: the debug map draws it in black
        _tr setVariable ["CQ_busy", true];
        _tr enableDynamicSimulation false;
        private _dg = group driver _tr;
        if (!isNull _dg) then { _dg enableDynamicSimulation false; _dg setFormation "COLUMN" };
        if (!isNull _sg) then { _sg enableDynamicSimulation false };
        if !(_tr getVariable ["CQ_btEh", false]) then {
            _tr setVariable ["CQ_btEh", true];
            _tr addEventHandler ["Killed", {
                params ["_v"];
                private _h = CQ_hqs getOrDefault [_v getVariable ["CQ_btHq", -1], createHashMap];
                if (count _h == 0 || { (_h getOrDefault ["buildTruck", objNull]) != _v }) exitWith {};
                _h set ["buildTruck", objNull];
                _h set ["btKills", (_h getOrDefault ["btKills", 0]) + 1];
                // the squad's survivors stay and garrison the HQ
                private _sg = _h getOrDefault ["btSquad", grpNull];
                _h set ["btSquad", grpNull];
                if (!isNull _sg && { ({ alive _x } count units _sg) > 0 }) then {
                    { unassignVehicle _x } forEach units _sg;
                    (_h get "infantry") pushBack _sg;
                };
                ["Enemy build truck destroyed", format ["HQ #%1: build truck destroyed at grid %2 (%3 lost so far), construction frozen",
                    _h get "id", mapGridPosition _v, _h get "btKills"]] call CQ_fnc_announce;
                ["request", [_h]] spawn CQ_fnc_buildTruck;
            }];
        };
        if (!(_hq getOrDefault ["buildDone", false]) && { !(_hq getOrDefault ["kajLoop", false]) }) then { ["kajman", [_hq]] spawn CQ_fnc_buildTruck };
        ["HQ #%1: build truck %2 assigned (squad %3, %4 escorts)", [_hq get "id", typeOf _tr,
            [groupId _sg, "none"] select (isNull _sg), (count units group driver _tr) - 1]] call CQ_fnc_log;
    };

    case "landed": {
        _args params ["_tr", "_id"];
        private _hq = CQ_hqs getOrDefault [_id, createHashMap];
        if (count _hq == 0 || { (_hq get "state") in ["Failed", "Destroyed"] }) exitWith {
            ["Build truck landed for HQ #%1, which is gone: it joins nobody", [_id]] call CQ_fnc_log;
        };
        [_tr] call CQ_fnc_crewVehicle;
        private _sg = createGroup [east, true];
        { _sg createUnit [_x, getPosATL _tr, [], 8, "NONE"] } forEach CQ_btSquad;
        [units _sg] call CQ_fnc_unitPrep;
        _sg addVehicle _tr;
        { if !(_x moveInCargo _tr) then { _x moveInAny _tr } } forEach units _sg;
        ["assign", [_hq, _tr, _sg]] call CQ_fnc_buildTruck;
        // escorts already down join the truck now
        { if (alive _x) then { (crew _x) joinSilent (group driver _tr) } } forEach (_hq getOrDefault ["btEscWait", []]);
        _hq set ["btEscWait", []];
        ["Enemy build truck landed", format ["HQ #%1: build truck down at grid %2 with its squad", _id, mapGridPosition _tr]] call CQ_fnc_announce;
    };

    case "escort": {
        _args params ["_v", "_id"];
        private _hq = CQ_hqs getOrDefault [_id, createHashMap];
        [_v] call CQ_fnc_crewVehicle;
        [_v, CQ_vehSpawnAmmo] call CQ_fnc_vehAmmoInit;
        _v setVariable ["CQ_busy", true];
        _v enableDynamicSimulation false;
        (group driver _v) enableDynamicSimulation false;
        if (count _hq == 0) exitWith {};
        private _tr = _hq getOrDefault ["buildTruck", objNull];
        if (alive _tr) then { (crew _v) joinSilent (group driver _tr) } else {
            private _w = _hq getOrDefault ["btEscWait", []]; _w pushBack _v; _hq set ["btEscWait", _w];
        };
        ["HQ #%1: build truck escort %2 down", [_id, typeOf _v]] call CQ_fnc_log;
    };

    case "request": {
        _args params ["_hq"];
        private _id = _hq get "id";
        if (_hq getOrDefault ["btPending", false]) exitWith {};
        if (isNil "CQ_btDrops") then { CQ_btDrops = 0 };
        if (CQ_btDrops >= CQ_btMaxDrops) exitWith {
            if !(_hq getOrDefault ["btNone", false]) then {
                _hq set ["btNone", true];
                ["Carrier out of build trucks", format ["HQ #%1: the carrier has no build truck left (%2 sent), its construction stays frozen", _id, CQ_btDrops]] call CQ_fnc_announce;
            };
        };
        CQ_btDrops = CQ_btDrops + 1;
        _hq set ["btPending", true];
        private _esc = (_hq getOrDefault ["btKills", 0]) min CQ_btEscortMax;
        ["HQ #%1: carrier sends a build truck in %2 s (drop %3/%4, %5 escorts)", [_id, CQ_btReplaceDelay, CQ_btDrops, CQ_btMaxDrops, _esc]] call CQ_fnc_log;
        private _t = time;
        waitUntil { sleep 2; time - _t >= CQ_btReplaceDelay || { _hq getOrDefault ["btNow", false] } };
        _hq set ["btNow", false];
        if ((_hq get "state") in ["Failed", "Destroyed"]) exitWith { _hq set ["btPending", false] };
        private _lz = (_hq get "pos") getPos [120 + random 80, random 360];
        [CQ_btTruckClass, _lz, compile format ["['landed', [_this select 0, %1]] call CQ_fnc_buildTruck", _id], "Build truck"] spawn CQ_fnc_paraDropVehicle;
        for "_i" from 1 to _esc do {
            [CQ_btEscortClass, _lz getPos [60 + 30 * _i, random 360], compile format ["['escort', [_this select 0, %1]] call CQ_fnc_buildTruck", _id], "Build truck escort"] spawn CQ_fnc_paraDropVehicle;
        };
        // lost in the air: the next look for a truck (CQ_fnc_hqBuild) asks again
        _t = time;
        waitUntil { sleep 5; alive (_hq getOrDefault ["buildTruck", objNull]) || { time - _t > 420 } };
        _hq set ["btPending", false];
    };

    case "kajman": {
        // A Kajman teams with the truck while the HQ is being built: the nearest free one of the
        // fleet (CQ_air, state "btEscort" keeps it out of patrols, QRFs and re-basing), else the
        // carrier flies one in. It scouts CQ_btKajRange m around the truck, a new point every
        // CQ_btKajEvery s. Lost: another after CQ_btKajDelay s. HQ built: back to the fleet.
        _args params ["_hq"];
        private _id = _hq get "id";
        _hq set ["kajLoop", true];
        private _e = createHashMap;
        private _nextT = time + 90;  // when a (new) Kajman may be fetched (90 s: the landing's own Kajman joins the fleet first)
        private _carrierT = time + 240;  // first fetch: the carrier sends one only if no fleet Kajman frees up within 240 s
        private _ptT = 0;
        private _release = {
            if (count _e > 0 && { alive (_e get "veh") }) then {
                (_e get "veh") setVariable ["CQ_btKaj", nil, true];
                _e set ["state", "toPark"]; _e set ["nearT", -1];
                (_e get "veh") flyInHeight 110;
                (_e get "veh") doMove (getPosATL (_e get "pad"));
                ["HQ #%1: build truck Kajman back to the fleet", [_id]] call CQ_fnc_log;
            };
            _e = createHashMap;
        };
        while { (_hq get "state") in CQ_activeStates && { !(_hq getOrDefault ["buildDone", false]) } } do {
            sleep 5;
            private _tr = _hq getOrDefault ["buildTruck", objNull];
            private _ctr = if (alive _tr) then { getPosATL _tr } else { _hq get "pos" };
            // lost (dead, or taken off the job): wait, then get another
            if (count _e > 0 && { !alive (_e get "veh") || { (_e get "state") != "btEscort" } }) then {
                if ((_e get "state") == "btEscort") then { ["HQ #%1: build truck Kajman lost, another in %2 s", [_id, CQ_btKajDelay]] call CQ_fnc_log };
                _e = createHashMap; _nextT = time + CQ_btKajDelay;
            };
            // dry or thirsty: back to the fleet (it rearms there), another one comes at once
            if (count _e > 0 && { alive (_e get "veh") } && { ([_e get "veh"] call CQ_fnc_vehAmmoLevel) < CQ_airLowAmmo || { fuel (_e get "veh") < CQ_airLowFuel } }) then {
                ["HQ #%1: build truck Kajman low on ammo or fuel, swapped", [_id]] call CQ_fnc_log;
                call _release; _nextT = time;
            };
            private _free = [];
            if (count _e == 0 && { time >= _nextT }) then {
                _free = CQ_air select {
                    alive (_x get "veh") && { (typeOf (_x get "veh")) find "O_Heli_Attack_02" == 0 } && { (_x get "state") in ["parked", "toPark", "patrolling"] }
                    && { ([_x get "veh"] call CQ_fnc_vehAmmoLevel) >= CQ_airLowAmmo } && { fuel (_x get "veh") >= CQ_airLowFuel }   // not the one just sent to rearm
                };
            };
            // no free one yet and the landing's escorts may still be on their way to the fleet: wait
            if (count _e == 0 && { time >= _nextT } && { _free isNotEqualTo [] || { time >= _carrierT } }) then {
                if (_free isNotEqualTo []) then {
                    _free = [_free, [], { (_x get "veh") distance2D _ctr }, "ASCEND"] call BIS_fnc_sortBy;
                    _e = _free select 0;
                    ["HQ #%1: fleet Kajman %2 teams with the build truck (%3 m away)", [_id, groupId (_e get "grp"), round ((_e get "veh") distance2D _ctr)]] call CQ_fnc_log;
                } else {
                    private _from = if (!isNil "CQ_carrierPos") then { CQ_carrierPos getPos [300, CQ_carrierPos getDir _ctr] } else { _ctr getPos [5000, random 360] };
                    ([CQ_btKajClass, [_from select 0, _from select 1, 0], _from getDir _ctr, false, CQ_heightEscort] call CQ_fnc_spawnHeli) params ["_h", "_hg"];
                    [_h] call CQ_fnc_airLoadout;
                    [_h, 1] call CQ_fnc_vehAmmoInit;
                    [_h, _hg, "armed", _id, objNull, [], true] call CQ_fnc_airRegister;   // always accepted (parked flag), even with a full fleet
                    _e = CQ_air select (CQ_air findIf { (_x get "veh") == _h });
                    _h engineOn true;
                    ["HQ #%1: no free Kajman, the carrier sends one for the build truck", [_id]] call CQ_fnc_log;
                };
                _e set ["state", "btEscort"];
                (_e get "veh") setVariable ["CQ_btKaj", _id, true];   // the debug map draws it in black
                private _g = _e get "grp";
                [_g] call CQ_fnc_clearWaypoints;
                _g setBehaviour "AWARE"; _g setCombatMode "RED";
                _ptT = 0;
            };
            // scouting: a new point CQ_btKajRange around the truck every CQ_btKajEvery s
            if (count _e > 0 && { time >= _ptT }) then {
                private _v = _e get "veh";
                CQ_btKajRange params ["_r0", "_r1"];
                _v flyInHeight (60 + random 60);
                _v doMove (_ctr getPos [_r0 + random (_r1 - _r0), random 360]);
                _ptT = time + (CQ_btKajEvery select 0) + random ((CQ_btKajEvery select 1) - (CQ_btKajEvery select 0));
            };
            // the truck moved on to another HQ (split): this loop belongs to the old one
            if (alive _tr && { (_tr getVariable ["CQ_btHq", -1]) != _id }) exitWith {};
        };
        call _release;
        _hq set ["kajLoop", false];
    };

    case "board": {
        _args params ["_hq"];
        private _tr = _hq getOrDefault ["buildTruck", objNull];
        private _sg = _hq getOrDefault ["btSquad", grpNull];
        if (!alive _tr || { isNull _sg }) exitWith {};
        private _out = (units _sg) select { alive _x && { vehicle _x != _tr } };
        if (_out isEqualTo []) exitWith {};
        _sg addVehicle _tr;
        { _x assignAsCargo _tr } forEach _out;
        _out orderGetIn true;
        private _t = time;
        waitUntil { sleep 1; !alive _tr || { ((units _sg) findIf { alive _x && { vehicle _x != _tr } }) < 0 } || { time - _t > CQ_btBoardTime } };
        // close enough: in they go; the others follow on foot
        { if (alive _x && { vehicle _x != _tr } && { _x distance _tr < 40 }) then { _x moveInCargo _tr } } forEach units _sg;
    };
};
