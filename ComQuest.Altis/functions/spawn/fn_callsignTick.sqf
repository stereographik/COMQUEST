/*
    CQ_fnc_callsignTick  (server, director task, every 10 s)
    Every enemy squad gets a callsign from CQ_enemyCallsigns. Names are recycled: a squad wiped
    out (or deleted) frees its name, and a new squad takes the first free name of the list. Only
    when every name is in use at once does a number appear ("Viper 2", then "Talon 2"...).
    Only groups still wearing the engine's default name ("Alpha 1-1") are renamed, so Spectre,
    the sniper teams and any other named group keep their names. Vehicle crews and static
    gunners keep theirs too: only groups whose leader is on foot or a passenger count as squads.
*/
if (time < (missionNamespace getVariable ["CQ_callsignNext", 0])) exitWith {};
CQ_callsignNext = time + 10;
if (isNil "CQ_callsignUsed") then { CQ_callsignUsed = createHashMap };   // name -> group

// free the names of squads that are gone
{
    if (isNull _y || { (units _y findIf { alive _x }) < 0 }) then { CQ_callsignUsed deleteAt _x };
} forEach +CQ_callsignUsed;

{
    private _g = _x;
    if (side _g != east || { (units _g findIf { alive _x }) < 0 }) then { continue };
    if !((groupId _g) regexMatch ".* [0-9]+-[0-9]+") then { continue };      // already named
    private _l = leader _g;
    private _v = vehicle _l;
    if (_v != _l && { _l in [driver _v, gunner _v, commander _v] }) then { continue };   // crew, not a squad
    // first free name of the list; if all are taken, the first free numbered one
    private _name = "";
    private _round = 1;
    while { _name == "" } do {
        {
            private _n = [_x, format ["%1 %2", _x, _round]] select (_round > 1);
            if !(_n in CQ_callsignUsed) exitWith { _name = _n };
        } forEach CQ_enemyCallsigns;
        _round = _round + 1;
    };
    CQ_callsignUsed set [_name, _g];
    _g setGroupIdGlobal [_name];
} forEach allGroups;
