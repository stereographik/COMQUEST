/*
    CQ_fnc_huntLaunch  (server, spawned; from CQ_fnc_hqNerves when an HQ turns ALARMED)
    [_hq] spawn CQ_fnc_huntLaunch;
    HUNTERS: a CSAT special forces team (CQ_huntClasses: recon, suppressed, NVGs, high skill)
    sent after the player squad that is hurting the HQ. One team alive at a time, CQ_huntTeams
    per carrier (not shown on the carrier marker).
      target   the squad of whoever destroyed the HQ's last objective, else the player group
               nearest to the HQ
      arrival  HALO: out of the carrier's aircraft at CQ_huntHaloAlt, chute opened at
               CQ_huntChuteAlt, landing scattered CQ_huntDropDist from the target, regroup
      hunt     every CQ_huntUpdate s the target squad's position +/- CQ_huntFuzz (exact when
               the team already knows one of them); stealth, ambush when close
      end      target wiped or CQ_huntTime s: the team patrols the WESTERN-most HQ (any stage,
               as soon as a site is designated), always on the front line
    MAGPIE: CQ_huntSpotChance to identify one, never on the heatmap before they fire.
    Wiped out: CQ_huntBounty squad points to the squad that killed the last one.
*/
params ["_hq"];
if (!isNull (missionNamespace getVariable ["CQ_huntGroup", grpNull]) && { ({ alive _x } count units CQ_huntGroup) > 0 }) exitWith {};
private _left = missionNamespace getVariable ["CQ_huntLeft", CQ_huntTeams];
if (_left <= 0) exitWith {};
CQ_huntLeft = _left - 1;
private _id = _hq get "id";
private _c = _hq get "pos";

// ---- target squad
private _playerGroups = { (allPlayers select { alive _x && { side group _x == west } }) apply { group _x } };
private _tg = grpNull;
private _k = _hq getOrDefault ["lastKiller", objNull];
if (!isNull _k && { isPlayer _k }) then { _tg = group _k };
if (isNull _tg) then {
    private _gs = call _playerGroups;
    if (_gs isNotEqualTo []) then { _tg = ([_gs, [], { leader _x distance2D _c }, "ASCEND"] call BIS_fnc_sortBy) select 0 };
};
if (isNull _tg) exitWith { CQ_huntLeft = _left; ["HUNTERS: no player squad to hunt for HQ #%1", [_id]] call CQ_fnc_log };
private _tpos = {
    private _alive = (units _tg) select { alive _x };
    if (_alive isEqualTo []) exitWith { [] };
    private _u = _alive select 0;
    if ((units CQ_huntGroup) findIf { alive _x && { (_x knowsAbout _u) > 1.5 } } > -1) exitWith { getPosATL _u };
    (getPosATL _u) getPos [random CQ_huntFuzz, random 360]
};

