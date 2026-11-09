/*
    CQ_fnc_magTick  (server, director task, every 5 s)
    MAGPIE flies her drones and reports what they identify.
    Drones: spawned on the runway when due; a destroyed one is reported and replaced after
    CQ_magRespawn s. Always full fuel, no weapons, never engage (careless, hold fire).
    Detection (every CQ_magDetectEvery s): every enemy unit or vehicle within the drone's
    sensor radius (grows with altitude) and in line of sight is identified; enemy HQ sites
    and their construction stage too.
    Flight plans (every CQ_magPlanEvery s per drone), avoiding the east coast:
      no known positions        explore: the nearest unscanned search cell (each drone its own)
      known positions           an ellipse fitted around every position identified in the
                                last CQ_magMemory s (principal axes), wider for the higher
                                drones (CQ_magDrones scale); the Reaper alternates ellipse and
                                exploration, the Greyhawk explores when the last report was empty
    Report (every CQ_magReportEvery s, if anything is new): a MAGPIE card with the count of new
    identifications by kind and the HQ news, and dots on every player's map for 10 s.
*/
if (time < CQ_magNext) exitWith {};
CQ_magNext = time + 5;

private _cat = {
    params ["_o"];
    switch (true) do {
        case (_o isKindOf "CAManBase"): { "inf" };
        case (_o isKindOf "Air"): { "air" };
        case (_o isKindOf "StaticWeapon"): { "static" };
        case (_o isKindOf "Tank" || { _o isKindOf "Wheeled_APC_F" }): { "armour" };
        default { "light" };
    }
};

