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
                                drones (CQ_magDrones scale); Sentinel_Hermes alternates ellipse and
                                exploration, Sentinel_Argos explores when the last report was empty
      before MAGPIE's first contact the two Sentinels fly their search circuits instead
                                (CQ_magPatrol: shared trunk from the base, then a loop flown over and over)
    Report (every CQ_magReportEvery s, if anything is new): a MAGPIE card with the count of new
    identifications by kind and the HQ news, and dots on every player's map for 10 s. Every
    new vehicle identified is photographed by the drone (CQ_fnc_magPhoto) and the report shows
    the photos in a grid under the summary.
*/
if (time < CQ_magNext) exitWith {};
CQ_magNext = time + 5;
// keep the runway clear of anything placed after the start
if (time > (missionNamespace getVariable ["CQ_runwayClearT", 0])) then { CQ_runwayClearT = time + 60; false call CQ_fnc_runwayClear };

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

// ---- drones: spawn, loss, fuel
// Darters take off together from their pads in the UAV field. Fixed-wing drones come one at a
// time at their Eden-placed spot (CQ_magFixedSpawns), facing the placed direction: cleared at once with a
// waypoint down the runway and a 70 km/h rolling start (otherwise the AI taxis away to its own
// start point); the next one spawns once it is airborne (> 30 m). A lost drone comes back after
// CQ_magRespawn s.
CQ_magRunway params ["_rp", "_hdg"];
private _fixed = { !((_this get "cls") == "B_UAV_01_F" && { (_this getOrDefault ["pad", -1]) > -1 || { (_this getOrDefault ["role", ""]) == "dormant" } }) };
{
    private _m = _x;
    private _v = _m get "veh";
    if (!isNull _v && { !alive _v } && { !(_m get "lost") } && { (_m getOrDefault ["role", ""]) == "dormant" }) then {
        // a woken dormant Darter: no respawn on the field, the nearest point left replaces it (CQ_fnc_magDormant)
        _m set ["lost", true];
        _m set ["phase", "none"];
        _m set ["due", 1e12];
        CQ_magDormantDead pushBack [getPosATL _v, time];
        CQ_magVehs = (CQ_mag apply { _x get "veh" }) select { alive _x };
        publicVariable "CQ_magVehs";
        ["MAGPIE: %1 lost at %2, a dormant point nearby replaces it in %3 s", [_m get "name", mapGridPosition _v, CQ_magDormantReplace]] call CQ_fnc_log;
    };
    if ((_m getOrDefault ["role", ""]) == "dormant") then { if (alive _v && { fuel _v < 0.9 }) then { _v setFuel 1 }; continue };
    if (!isNull _v && { !alive _v } && { !(_m get "lost") }) then {
        _m set ["lost", true];
        _m set ["phase", "none"];
        _m set ["due", time + CQ_magRespawn];
        CQ_magVehs = (CQ_mag apply { _x get "veh" }) select { alive _x };
        publicVariable "CQ_magVehs";
        ["MAGPIE: %1 lost at %2, replacement in %3 s", [_m get "name", mapGridPosition _v, CQ_magRespawn]] call CQ_fnc_log;
        if ((_m get "name") find "Sentinel" == 0) then { ["magDown", [(_m get "name") splitString "_" joinString " ", round (CQ_magRespawn / 60)]] call CQ_fnc_say };
    };
    if ((isNull _v || { !alive _v }) && { time >= (_m get "due") }) then {
        private _quad = !(_m call _fixed);
        private _sp = [];
        if (_quad) then { _sp = CQ_magPads select (_m get "pad") } else {
            // fixed wing: one at a time, at the very start of the runway; the next one only
            // spawns once the previous one is airborne
            if ((CQ_mag findIf { (_x call _fixed) && { alive (_x get "veh") } && { (_x getOrDefault ["phase", ""]) in ["waiting", "rolling"] } }) > -1) then { _sp = [] } else {
                private _fs = CQ_magFixedSpawns getOrDefault [_m get "name", [_rp, _hdg]];
                _sp = _fs select 0;
                _m set ["hdg", _fs select 1];
            };
        };
        if (_sp isEqualTo []) then { continue };
        _sp = [_sp select 0, _sp select 1, 0];
        if (((nearestObjects [_sp, ["LandVehicle", "Air"], 4]) select { alive _x }) isNotEqualTo []) exitWith {};   // place busy
        private _nv = createVehicle [_m get "cls", _sp, [], 0, "CAN_COLLIDE"];
        _nv setDir ([_m getOrDefault ["hdg", _hdg], CQ_baseDir] select _quad);
        _nv setPosATL [_sp select 0, _sp select 1, 0.3];
        createVehicleCrew _nv;
        { _nv setPylonLoadout [_forEachIndex + 1, ""] } forEach (getPylonMagazines _nv);
        private _g = group effectiveCommander _nv;
        _g setGroupIdGlobal [format ["MAGPIE %1", _m get "name"]];
        _g setBehaviour "CARELESS";
        _g setCombatMode "BLUE";
        _nv flyInHeight (_m get "alt");
        _nv engineOn true;
        _nv setVariable ["CQ_magpie", true, true];
        _nv setVariable ["CQ_magName", _m get "name", true];
        _m set ["veh", _nv];
        _m set ["lost", false];
        _m set ["planT", time];
        if (_quad) then {
            (_g addWaypoint [_sp getPos [1500, CQ_baseDir], 0]) setWaypointType "MOVE";
            _m set ["phase", "rolling"];
            _m set ["rollT", time];
        } else {
            _m set ["phase", "waiting"];               // cleared for take-off just below
        };
        CQ_magVehs = (CQ_mag apply { _x get "veh" }) select { alive _x };
        publicVariable "CQ_magVehs";
        ["MAGPIE: %1 (%2) %3", [_m get "name", _m get "cls", if (_quad) then { format ["on pad %1 of the UAV field", _m get "pad"] } else { "at the start of the runway" }]] call CQ_fnc_log;
    };
    if (alive _v && { fuel _v < 0.9 }) then { _v setFuel 1 };
    // anti-stuck: on the ground and not moving for CQ_magStuckTime s -> a gentle push forward and a
    // fresh waypoint straight ahead (it may roll on the grass, that's fine)
    if (alive _v && { (_m getOrDefault ["phase", ""]) == "rolling" } && { !(_v isKindOf "Helicopter") } && { ((getPosATL _v) select 2) < 5 }) then {
        if (speed _v > 3) then { _m set ["moveT", time] };
        if (time - (_m getOrDefault ["moveT", _m get "rollT"]) > CQ_magStuckTime) then {
            _m set ["moveT", time];
            private _g = group effectiveCommander _v;
            [_g] call CQ_fnc_clearWaypoints;
            private _nw = _g addWaypoint [_v getPos [3000, getDir _v], 0];
            _nw setWaypointType "MOVE";
            _g setCurrentWaypoint _nw;
            _v engineOn true;
            _v setVelocityModelSpace [0, 12, 0];
            ["MAGPIE: %1 stuck on the ground, nudged forward", [_m get "name"]] call CQ_fnc_log;
        };
    };
    if (alive _v && { (_m getOrDefault ["phase", ""]) == "rolling" } && { ((getPosATL _v) select 2) > 30 }) then {
        _m set ["phase", "air"];
        _m set ["planT", -1e6];                             // first route right away
        ["MAGPIE: %1 airborne after %2 s", [_m get "name", round (time - (_m get "rollT"))]] call CQ_fnc_log;
        if ((_m get "name") find "Sentinel" == 0) then { ["magLaunch", [(_m get "name") splitString "_" joinString " "]] call CQ_fnc_say };
    };
} forEach CQ_mag;
// take-off clearance: the waiting drone nearest the take-off spot, once nobody is rolling
if ((CQ_mag findIf { (_x call _fixed) && { alive (_x get "veh") } && { (_x getOrDefault ["phase", ""]) == "rolling" } }) == -1) then {
    private _line = CQ_mag select { (_x call _fixed) && { alive (_x get "veh") } && { (_x getOrDefault ["phase", ""]) == "waiting" } };
    if (_line isNotEqualTo []) then {
        private _m = _line select 0;
        private _v = _m get "veh";
        private _h = _m getOrDefault ["hdg", _hdg];
        private _g = group effectiveCommander _v;
        [_g] call CQ_fnc_clearWaypoints;
        private _wp = _g addWaypoint [_v getPos [3000, _h], 0];
        _wp setWaypointType "MOVE";
        _g setCurrentWaypoint _wp;
        _v setDir _h;
        _v setVelocityModelSpace [0, 20, 0];       // already rolling down the runway: the AI takes off instead of taxiing away
        _m set ["phase", "rolling"];
        _m set ["rollT", time];
        _m set ["moveT", time];
        ["MAGPIE: %1 cleared for take-off", [_m get "name"]] call CQ_fnc_log;
    };
};

