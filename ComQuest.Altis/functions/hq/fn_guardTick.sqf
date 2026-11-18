/*
    CQ_fnc_guardTick  (server, director task "guards", unscheduled)
    Posted guards of every HQ (sites registered by CQ_fnc_guardSite):
      a player within CQ_guardSpawnR m of an active HQ -> each site's guards appear at their posts
      no player within CQ_guardDespawnR m for CQ_guardDespawnDelay s -> the living ones are removed
    A killed guard's post stays empty for the rest of the game (no farming).
    Out of the infantry cap (CQ_noInfCap) and of the all-AI total (CQ_noCap).
    Every site but the AA pits: half the men hold the posts in cover (doStop, crouched behind the
    barriers, tower tops and roofs standing; they never leave), the other half
    hunt: they patrol the site and run at any player they know of within CQ_guardHuntR m.
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
            // hunters: run at the closest player they know of within CQ_guardHuntR m of the site, back when he is gone
            private _gh = _s getOrDefault ["hunt", grpNull];
            if (!isNull _gh) then {
                private _sp = _s get "pos";
                private _l = leader _gh;
                private _t = (allPlayers select { alive _x && { _x distance2D _sp < CQ_guardHuntR } && { (_l knowsAbout vehicle _x) > 1 } });
                if (_t isNotEqualTo []) then {
                    _t = ([_t, [], { _x distance2D _l }, "ASCEND"] call BIS_fnc_sortBy) select 0;
                    [_gh] call CQ_fnc_clearWaypoints;
                    _gh setBehaviour "COMBAT"; _gh setSpeedMode "FULL";
                    _gh move (getPosATL _t);
                    _gh setVariable ["CQ_chasing", true];
                } else {
                    if ((_gh getVariable ["CQ_chasing", false]) || { _l distance2D _sp > CQ_guardHuntR + 50 }) then {
                        _gh setVariable ["CQ_chasing", false];
                        [_gh, _sp, CQ_guardHuntR * 0.5] call CQ_fnc_infPatrol;
                        _gh setBehaviour "AWARE"; _gh setSpeedMode "FULL";
                    };
                };
            };
            if (!isNull (_s get "group") || { !isNull _gh }) then { continue };   // still manned (the cover half never leaves its posts)
            private _posts = _s get "posts";
            private _dead = _s get "dead";
            private _live = [];
            { if !(_forEachIndex in _dead) then { _live pushBack [_forEachIndex, _x] } } forEach _posts;
            if (_live isEqualTo []) then { continue };
            // every site but the AA pits: half the men hunt within CQ_guardHuntR m, the other half hold the posts in cover
            // (the posts go high first, the rim last: the hunters take the rim ones)
            private _nHunt = if ((_s get "kind") == "aaPit") then { 0 } else { floor (count _live / 2) };
            private _hunt = _live select [count _live - _nHunt, _nHunt];
            private _hold = _live select [0, count _live - _nHunt];
            private _mkGroup = {
                params ["_list", "_tag"];
                private _g = createGroup [east, true];
                _g setVariable ["CQ_noInfCap", true];
                _g setVariable ["CQ_role", "post"];
                _g setGroupIdGlobal [format [["%1 %3 %2", "Tower guard %2"] select ((_s get "kind") == "radio" && { _tag == "guard" }), _s get "kind", _hid, _tag]];
                {
                    _x params ["_pi", "_post"];
                    _post params ["_p", "_dir", "_high"];
                    private _u = _g createUnit [CQ_guardClasses select (_pi mod count CQ_guardClasses), [_p select 0, _p select 1, 0], [], 0, "CAN_COLLIDE"];
                    _u setPosATL _p;
                    _u setDir _dir;
                    _u setSkill CQ_guardSkill;
                    _u setVariable ["CQ_gPost", [_hid, _si, _pi]];
                    _u setVariable ["CQ_noCap", true];   // out of the all-AI total too (they only exist near players)
                    _u addEventHandler ["Killed", {
                        ((_this select 0) getVariable ["CQ_gPost", []]) params [["_h", -1], ["_si", -1], ["_pi", -1]];
                        private _hq = CQ_hqs getOrDefault [_h, createHashMap];
                        private _s = (_hq getOrDefault ["guardSites", []]) param [_si, createHashMap];
                        if (count _s > 0) then { (_s get "dead") pushBackUnique _pi };
                    }];
                    _made = _made + 1;
                } forEach _list;
                [units _g] call CQ_fnc_unitPrep;
                _g setCombatMode "RED";
                _g enableDynamicSimulation false;
                _g
            };
            if (_hold isNotEqualTo []) then {
                private _g = [_hold, "guard"] call _mkGroup;
                _g setBehaviour "AWARE";
                {
                    private _high = ((_hold select _forEachIndex) select 1) select 2;
                    _x setVariable ["CQ_gHigh", _high];
                    doStop _x;
                    if (_high) then { _x disableAI "PATH"; _x setUnitPos "UP" } else { _x setUnitPos "MIDDLE" };   // crouched behind the barriers
                } forEach units _g;
                _s set ["group", _g];
            };
            if (_hunt isNotEqualTo []) then {
                private _g = [_hunt, "hunters"] call _mkGroup;
                _g setBehaviour "AWARE"; _g setSpeedMode "FULL";
                [_g, _s get "pos", CQ_guardHuntR * 0.5] call CQ_fnc_infPatrol;
                _s set ["hunt", _g];
            };
            _s set ["free", false];
        } forEach _sites;
        if (_made > 0) then { ["HQ #%1: player near, %2 guards at their posts", [_hid, _made]] call CQ_fnc_log };
    } else {
        if ((_sites findIf { !isNull (_x get "group") || { !isNull (_x getOrDefault ["hunt", grpNull]) } }) == -1) then { continue };
        if (!_far) then { _hq set ["guardFarT", -1]; continue };   // a player still around (or a fallen HQ being fought over): keep them
        if ((_hq getOrDefault ["guardFarT", -1]) < 0) then { _hq set ["guardFarT", time] };
        if (time - (_hq get "guardFarT") < CQ_guardDespawnDelay) then { continue };
        private _gone = 0;
        {
            private _s = _x;
            {
                private _g = _s getOrDefault [_x, grpNull];
                if (!isNull _g) then {
                    { if (alive _x && { vehicle _x == _x }) then { deleteVehicle _x; _gone = _gone + 1 } } forEach units _g;
                    _s set [_x, grpNull];
                };
            } forEach ["group", "hunt"];
        } forEach _sites;
        _hq set ["guardFarT", -1];
        ["HQ #%1: no player near, %2 guards taken off their posts", [_hid, _gone]] call CQ_fnc_log;
    };
} forEach CQ_hqs;