// ---- drones: spawn, take-off queue, loss, fuel
// Every due drone spawns at once: the first on the take-off spot, the others on waiting spots
// beside the runway. One drone rolls at a time: it is placed on the take-off spot, its AI is
// released and it gets a push down the runway (no slow AI taxiing). Watchdog: still on the
// ground after CQ_magRollTimeout s -> put back and pushed again; after 2 retries it is
// started in the air. A lost drone is reported and comes back after CQ_magRespawn s.
CQ_magRunway params ["_rp", "_hdg"];
private _waitPos = {
    params ["_k"];
    private _p = (_rp getPos [30, _hdg + 90]) getPos [18 * _k, _hdg];
    [_p select 0, _p select 1, 0]
};
private _launch = {
    params ["_m"];
    private _v = _m get "veh";
    private _g = group effectiveCommander _v;
    { _x enableAI "MOVE" } forEach crew _v;
    _v setDir _hdg;
    _v setPosATL [_rp select 0, _rp select 1, 0.3];
    while { (waypoints _g) isNotEqualTo [] } do { deleteWaypoint ((waypoints _g) select 0) };
    private _wp = _g addWaypoint [_rp getPos [3000, _hdg], 0];
    _wp setWaypointType "MOVE";
    _v engineOn true;
    _v flyInHeight (_m get "alt");
    if (_v isKindOf "Helicopter" || { (getNumber (configOf _v >> "vtol")) > 0 } || { (_m get "cls") == "B_UAV_01_F" }) then {
        _v setVelocity [0, 0, 6];                         // quadcopter: straight up
    } else {
        _v setVelocityModelSpace [0, 45, 0];              // fixed wing: rolling start (~160 km/h)
    };
    _v allowDamage false;                                  // no bounce damage during the take-off run
    _m set ["phase", "rolling"];
    _m set ["rollT", time];
    _m set ["planT", time];
    CQ_magLastLaunch = time;
    ["MAGPIE: %1 cleared for take-off (try %2)", [_m get "name", (_m get "tries") + 1]] call CQ_fnc_log;
};
{
    private _m = _x;
    private _v = _m get "veh";
    if (!isNull _v && { !alive _v } && { !(_m get "lost") }) then {
        _m set ["lost", true];
        _m set ["phase", "none"];
        CQ_magVehs = (CQ_mag apply { _x get "veh" }) select { alive _x };
        publicVariable "CQ_magVehs";
        _m set ["due", time + CQ_magRespawn];
        ["magDown", [_m get "name"]] call CQ_fnc_say;
        ["MAGPIE: %1 lost at %2, replacement in %3 s", [_m get "name", mapGridPosition _v, CQ_magRespawn]] call CQ_fnc_log;
    };
    // spawn (on a waiting spot; the queue below sends it to the runway)
    if ((isNull _v || { !alive _v }) && { time >= (_m get "due") }) then {
        private _k = 1 + (_m get "i");
        private _sp = [_k] call _waitPos;
        private _nv = createVehicle [_m get "cls", _sp, [], 0, "CAN_COLLIDE"];
        _nv setDir _hdg;
        _nv setPosATL [_sp select 0, _sp select 1, 0.3];
        createVehicleCrew _nv;
        { _nv setPylonLoadout [_forEachIndex + 1, ""] } forEach (getPylonMagazines _nv);
        private _g = group effectiveCommander _nv;
        _g setGroupIdGlobal [format ["MAGPIE %1", _m get "name"]];
        _g setBehaviour "CARELESS";
        _g setCombatMode "BLUE";
        { _x disableAI "MOVE" } forEach crew _nv;        // waits until cleared for take-off
        _nv setVariable ["CQ_magpie", true, true];
        _nv setVariable ["CQ_magName", _m get "name", true];
        CQ_magVehs = (CQ_mag apply { _x get "veh" }) select { alive _x };
        publicVariable "CQ_magVehs";
        _m set ["veh", _nv];
        _m set ["lost", false];
        _m set ["phase", "waiting"];
        _m set ["tries", 0];
        _m set ["planT", time];
        ["MAGPIE: %1 (%2) waiting beside the runway", [_m get "name", _m get "cls"]] call CQ_fnc_log;
    };
    if (alive _v && { fuel _v < 0.9 }) then { _v setFuel 1 };
    // rolling -> airborne, or watchdog
    if (alive _v && { (_m getOrDefault ["phase", ""]) == "rolling" }) then {
        if (((getPosATL _v) select 2) > 30) then {
            _m set ["phase", "air"];
            _m set ["planT", -1e6];                         // first exploration route right away
            _v allowDamage true;
            ["magLaunch", [_m get "name"]] call CQ_fnc_say;
            ["MAGPIE: %1 airborne after %2 s", [_m get "name", round (time - (_m get "rollT"))]] call CQ_fnc_log;
        } else {
            if (time - (_m get "rollT") > CQ_magRollTimeout) then {
                _m set ["tries", (_m get "tries") + 1];
                if ((_m get "tries") > 2) then {
                    _v setPosATL ((_rp getPos [600, _hdg]) vectorAdd [0, 0, 200]);
                    _v setDir _hdg;
                    _v setVelocityModelSpace [0, 60, 0];
                    _v allowDamage true;
                    _m set ["phase", "air"];
                    _m set ["planT", -1e6];
                    ["magLaunch", [_m get "name"]] call CQ_fnc_say;
                    ["MAGPIE: %1 could not take off, started in the air", [_m get "name"]] call CQ_fnc_log;
                } else {
                    [_m] call _launch;
                };
            };
        };
    };
} forEach CQ_mag;
// the queue: one drone on the runway at a time, in order
private _next = CQ_mag select { alive (_x get "veh") && { (_x getOrDefault ["phase", ""]) == "waiting" } };
private _gap = if (_next isNotEqualTo [] && { ((_next select 0) get "cls") == "B_UAV_01_F" }) then { CQ_magLaunchGapQuad } else { CQ_magLaunchGap };
if ((CQ_mag findIf { alive (_x get "veh") && { (_x getOrDefault ["phase", ""]) == "rolling" } }) == -1
    && { time - (missionNamespace getVariable ["CQ_magLastLaunch", -1e6]) > _gap }) then {
    if (_next isNotEqualTo []) then {
        private _busy = ((nearestObjects [_rp, ["LandVehicle", "Air"], 25]) select { alive _x && { !(_x getVariable ["CQ_magpie", false]) } }) isNotEqualTo [];
        if (_busy) exitWith { ["MAGPIE: take-off spot blocked by %1", [typeOf ((nearestObjects [_rp, ["LandVehicle", "Air"], 25]) select 0)]] call CQ_fnc_log };
        [_next select 0] call _launch;
    };
};