private _flying = CQ_mag select { alive (_x get "veh") && { (_x getOrDefault ["phase", ""]) == "air" } };

// ---- detection
// Sensor radius grows with altitude (CQ_magSensor). A new contact in line of sight is only
// identified with a chance per pass (CQ_magSpotChance by kind): it takes several passes to see
// everything. A contact already identified is tracked while it stays in line of sight: those
// are the live enemy positions every player sees on the map (CQ_magVisible).
// Data link (CQ_fnc_linkTick): a drone only reports while it is linked to the base through a chain
// of friendly nodes (overlapping ranges). Unlinked, it flies on and nothing it sees reaches us.
// During a crash-crate decryption everything gets through.
private _covered = { true };
// corridor outpost (CQ_fnc_outpostTick): its jammer hides everything around it; a drone within
// sensor range of it only learns that something is there (CQ_outpostState "spotted": the rough area)
private _opJam = missionNamespace getVariable ["CQ_opJam", false];
private _opPos = missionNamespace getVariable ["CQ_opJamPos", []];
if (time >= CQ_magDetectT) then {
    CQ_magDetectT = time + CQ_magDetectEvery;
    {
        private _v = _x get "veh";
        private _alt = (getPosATL _v) select 2;
        if (_alt < 40) then { continue };                 // still taking off
        if (!(_v getVariable ["CQ_linked", false]) && { time >= (missionNamespace getVariable ["CQ_decryptUntil", -1]) }) then { continue };   // no data link
        CQ_magSensor params ["_r0", "_rk", "_rmax"];
        private _r = (_r0 + _alt * _rk) min _rmax;
        private _eye = getPosASL _v vectorAdd [0, 0, -1.5];
        // search cells seen
        { if (!(_x select 1) && { (_x select 0) distance2D _v < _r * 0.8 }) then { _x set [1, true] } } forEach CQ_magCells;
        private _checks = 0;
        {
            private _o = _x;
            if (!alive _o || { !(side _o in [east, resistance]) }) then { continue };
            if (_o getVariable ["CQ_outpost", false] && { !isNil "CQ_outpostState" } && { !(CQ_outpostState get "spotted") } && { _o distance2D (CQ_outpostState get "pos") < 300 }) then {
                CQ_outpostState set ["spotted", true];
                ["MAGPIE: %1 picked up the corridor outpost (%2)", [_v getVariable ["CQ_magName", "a drone"], ["exact", "jammed: rough area only"] select _opJam]] call CQ_fnc_log;
            };
            if (_opJam && { _o distance2D _opPos < CQ_opJamRadius }) then { continue };      // jammed: nothing identified
            if !([_o] call _covered) then { continue };      // nGD: no data link out there, nothing identified
            private _k = hashValue _o;
            private _rec = CQ_magSeen getOrDefault [_k, []];
            if (_rec isNotEqualTo [] && { time - (_rec select 2) < CQ_magDetectEvery - 1 }) then { continue };   // another drone just saw it
            if (_checks >= CQ_magChecksPerPass) then { break };
            _checks = _checks + 1;
            if (([_v, "VIEW", _o] checkVisibility [_eye, aimPos _o]) < 0.2) then { continue };
            if (_rec isEqualTo []) then {
                private _c = [_o] call _cat;
                if (random 1 > ([CQ_magSpotChance getOrDefault [_c, 0.3], CQ_huntSpotChance] select (_o getVariable ["CQ_hunter", false]))) then { continue };   // not identified this pass
                CQ_magSeen set [_k, [_o, time, time, getPosATL _o, _c, false, [round getDir _o, round speed _o]]];   // + heading and speed when identified
                // a new vehicle: the drone takes its photo (rendered on every client) for the next report
                if (CQ_magPhotos && { count CQ_magPhotoPend < CQ_magPhotoMax }) then {
                    CQ_magPhotoN = CQ_magPhotoN + 1;
                    CQ_magPhotoPend pushBack [CQ_magPhotoN, typeOf _o];
                    ["shot", [CQ_magPhotoN, _o, _v]] remoteExec ["CQ_fnc_magPhoto", 0];
                };
                private _fp = missionNamespace getVariable ["CQ_magFocus", []];
                // the focus (and the end of the Sentinels' search circuits) needs a contact on the
                // ground: an insertion helicopter passing by is not a position to encircle
                if (_fp isEqualTo [] && { !(_o isKindOf "Air") || { ((getPosATL _o) select 2) < 5 } }) then {
                    CQ_magFocus = getPosATL _o; CQ_magFocusT = time; CQ_magFocusNew = time;
                    CQ_magContactMade = true;                       // the Sentinels leave their search circuits for good
                    { _x set ["planT", -1e6] } forEach CQ_mag;      // everyone re-routes now
                    ["magFocus", []] call CQ_fnc_say;
                    ["MAGPIE: first contact (%1) at %2, every drone encircles it", [typeOf _o, mapGridPosition _o]] call CQ_fnc_log;
                } else {
                    if (_fp isNotEqualTo [] && { _o distance2D _fp < (missionNamespace getVariable ["CQ_magRingR", CQ_magRingStart]) + 500 }) then { CQ_magFocusNew = time };
                };
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
            if !([_h get "pos"] call _covered) then { continue };
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
// the corridor outpost's Titans, once it is spotted: kept clear of like a Tigris (rough area while jammed)
if (!isNil "CQ_outpostState" && { CQ_outpostState get "spotted" } && { !(CQ_outpostState get "fallen") } && { ((CQ_outpostState get "aa") findIf { alive _x && { alive gunner _x } }) > -1 }) then {
    _aa pushBack (missionNamespace getVariable ["CQ_opMarkPos", CQ_outpostState get "pos"]);
};
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
// ---- encirclement: after the first contact, every airborne drone takes a sector of a ring around
// the focus; the ring turns (CQ_magRingTurn) so every sector is covered, and tightens from
// CQ_magRingStart to CQ_magRingMin. Known Tigris positions push the ring points out to
// CQ_magAaAvoid only (inside its missile range: a risk taken on purpose). Once tight and quiet for
// CQ_magFocusQuiet s, the focus jumps to the newest contact elsewhere, or is released.
private _focus = missionNamespace getVariable ["CQ_magFocus", []];
if (_focus isNotEqualTo [] && { CQ_magRingR <= CQ_magRingMin } && { time - CQ_magFocusNew > CQ_magFocusQuiet }) then {
    private _cand = (values CQ_magSeen) select { time - (_x select 1) < CQ_magFocusQuiet * 2 && { (_x select 3) distance2D _focus > CQ_magRingStart } };
    if (_cand isEqualTo []) then {
        CQ_magFocus = []; _focus = [];
        ["MAGPIE: focus area quiet, back to the sweep"] call CQ_fnc_log;
    } else {
        private _n = ([_cand, [], { _x select 1 }, "DESCEND"] call BIS_fnc_sortBy) select 0;
        CQ_magFocus = _n select 3; _focus = CQ_magFocus; CQ_magFocusT = time; CQ_magFocusNew = time;
        { _x set ["planT", -1e6] } forEach CQ_mag;
        ["magFocus", []] call CQ_fnc_say;
        ["MAGPIE: focus moves to the newest contact at %1", [mapGridPosition _focus]] call CQ_fnc_log;
    };
};
// ---- the centre of the encirclement follows the situation (every CQ_magCentreEvery s):
//   1 the first ground contact (set when it is identified)
//   2 the barycentre of the largest group of ground positions identified in the last
//     CQ_magMemory s within CQ_magRingStart of the focus (groups: CQ_magClusterR)
//   3 the radio tower of the enemy HQ in the area, as soon as it is built
// The drones re-route when the centre moves more than CQ_magCentreMove m.
if (_focus isNotEqualTo [] && { time - (missionNamespace getVariable ["CQ_magCentreT", -1e6]) > CQ_magCentreEvery }) then {
    CQ_magCentreT = time;
    private _new = [];
    private _why = "";
    private _tw = ((values CQ_hqs) select { (_x get "state") in CQ_activeStates && { alive (_x getOrDefault ["radio", objNull]) } && { (_x get "pos") distance2D _focus < CQ_magRingStart } })
        apply { _x get "radio" };
    if (_tw isNotEqualTo []) then {
        _new = getPosATL (([_tw, [], { _x distance2D _focus }, "ASCEND"] call BIS_fnc_sortBy) select 0);
        _why = "radio tower";
    } else {
        private _pts = ((values CQ_magSeen) select { time - (_x select 2) < CQ_magMemory && { (_x select 4) != "air" } && { (_x select 3) distance2D _focus < CQ_magRingStart } }) apply { _x select 3 };
        private _best = [];
        { private _c = _x; private _grp = _pts select { _x distance2D _c < CQ_magClusterR }; if (count _grp > count _best) then { _best = _grp } } forEach _pts;
        if (count _best >= 2) then {
            private _sx = 0; private _sy = 0;
            { _sx = _sx + (_x select 0); _sy = _sy + (_x select 1) } forEach _best;
            _new = [_sx / count _best, _sy / count _best, 0];
            _why = format ["largest group (%1 positions)", count _best];
        };
    };
    if (_new isNotEqualTo [] && { _new distance2D _focus > CQ_magCentreMove }) then {
        private _moved = round (_new distance2D _focus);
        CQ_magFocus = _new; _focus = _new;
        { _x set ["planT", -1e6] } forEach CQ_mag;
        ["MAGPIE: encirclement centre moves %1 m to the %2 at %3", [_moved, _why, mapGridPosition _new]] call CQ_fnc_log;
    };
};
private _focusOn = _focus isNotEqualTo [];
if (_focusOn) then {
    _focus = [_focus select 0, _focus select 1, 0];
    CQ_magRingR = (CQ_magRingStart - CQ_magRingShrink * (time - CQ_magFocusT) / 60) max CQ_magRingMin;
    private _ring = [_flying select { !(_x getOrDefault ["flee", false]) }, [], { _x get "i" }, "ASCEND"] call BIS_fnc_sortBy;   // a woken Darter getting away joins once clear
    private _n = count _ring;
    private _step = 360 / (_n max 1);
    private _rot = (time - CQ_magFocusT) * CQ_magRingTurn;
    {
        private _m = _x;
        if (time - (_m get "planT") < 30) then { continue };
        _m set ["planT", time];
        private _v = _m get "veh";
        private _r = CQ_magRingR * ((_m get "scale") max 1);
        // fixed wings (the Sentinels): a loiter circle around the contact whose radius
        // oscillates (CQ_magOsc) as it is renewed every 30 s; kept CQ_magAaAvoid clear of a
        // known Tigris near the focus by widening the circle
        if (_m call _fixed) then {
            CQ_magOsc params ["_amp", "_period"];
            private _R = _r * (1 + _amp * sin (360 * (time - CQ_magFocusT) / _period + _forEachIndex * 120));
            { private _d = _x distance2D _focus; if (abs (_R - _d) < CQ_magAaAvoid) then { _R = _R max (_d + CQ_magAaAvoid) } } forEach _aa;
            private _g = group effectiveCommander _v;
            [_g] call CQ_fnc_clearWaypoints;
            _v flyInHeight (_m get "alt");
            private _wp = _g addWaypoint [_focus, 0];
            _wp setWaypointType "LOITER";
            _wp setWaypointLoiterType "CIRCLE_L";
            _wp setWaypointLoiterRadius _R;
            _g setCurrentWaypoint _wp;
            _m set ["target", _focus];
            if ((_m getOrDefault ["patrolVeh", objNull]) == _v && { !(_m getOrDefault ["patrolLeft", false]) }) then {
                _m set ["patrolLeft", true];
                ["MAGPIE: %1 leaves its search circuit, loiters around the contact at %2 (radius %3 m)", [_m get "name", mapGridPosition _focus, round _R]] call CQ_fnc_log;
            };
            if (time - (_m getOrDefault ["loiterLogT", -1e6]) > 120) then {
                _m set ["loiterLogT", time];
                if (CQ_logVerbose) then { ["MAGPIE: %1 loiters around the contact at %2, radius %3 m", [_m get "name", mapGridPosition _focus, round _R]] call CQ_fnc_log };
            };
            continue;
        };
        private _a0 = _rot + _forEachIndex * _step;
        private _pts = [];
        {
            private _p = _focus getPos [_r, _a0 + _x * _step];
            _p = [_p select 0, _p select 1, 0];
            private _t = 0;
            while { !([_p] call CQ_magEastOk) && { _t < 6 } } do { _p = _p vectorAdd ((_focus vectorDiff _p) vectorMultiply 0.2); _t = _t + 1 };
            _p = [_p] call _aaPush;
            if ([_p] call CQ_magEastOk) then { _pts pushBack _p };
        } forEach [0, 0.5, 1];
        if (_pts isEqualTo []) then { continue };
        private _g = group effectiveCommander _v;
        [_g] call CQ_fnc_clearWaypoints;
        _v flyInHeight (_m get "alt");
        private _first = -1;
        { private _wp = _g addWaypoint [_x, 0]; _wp setWaypointType "MOVE"; _wp setWaypointCompletionRadius 200; if (_first < 0) then { _first = _wp select 1 } } forEach _pts;
        _g setCurrentWaypoint [_g, _first];
        _m set ["target", _pts select 0];
    } forEach _ring;
    if (time - (missionNamespace getVariable ["CQ_magRingLogT", -1e6]) > 60) then {
        CQ_magRingLogT = time;
        if (CQ_logVerbose) then { ["MAGPIE: %1 drones encircle %2, ring %3 m, %4 known Tigris", [_n, mapGridPosition _focus, round CQ_magRingR, count _aa]] call CQ_fnc_log };
    };
};

// ---- scan chain: a north-south line of Darters moving east, spread over the land
private _chain = _flying select { (_x getOrDefault ["role", ""]) == "chain" };
if (_chain isNotEqualTo [] && { !_focusOn }) then {
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
        if (CQ_logVerbose) then { ["MAGPIE: scan chain moves to x %1 (%2 slots on land)", [round CQ_magChainX, count CQ_magChainSlots]] call CQ_fnc_log };
    };
    {
        private _m = _x;
        if (time - (_m get "planT") < 30) then { continue };
        _m set ["planT", time];
        private _s = CQ_magChainSlots param [_m get "slot", []];
        if (_s isEqualTo []) then { continue };
        private _v = _m get "veh";
        private _g = group effectiveCommander _v;
        [_g] call CQ_fnc_clearWaypoints;
        _v flyInHeight (_m get "alt");
        private _wp = _g addWaypoint [_s, 0];
        _wp setWaypointType "MOVE";
        _wp setWaypointCompletionRadius 150;
        _g setCurrentWaypoint _wp;
        _m set ["target", _s];
    } forEach _chain;
};

{
    private _m = _x;
    private _v = _m get "veh";
    if (_focusOn || { (_m getOrDefault ["role", ""]) == "chain" } || { _m getOrDefault ["flee", false] }) then { continue };
    if (((getPosATL _v) select 2) < 40 && { time - (_m get "planT") < 300 }) then { continue };
    private _tgt = _m get "target";
    private _arrived = (_m get "explore") && { _tgt isNotEqualTo [] } && { _v distance2D _tgt < 500 };
    if (_arrived) then { { if ((_x select 0) isEqualTo _tgt) then { _x set [1, true] } } forEach CQ_magCells };
    private _gr = group effectiveCommander _v;
    if (currentWaypoint _gr >= count waypoints _gr) then { _arrived = true };   // route flown: new one now
    // search circuit until the first contact: trunk + loop the first time, then the loop again
    // each time it is flown (a replacement drone starts from the trunk again)
    private _route = CQ_magPatrol getOrDefault [_m get "name", []];
    // TEST OVERRIDE (CQ_testMagDirect, test branches only): before the first contact the two
    // Sentinels skip their search circuits and loiter straight over the first enemy HQ site
    // (known as soon as the insertion is planned)
    if (CQ_testMagDirect && { _route isNotEqualTo [] } && { isNil "CQ_magContactMade" }) then {
        private _hs = [(values CQ_hqs) select { (_x get "state") in CQ_activeStates }, [], { _x get "id" }] call BIS_fnc_sortBy;
        if (_hs isEqualTo []) exitWith {};
        private _h = _hs select 0;
        if ((_m getOrDefault ["directHq", -1]) == (_h get "id") && { (_m getOrDefault ["patrolVeh", objNull]) == _v }) exitWith { _route = [] };
        _m set ["directHq", _h get "id"];
        _m set ["patrolVeh", _v];
        _m set ["planT", time];
        [_gr] call CQ_fnc_clearWaypoints;
        _v flyInHeight (_m get "alt");
        private _wp = _gr addWaypoint [_h get "pos", 0];
        _wp setWaypointType "LOITER";
        _wp setWaypointLoiterType "CIRCLE_L";
        _wp setWaypointLoiterRadius (800 * (_m get "scale"));
        _gr setCurrentWaypoint _wp;
        _route = [];
        ["MAGPIE TEST: %1 flies straight to %2 at %3", [_m get "name", [_h get "id"] call CQ_fnc_objName, mapGridPosition (_h get "pos")]] call CQ_fnc_log;
    };
    if (CQ_testMagDirect && { _route isEqualTo [] } && { isNil "CQ_magContactMade" } && { (_m getOrDefault ["directHq", -1]) > -1 }) then { continue };
    if (_route isNotEqualTo [] && { isNil "CQ_magContactMade" }) then {
        private _on = (_m getOrDefault ["patrolVeh", objNull]) == _v;
        if (_on && { currentWaypoint _gr < count waypoints _gr }) then { continue };
        _route params ["_trunk", "_loop"];
        private _pts = if (_on) then { _loop } else { _trunk + _loop };
        _m set ["patrolVeh", _v];
        _m set ["planT", time];
        _m set ["explore", false];
        _m set ["target", []];
        [_gr] call CQ_fnc_clearWaypoints;
        _v flyInHeight (_m get "alt");
        private _first = -1;
        { private _wp = _gr addWaypoint [[_x select 0, _x select 1, 0], 0]; _wp setWaypointType "MOVE"; _wp setWaypointCompletionRadius 400; if (_first < 0) then { _first = _wp select 1 } } forEach _pts;
        if (_first >= 0) then { _gr setCurrentWaypoint [_gr, _first] };
        ["MAGPIE: %1 %2 its search circuit (%3 points)", [_m get "name", ["starts", "loops"] select _on, count _pts]] call CQ_fnc_log;
        continue;
    };
    if (time - (_m get "planT") < CQ_magPlanEvery && { !_arrived }) then { continue };
    _m set ["planT", time];
    private _i = _m get "i";
    private _explore = switch (_i) do {
        case 0: { count _known == 0 };
        case 1: { count _known < 3 || { CQ_magNewSince == 0 } };
        default { count _known < 3 || { !(_m get "explore") } };   // alternates
    };
    private _g = group effectiveCommander _v;
    [_g] call CQ_fnc_clearWaypoints;
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
    private _first = -1;
    { private _wp = _g addWaypoint [_x, 0]; _wp setWaypointType "MOVE"; _wp setWaypointCompletionRadius 300; if (_first < 0) then { _first = _wp select 1 } } forEach _pts;
    if (_first >= 0) then { _g setCurrentWaypoint [_g, _first] };     // start the new route at its first point
    if (CQ_logVerbose) then {
    ["MAGPIE: %1 %2 (%3 waypoints, %4 known positions, %5 known AA, alt %6)", [_m get "name", ["orbits the known positions", "explores a new cell"] select _explore,
        count _pts, count _known, count _aa, _m get "alt"]] call CQ_fnc_log;
    };
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
            _news pushBack format ["New enemy position: %1.", [_x] call CQ_fnc_objName];
        } else {
            if (_st > _y) then {
                _news pushBack (if (_st >= 6) then { format ["%1 is fully operational.", [_x] call CQ_fnc_objName] }
                    else { format ["%1: construction, stage %2 of 6.", [_x] call CQ_fnc_objName, _st] });
            };
        };
        CQ_magHqSeen set [_x, _st];
    } forEach (keys CQ_magHqSeen);
    CQ_magNewSince = _new + count _news;
    // three empty reports in a row: she says so once
    CQ_magEmpty = if (CQ_magNewSince == 0) then { (missionNamespace getVariable ["CQ_magEmpty", 0]) + 1 } else { 0 };
    // MAGPIE only speaks about enemies she tracks (reports, first contact, AA): no word on her own drones
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
        { _rich = _rich + format ["<br/><t size='0.8' color='#F2F1DF'>%1</t>", _x] } forEach _news;
        {
            private _row = _tab get _x;
            private _cells = "";
            { if ((_row select _forEachIndex) > 0) then { _cells = _cells + format ["   <img size='0.75' image='%1'/> %2", _x, _row select _forEachIndex] } } forEach _ico;
            _rich = _rich + format ["<br/><t size='0.78' font='PuristaMedium' color='#A6A381'>%1</t><t size='0.8' color='#F2F1DF'>%2</t>", _x, _cells];
        } forEach _order;
        // every enemy vehicle identified and still alive, by GROUND / AIR:
        // [type] [hdg:heading when spotted] [spd:speed when spotted]
        private _vehs = (values CQ_magSeen) select { alive (_x select 0) && { (_x select 4) != "inf" } };
        _vehs = [_vehs, [], { _x select 1 }] call BIS_fnc_sortBy;
        {
            _x params ["_title", "_list"];
            if (_list isEqualTo []) then { continue };
            _rich = _rich + format ["<br/><t size='0.72' font='PuristaMedium' color='#918C3B'>%1 (%2)</t>", _title, count _list];
            {
                (_x param [6, [0, 0]]) params ["_hdg", "_spd"];
                private _h = str (_hdg mod 360);
                while { count _h < 3 } do { _h = "0" + _h };     // 3 digits: 045
                _rich = _rich + format ["<br/><t size='0.72' color='#F2F1DF'>[%1] </t><t size='0.72' color='#A6A381'>[hdg:%2] [spd:%3 km/h]</t>",
                    getText (configOf (_x select 0) >> "displayName"), _h, _spd];
            } forEach (_list select [0, CQ_magReportVehMax]);
            if (count _list > CQ_magReportVehMax) then { _rich = _rich + format ["<br/><t size='0.7' color='#A6A381'>+%1 more</t>", count _list - CQ_magReportVehMax] };
        } forEach [
            ["GROUND", _vehs select { (_x select 4) != "air" }],
            ["AIR", _vehs select { (_x select 4) == "air" }]
        ];
        // photo grid under the report: "<ph>id:class,...</ph>" (read by CQ_fnc_storyClient)
        if (CQ_magPhotoPend isNotEqualTo []) then {
            _rich = _rich + "<ph>" + ((CQ_magPhotoPend apply { format ["%1:%2", _x select 0, _x select 1] }) joinString ",") + "</ph>";
            CQ_magPhotoPend = [];
        };
        ["magReport", [_rich]] call CQ_fnc_say;
        ["MAGPIE report: %1 new identifications, %2 HQ news, areas %3", [_new, count _news, _order]] call CQ_fnc_log;
    };
};
