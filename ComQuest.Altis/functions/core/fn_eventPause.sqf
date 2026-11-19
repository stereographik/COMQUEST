/*
    CQ_fnc_eventPause  (server, director task "eventPause")
    Event AI that waits in place (EMP guards, crash site, hostage takers: groups with CQ_eventPause)
    is frozen, men and their vehicles (simulation off, no CPU), while no player is within
    CQ_eventPauseR m of its leader; it wakes up as soon as one comes closer.
    Hunters and the sabotage team are not paused: they travel to the players.
*/
{
    private _g = _x;
    if (!(_g getVariable ["CQ_eventPause", false]) || { (units _g) isEqualTo [] }) then { continue };
    private _l = leader _g;
    private _far = (allPlayers findIf { alive _x && { _x distance2D _l < CQ_eventPauseR } }) == -1;
    if (_far isEqualTo (_g getVariable ["CQ_paused", false])) then { continue };
    _g setVariable ["CQ_paused", _far];
    private _objs = [];
    { _objs pushBackUnique _x; if (vehicle _x != _x) then { _objs pushBackUnique (vehicle _x) } } forEach units _g;
    { _x enableSimulationGlobal !_far } forEach _objs;
    ["Event %1: %2 (%3 men)", [groupId _g, ["awake, a player is near", "paused, no player within " + str CQ_eventPauseR + " m"] select _far, count units _g]] call CQ_fnc_log;
} forEach (groups east);