private _flying = CQ_mag select { alive (_x get "veh") && { (_x getOrDefault ["phase", ""]) == "air" } };

// ---- detection
// Sensor radius grows with altitude (CQ_magSensor). A new contact in line of sight is only
// identified with a chance per pass (CQ_magSpotChance by kind): it takes several passes to see
// everything. A contact already identified is tracked while it stays in line of sight: those
// are the live enemy positions every player sees on the map (CQ_magVisible).
if (time >= CQ_magDetectT) then {
    CQ_magDetectT = time + CQ_magDetectEvery;
    {
        private _v = _x get "veh";
        private _alt = (getPosATL _v) select 2;
        if (_alt < 40) then { continue };                 // still taking off
        CQ_magSensor params ["_r0", "_rk", "_rmax"];
        private _r = (_r0 + _alt * _rk) min _rmax;
        private _eye = getPosASL _v vectorAdd [0, 0, -1.5];
        // search cells seen
        { if (!(_x select 1) && { (_x select 0) distance2D _v < _r * 0.8 }) then { _x set [1, true] } } forEach CQ_magCells;
        private _checks = 0;
        {
            private _o = _x;
            if (!alive _o || { !(side _o in [east, resistance]) }) then { continue };
            private _k = hashValue _o;
            private _rec = CQ_magSeen getOrDefault [_k, []];
            if (_rec isNotEqualTo [] && { time - (_rec select 2) < CQ_magDetectEvery - 1 }) then { continue };   // another drone just saw it
            if (_checks >= 60) then { break };
            _checks = _checks + 1;
            if (([_v, "VIEW", _o] checkVisibility [_eye, aimPos _o]) < 0.2) then { continue };
            if (_rec isEqualTo []) then {
                private _c = [_o] call _cat;
                if (random 1 > (CQ_magSpotChance getOrDefault [_c, 0.3])) then { continue };   // not identified this pass
                CQ_magSeen set [_k, [_o, time, time, getPosATL _o, _c, false]];
                if ((typeOf _o) in CQ_magAaClasses) then { ["magAa", []] call CQ_fnc_say; ["MAGPIE: anti-air identified (%1) at %2", [typeOf _o, mapGridPosition _o]] call CQ_fnc_log };
            } else {
                _rec set [2, time];
                _rec set [3, getPosATL _o];
            };
        } forEach (_v nearEntities [["CAManBase", "LandVehicle", "Air", "StaticWeapon", "Ship"], _r]);
        // HQ sites
        {
            private _h = _y;
            if !((_h get "state") in CQ_activeStates) then { continue };
            if ((_h get "pos") distance2D _v > _r) then { continue };
            if !(terrainIntersectASL [_eye, AGLToASL ((_h get "pos") vectorAdd [0, 0, 3])]) then {
                private _id = _h get "id";
                if !(_id in CQ_magHqSeen) then { CQ_magHqSeen set [_id, -2] };   // -2: seen, not reported yet
                _h set ["magSeenStage", _h getOrDefault ["buildStage", 0]];
            };
        } forEach CQ_hqs;
    } forEach _flying;
    // forget the dead and the stale
    {
        private _r = CQ_magSeen get _x;
        if (!alive (_r select 0) || { time - (_r select 2) > CQ_magMemory * 2 }) then { CQ_magSeen deleteAt _x };
    } forEach (keys CQ_magSeen);
    // live picture for the players' maps: what a drone has in sight right now
    CQ_magVisible = ((values CQ_magSeen) select { time - (_x select 2) <= CQ_magDetectEvery + 2 }) apply { _x select 0 };
    publicVariable "CQ_magVisible";
};

// known anti-air (Tigris, AA statics) MAGPIE has seen recently: the drones keep CQ_magAaAvoid away
private _aa = ((values CQ_magSeen) select {
    time - (_x select 2) < CQ_magMemory && { alive (_x select 0) } && { (typeOf (_x select 0)) in CQ_magAaClasses }
}) apply { _x select 3 };
private _aaOk = { params ["_p"]; (_aa findIf { _x distance2D _p < CQ_magAaAvoid }) == -1 };
private _aaPush = {
    params ["_p"];
    {
        private _d = _x distance2D _p;
        if (_d < CQ_magAaAvoid) then { _p = _x getPos [CQ_magAaAvoid + 100, _x getDir _p]; _p = [_p select 0, _p select 1, 0] };
    } forEach _aa;
    _p
};

