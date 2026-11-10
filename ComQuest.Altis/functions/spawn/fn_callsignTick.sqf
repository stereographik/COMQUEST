/*
    CQ_fnc_callsignTick  (server, director task, every 10 s)
    Every enemy squad gets a callsign from CQ_enemyCallsigns (in order, each used once; when
    all are taken the list starts again with a number: "Butcher 2"). Only groups still wearing
    the engine's default name ("Alpha 1-1") are renamed, so Spectre, the sniper teams and any
    other named group keep their names. Vehicle crews and static gunners keep theirs too: only
    groups whose leader is on foot or a passenger count as squads.
*/
if (time < (missionNamespace getVariable ["CQ_callsignNext", 0])) exitWith {};
CQ_callsignNext = time + 10;
if (isNil "CQ_callsignN") then { CQ_callsignN = 0 };
{
    private _g = _x;
    if (side _g != east || { (units _g findIf { alive _x }) < 0 }) then { continue };
    if !((groupId _g) regexMatch ".* [0-9]+-[0-9]+") then { continue };      // already named
    private _l = leader _g;
    private _v = vehicle _l;
    if (_v != _l && { _l in [driver _v, gunner _v, commander _v] }) then { continue };   // crew, not a squad
    private _n = count CQ_enemyCallsigns;
    private _name = CQ_enemyCallsigns select (CQ_callsignN mod _n);
    private _round = floor (CQ_callsignN / _n);
    if (_round > 0) then { _name = format ["%1 %2", _name, _round + 1] };
    CQ_callsignN = CQ_callsignN + 1;
    _g setGroupIdGlobal [_name];
} forEach allGroups;
