/*
    CQ_fnc_traceTick  (server, director task)
    Every CQ_traceEvery s: where each group on the ground is (its leader, or the vehicle he rides).
    A point is added when the group moved CQ_traceStep m since its last one. Aircraft and boats
    are left out. Friendlies = west, enemies = east / independent.
      CQ_trace: hashmap group trace id -> [side (0 friendly, 1 enemy), [[x, y, time], ...]]
    Shown at the end of the game: the DEBRIEF's MAP tab (CQ_fnc_endgame packs it, CQ_fnc_endgameUi
    draws each trace white -> blue (friendlies) or black -> red (enemies) over the whole game, with
    a slider to replay it).
*/
if (time < (missionNamespace getVariable ["CQ_traceNext", 0])) exitWith {};
CQ_traceNext = time + CQ_traceEvery;
if (isNil "CQ_trace") then { CQ_trace = createHashMap; CQ_traceN = 0 };
private _t = round time;
{
    private _g = _x;
    private _s = side _g;
    private _sd = -1;
    if (_s == west) then { _sd = 0 };
    if (_s in [east, resistance]) then { _sd = 1 };
    private _l = leader _g;
    if (_sd >= 0 && { alive _l }) then {
        private _v = vehicle _l;
        if (!(_v isKindOf "Air") && { !(_v isKindOf "Ship") } && { ((getPosATL _v) select 2) < 30 }) then {
            private _id = _g getVariable ["CQ_trId", -1];
            if (_id < 0) then { CQ_traceN = CQ_traceN + 1; _id = CQ_traceN; _g setVariable ["CQ_trId", _id]; CQ_trace set [_id, [_sd, []]] };
            private _pts = (CQ_trace get _id) select 1;
            private _p = getPosATL _v;
            if (_pts isEqualTo [] || { ((_pts select (count _pts - 1)) distance2D _p) >= CQ_traceStep }) then { _pts pushBack [round (_p select 0), round (_p select 1), _t] };
        };
    };
} forEach allGroups;