// ---- flight plans
private _known = [];
{ if (time - (_y select 2) < CQ_magMemory) then { _known pushBack (_y select 3) } } forEach CQ_magSeen;
{ if ((_x in CQ_magHqSeen) && { (_y get "state") in CQ_activeStates }) then { _known pushBack (_y get "pos") } } forEach CQ_hqs;
// ---- scan chain: a north-south line of Darters moving east, spread over the land
private _chain = _flying select { (_x getOrDefault ["role", ""]) == "chain" };
if (_chain isNotEqualTo []) then {
    // slots of the line at CQ_magChainX: land samples north-south, one slot per chain drone at
    // evenly spaced land samples (sea skipped), clear of the east coast and known anti-air
    private _slotsAt = {
        params ["_x0"];
        private _land = [];
        for "_y" from 200 to worldSize - 200 step 150 do {
            private _p = [_x0, _y, 0];
            if (!surfaceIsWater _p && { [_p] call CQ_magEastOk } && { [_p] call _aaOk }) then { _land pushBack _p };
        };
        if (_land isEqualTo []) exitWith { [] };
        private _n = CQ_magChainCount;
        private _out = [];
        for "_j" from 0 to _n - 1 do { _out pushBack (_land select (floor (((_j + 0.5) / _n) * count _land))) };
        _out
    };
    if (CQ_magChainSlots isEqualTo []) then { CQ_magChainSlots = [CQ_magChainX] call _slotsAt };
    // move on: 70 % of the chain in place, or the step timed out
    private _inPlace = { private _s = CQ_magChainSlots param [_x get "slot", []]; _s isNotEqualTo [] && { (_x get "veh") distance2D _s < 300 } } count _chain;
    if (_inPlace >= ceil (0.7 * count _chain) || { time - CQ_magChainT > CQ_magChainStepTime }) then {
        private _tries = 0;
        private _new = [];
        while { _new isEqualTo [] && { _tries < 60 } } do {
            CQ_magChainX = CQ_magChainX + CQ_magChainStep;
            if (CQ_magChainX > (CQ_magArea select 2)) then { CQ_magChainX = (CQ_basePos select 0) + 1000 };   // back to the west edge
            _new = [CQ_magChainX] call _slotsAt;
            _tries = _tries + 1;
        };
        if (_new isNotEqualTo []) then { CQ_magChainSlots = _new };
        CQ_magChainT = time;
        { _x set ["planT", -1e6] } forEach _chain;
        ["MAGPIE: scan chain moves to x %1 (%2 slots on land)", [round CQ_magChainX, count CQ_magChainSlots]] call CQ_fnc_log;
    };
    {
        private _m = _x;
        if (time - (_m get "planT") < 30) then { continue };
        _m set ["planT", time];
        private _s = CQ_magChainSlots param [_m get "slot", []];
        if (_s isEqualTo []) then { continue };
        private _v = _m get "veh";
        private _g = group effectiveCommander _v;
        while { (waypoints _g) isNotEqualTo [] } do { deleteWaypoint ((waypoints _g) select 0) };
        _v flyInHeight (_m get "alt");
        private _wp = _g addWaypoint [_s, 0];
        _wp setWaypointType "MOVE";
        _wp setWaypointCompletionRadius 150;
        _m set ["target", _s];
    } forEach _chain;
};

