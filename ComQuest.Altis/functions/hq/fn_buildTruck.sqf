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