// ---- HALO
private _cls = CQ_huntClasses apply {
    private _cfg = configFile >> "CfgVehicles" >> _x;
    [_x, "O_Soldier_F"] select !(isClass _cfg && { getText (_cfg >> "DLC") == "" })
};
private _g = createGroup [east, true];
CQ_huntGroup = _g;
_g setGroupIdGlobal ["Spectre"];
private _lz = (getPosATL leader _tg) getPos [(CQ_huntDropDist select 0) + random ((CQ_huntDropDist select 1) - (CQ_huntDropDist select 0)), random 360];
private _t = 0;
while { surfaceIsWater _lz && { _t < 20 } } do { _lz = (getPosATL leader _tg) getPos [(CQ_huntDropDist select 0) + random 800, random 360]; _t = _t + 1 };
{
    private _u = _g createUnit [_x, [0, 0, 0], [], 0, "NONE"];
    [[_u]] call CQ_fnc_unitPrep;
    _u setSkill 0.85;
    _u setVariable ["CQ_hunter", true];
    _u setVariable ["CQ_hunterHidden", true];
    private _p = _lz getPos [random 250, random 360];
    _u setPosATL [_p select 0, _p select 1, CQ_huntHaloAlt + random 80];
    _u addEventHandler ["FiredMan", {
        params ["_u"];
        { _x setVariable ["CQ_hunterHidden", false] } forEach units group _u;
        if !(group _u getVariable ["CQ_huntContact", false]) then {
            group _u setVariable ["CQ_huntContact", true];
            ["huntContact", []] call CQ_fnc_say;
            ["HUNTERS: first contact at grid %1", [mapGridPosition _u]] call CQ_fnc_log;
        };
    }];
    _u addEventHandler ["Killed", {
        params ["_u", "_k", "_i"];
        private _who = [_i, _k] select (isNull _i);
        if (({ alive _x } count units group _u) > 0) exitWith {};
        ["HUNTERS: team wiped out (last one at grid %1)", [mapGridPosition _u]] call CQ_fnc_log;
        ["huntDown", []] call CQ_fnc_say;
        ["spectre", _who] call CQ_fnc_opEvent;
        if (!isNull _who && { isPlayer _who }) then {
            private _pg = group _who;
            if !(_pg getVariable ["CQ_solo", true]) then { _pg setVariable ["CQ_sqPts", (_pg getVariable ["CQ_sqPts", 0]) + CQ_huntBounty, true]; _pg setVariable ["CQ_sqScore", (_pg getVariable ["CQ_sqScore", 0]) + CQ_huntBounty, true] };
            [_who, CQ_huntBounty, "special forces team"] call CQ_fnc_scoreAdd;
        };
    }];
    // free fall, chute opened low, kit restored on the ground
    [_u] spawn {
        params ["_u"];
        private _kit = getUnitLoadout _u;
        waitUntil { sleep 0.5; !alive _u || { ((getPosATL _u) select 2) < CQ_huntChuteAlt } };
        if (!alive _u) exitWith {};
        private _ch = createVehicle ["Steerable_Parachute_F", getPosATL _u, [], 0, "CAN_COLLIDE"];
        _ch setPosATL getPosATL _u;
        _u moveInDriver _ch;
        waitUntil { sleep 1; !alive _u || { isTouchingGround _u } || { vehicle _u == _u } };
        if (alive _u) then { _u setUnitLoadout _kit };
    };
} forEach _cls;
_g setBehaviour "STEALTH";
_g setCombatMode "RED";
_g setSpeedMode "NORMAL";
_g enableDynamicSimulation false;
["huntLaunch", [[_id] call CQ_fnc_objName], _hq] call CQ_fnc_say;
["HUNTERS (team %1/%2) HALO near grid %3, hunting %4 (for HQ #%5)", [CQ_huntTeams - CQ_huntLeft, CQ_huntTeams, mapGridPosition _lz, groupId _tg, _id]] call CQ_fnc_log;

// ---- regroup on the ground
private _t0 = time;
waitUntil { sleep 3; ({ alive _x } count units _g) == 0 || { ((units _g) findIf { alive _x && { vehicle _x != _x || { ((getPosATL _x) select 2) > 3 } } }) == -1 } || { time - _t0 > 180 } };
_g move (getPosATL leader _g);
sleep 20;

// ---- hunt
private _start = time;
while { ({ alive _x } count units _g) > 0 && { time - _start < CQ_huntTime } } do {
    private _p = call _tpos;
    if (_p isEqualTo []) exitWith { ["HUNTERS: target squad %1 wiped out", [groupId _tg]] call CQ_fnc_log };
    [_g] call CQ_fnc_clearWaypoints;
    if (leader _g distance2D _p < 350) then {
        // ambush: go to ground facing them, hold a while
        _g setBehaviour "COMBAT";
        { _x setUnitPos "MIDDLE"; _x doWatch _p } forEach units _g;
        doStop (units _g);
        sleep 60;
        { _x setUnitPos "AUTO" } forEach units _g;
        _g setBehaviour "STEALTH";
    } else {
        private _wp = _g addWaypoint [_p, 0];
        _wp setWaypointType "MOVE";
        _wp setWaypointSpeed "NORMAL";
        sleep ((CQ_huntUpdate select 0) + random ((CQ_huntUpdate select 1) - (CQ_huntUpdate select 0)));
    };
};

// ---- front line: patrol the western-most HQ (any stage)
private _home = [];
while { ({ alive _x } count units _g) > 0 } do {
    private _hs = (values CQ_hqs) select { (_x get "state") in CQ_activeStates };
    if (_hs isNotEqualTo []) then {
        private _w = ([_hs, [], { (_x get "pos") select 0 }, "ASCEND"] call BIS_fnc_sortBy) select 0;
        if !((_w get "pos") isEqualTo _home) then {
            _home = _w get "pos";
            [_g] call CQ_fnc_clearWaypoints;
            [_g, _home, CQ_huntPatrolR] call CQ_fnc_infPatrol;
            _g setBehaviour "STEALTH";
            ["HUNTERS: front-line patrol around HQ #%1 (grid %2)", [_w get "id", mapGridPosition _home]] call CQ_fnc_log;
        };
    };
    sleep 120;
};