{
    private _m = _x;
    private _v = _m get "veh";
    if ((_m getOrDefault ["role", ""]) == "chain") then { continue };
    if (((getPosATL _v) select 2) < 40 && { time - (_m get "planT") < 300 }) then { continue };
    private _tgt = _m get "target";
    private _arrived = (_m get "explore") && { _tgt isNotEqualTo [] } && { _v distance2D _tgt < 500 };
    if (_arrived) then { { if ((_x select 0) isEqualTo _tgt) then { _x set [1, true] } } forEach CQ_magCells };
    if (time - (_m get "planT") < CQ_magPlanEvery && { !_arrived }) then { continue };
    _m set ["planT", time];
    private _i = _m get "i";
    private _explore = switch (_i) do {
        case 0: { count _known == 0 };
        case 1: { count _known < 3 || { CQ_magNewSince == 0 } };
        default { count _known < 3 || { !(_m get "explore") } };   // alternates
    };
    private _g = group effectiveCommander _v;
    while { (waypoints _g) isNotEqualTo [] } do { deleteWaypoint ((waypoints _g) select 0) };
    _v flyInHeight (_m get "alt");
    private _pts = [];
    if (_explore) then {
        private _taken = ((_flying select { (_x get "i") != _i }) apply { _x get "target" }) select { _x isNotEqualTo [] };
        private _free = CQ_magCells select { !(_x select 1) && { [_x select 0] call _aaOk } };
        if (_free isEqualTo []) then { { _x set [1, false] } forEach CQ_magCells; _free = CQ_magCells select { [_x select 0] call _aaOk } };   // all scanned: start over
        if (_free isEqualTo []) then { _free = +CQ_magCells };
        private _far = _free select { private _c = _x select 0; (_taken findIf { _x distance2D _c < 1500 }) == -1 };
        if (_far isNotEqualTo []) then { _free = _far };
        private _c = ([_free, [], { (_x select 0) distance2D _v }, "ASCEND"] call BIS_fnc_sortBy) select 0 select 0;
        _pts = [_c];
        _m set ["target", _c];
    } else {
        // ellipse around every known position (principal axes)
        private _n = count _known;
        private _mx = 0; private _my = 0;
        { _mx = _mx + (_x select 0); _my = _my + (_x select 1) } forEach _known;
        _mx = _mx / _n; _my = _my / _n;
        private _sxx = 0; private _syy = 0; private _sxy = 0;
        { private _dx = (_x select 0) - _mx; private _dy = (_x select 1) - _my; _sxx = _sxx + _dx * _dx; _syy = _syy + _dy * _dy; _sxy = _sxy + _dx * _dy } forEach _known;
        private _th = 0.5 * ((2 * _sxy) atan2 (_sxx - _syy));
        private _u = [cos _th, sin _th];
        private _w = [-(sin _th), cos _th];
        private _a = 0; private _b = 0;
        {
            private _dx = (_x select 0) - _mx; private _dy = (_x select 1) - _my;
            _a = _a max abs (_dx * (_u select 0) + _dy * (_u select 1));
            _b = _b max abs (_dx * (_w select 0) + _dy * (_w select 1));
        } forEach _known;
        private _sc = _m get "scale";
        private _margin = 300 + (_m get "alt") * 0.4;
        _a = ((_a + _margin) * _sc) max 500;
        _b = ((_b + _margin) * _sc) max 500;
        private _ctr = [_mx, _my, 0];
        private _off = random 36;
        for "_k" from 0 to 9 do {
            private _f = _off + _k * 36;
            private _p = [_mx + (_u select 0) * _a * cos _f + (_w select 0) * _b * sin _f,
                          _my + (_u select 1) * _a * cos _f + (_w select 1) * _b * sin _f, 0];
            private _tries = 0;
            while { !([_p] call CQ_magEastOk) && { _tries < 6 } } do {
                _p = _p vectorAdd ((_ctr vectorDiff _p) vectorMultiply 0.2);
                _tries = _tries + 1;
            };
            _p = [_p] call _aaPush;                       // stay out of known anti-air range
            if ([_p] call CQ_magEastOk && { [_p] call _aaOk }) then { _pts pushBack _p };
        };
        if (_pts isEqualTo []) then { _pts = [[_ctr] call _aaPush] };
        _m set ["target", _ctr];
    };
    _m set ["explore", _explore];
    { private _wp = _g addWaypoint [_x, 0]; _wp setWaypointType "MOVE"; _wp setWaypointCompletionRadius 300 } forEach _pts;
    if (count _pts > 1) then { (_g addWaypoint [_pts select 0, 0]) setWaypointType "CYCLE" };
    ["MAGPIE: %1 %2 (%3 waypoints, %4 known positions, %5 known AA, alt %6)", [_m get "name", ["orbits the known positions", "explores a new cell"] select _explore,
        count _pts, count _known, count _aa, _m get "alt"]] call CQ_fnc_log;
} forEach _flying;

