/*
    CQ_fnc_guardTick  (server, director task "guards", unscheduled)
    Posted guards of every HQ (sites registered by CQ_fnc_guardSite):
      a player within CQ_guardSpawnR m of an active HQ -> each site's guards appear at their posts
      no player within CQ_guardDespawnR m for CQ_guardDespawnDelay s -> the living ones are removed
    A killed guard's post stays empty for the rest of the game (no farming).
    Out of the infantry cap (CQ_noInfCap); they still count in the all-AI total.
    At their posts they hold (doStop; tower tops and roofs never leave). Once their group is in
    combat, the ones on the ground follow their leader and fight.
*/
{
    private _hq = _y;
    private _sites = _hq getOrDefault ["guardSites", []];
    if (_sites isEqualTo []) then { continue };
    private _c = _hq get "pos";
    private _active = (_hq get "state") in CQ_activeStates;
    private _near = (allPlayers findIf { alive _x && { _x distance2D _c < CQ_guardSpawnR } }) > -1;
    private _far = (allPlayers findIf { alive _x && { _x distance2D _c < CQ_guardDespawnR } }) == -1;
    private _hid = _hq get "id";

    if (_near && { _active }) then {
        _hq set ["guardFarT", -1];
        private _made = 0;
        {
            private _s = _x;
            private _si = _forEachIndex;
            if (!isNull (_s get "group")) then {
                // released once in combat: the men on the ground fight with their leader
                private _g = _s get "group";
                if (!(_s get "free") && { (behaviour leader _g) == "COMBAT" }) then {
                    _s set ["free", true];
                    { if (!(_x getVariable ["CQ_gHigh", false])) then { _x doFollow leader _g } } forEach units _g;
                };
                continue;
            };
            private _posts = _s get "posts";
            private _dead = _s get "dead";
            private _live = [];
            { if !(_forEachIndex in _dead) then { _live pushBack [_forEachIndex, _x] } } forEach _posts;
            if (_live isEqualTo []) then { continue };
            private _g = createGroup [east, true];
            _g setVariable ["CQ_noInfCap", true];
            _g setVariable ["CQ_role", "post"];
            _g setGroupIdGlobal [format [["%1 guard %2", "Tower guard %2"] select ((_s get "kind") == "radio"), _s get "kind", _hid]];
            {
                _x params ["_pi", "_post"];
                _post params ["_p", "_dir", "_high"];
                private _u = _g createUnit [CQ_guardClasses select (_pi mod count CQ_guardClasses), [_p select 0, _p select 1, 0], [], 0, "CAN_COLLIDE"];
                _u setPosATL _p;
                _u setDir _dir;
                _u setSkill CQ_guardSkill;
                _u setVariable ["CQ_gPost", [_hid, _si, _pi]];
                _u setVariable ["CQ_gHigh", _high];
                if (_high) then { _u disableAI "PATH"; _u setUnitPos "UP" };
                _u addEventHandler ["Killed", {
                    ((_this select 0) getVariable ["CQ_gPost", []]) params [["_h", -1], ["_si", -1], ["_pi", -1]];
                    private _hq = CQ_hqs getOrDefault [_h, createHashMap];
                    private _s = (_hq getOrDefault ["guardSites", []]) param [_si, createHashMap];
                    if (count _s > 0) then { (_s get "dead") pushBackUnique _pi };
                }];
                _made = _made + 1;
            } forEach _live;
            [units _g] call CQ_fnc_unitPrep;
            _g setBehaviour "AWARE"; _g setCombatMode "RED";
            _g enableDynamicSimulation false;
            { doStop _x } forEach units _g;
            _s set ["group", _g];
            _s set ["free", false];
        } forEach _sites;
        if (_made > 0) then { ["HQ #%1: player near, %2 guards at their posts", [_hid, _made]] call CQ_fnc_log };
    } else {
        if ((_sites findIf { !isNull (_x get "group") }) == -1) then { continue };
        if (!_far) then { _hq set ["guardFarT", -1]; continue };   // a player still around (or a fallen HQ being fought over): keep them
        if ((_hq getOrDefault ["guardFarT", -1]) < 0) then { _hq set ["guardFarT", time] };
        if (time - (_hq get "guardFarT") < CQ_guardDespawnDelay) then { continue };
        private _gone = 0;
        {
            private _g = _x get "group";
            if (!isNull _g) then {
                { if (alive _x && { vehicle _x == _x }) then { deleteVehicle _x; _gone = _gone + 1 } } forEach units _g;
                _x set ["group", grpNull];
            };
        } forEach _sites;
        _hq set ["guardFarT", -1];
        ["HQ #%1: no player near, %2 guards taken off their posts", [_hid, _gone]] call CQ_fnc_log;
    };
} forEach CQ_hqs;