// ---- report (every CQ_magReportEvery s, only when something is new)
// New identifications grouped by known AO (HQs MAGPIE has seen or that a captured commander
// revealed; nearest within CQ_magAoRange, else "outside known AOs"), counted in three kinds:
// infantry, vehicles (incl. statics), helicopters / aircraft. Shown as a small icon list on the
// MAGPIE card. HQ news (new position, construction stage) leads the card.
if (time - CQ_magReportT >= CQ_magReportEvery) then {
    CQ_magReportT = time;
    private _aos = (values CQ_hqs) select { (_x get "state") in CQ_activeStates && { (_x get "id") in CQ_magHqSeen || { _x getOrDefault ["revealed", false] } } };
    private _tab = createHashMap;            // AO name -> [inf, veh, air]
    private _order = [];
    private _new = 0;
    {
        if !(_y select 5) then {
            _y set [5, true];
            _new = _new + 1;
            private _p = _y select 3;
            private _ao = "Outside known AOs";
            private _best = CQ_magAoRange;
            { private _d = (_x get "pos") distance2D _p; if (_d < _best) then { _best = _d; _ao = [_x get "id"] call CQ_fnc_objName } } forEach _aos;
            if !(_ao in _tab) then { _tab set [_ao, [0, 0, 0]]; _order pushBack _ao };
            private _row = _tab get _ao;
            private _i = switch (_y select 4) do { case "inf": { 0 }; case "air": { 2 }; default { 1 } };
            _row set [_i, (_row select _i) + 1];
        };
    } forEach CQ_magSeen;
    private _news = [];
    {
        private _y = CQ_magHqSeen get _x;
        private _h = CQ_hqs getOrDefault [_x, createHashMap];
        if (count _h == 0) then { continue };
        private _st = _h getOrDefault ["magSeenStage", 0];
        if (_y == -2) then {
            _news pushBack format ["New enemy position: Objective %1.", [_x] call CQ_fnc_objName];
        } else {
            if (_st > _y) then {
                _news pushBack (if (_st >= 4) then { format ["%1 is fully operational.", [_x] call CQ_fnc_objName] }
                    else { format ["%1: construction, stage %2 of 4.", [_x] call CQ_fnc_objName, _st] });
            };
        };
        CQ_magHqSeen set [_x, _st];
    } forEach (keys CQ_magHqSeen);
    CQ_magNewSince = _new + count _news;
    // three empty reports in a row: she says so once
    CQ_magEmpty = if (CQ_magNewSince == 0) then { (missionNamespace getVariable ["CQ_magEmpty", 0]) + 1 } else { 0 };
    if (CQ_magEmpty == 3 && { ((CQ_mag select { alive (_x get "veh") }) isNotEqualTo []) }) then { ["magQuiet", []] call CQ_fnc_say };
    if (CQ_magNewSince > 0) then {
        // "outside known AOs" last
        private _out = "Outside known AOs";
        if (_out in _order) then { _order = (_order - [_out]) + [_out] };
        private _ico = [
            "\A3\ui_f\data\map\vehicleicons\iconMan_ca.paa",
            "\A3\ui_f\data\map\vehicleicons\iconCar_ca.paa",
            "\A3\ui_f\data\map\vehicleicons\iconHelicopter_ca.paa"
        ];
        private _rich = "<rich>";
        { _rich = _rich + format ["<br/><t size='0.8' color='#f2f2f2'>%1</t>", _x] } forEach _news;
        {
            private _row = _tab get _x;
            private _cells = "";
            { if ((_row select _forEachIndex) > 0) then { _cells = _cells + format ["   <img size='0.75' image='%1'/> %2", _x, _row select _forEachIndex] } } forEach _ico;
            _rich = _rich + format ["<br/><t size='0.78' font='PuristaMedium' color='#c8c8c8'>%1</t><t size='0.8' color='#ffffff'>%2</t>", _x, _cells];
        } forEach _order;
        ["magReport", [_rich]] call CQ_fnc_say;
        ["MAGPIE report: %1 new identifications, %2 HQ news, areas %3", [_new, count _news, _order]] call CQ_fnc_log;
    };
};
