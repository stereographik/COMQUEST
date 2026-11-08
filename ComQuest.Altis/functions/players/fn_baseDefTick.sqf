/*
    CQ_fnc_baseDefTick  (server, director task, every 60 s)
    A base defence spot whose guns are destroyed or whose gunners are dead is rebuilt
    CQ_baseDefRespawn s later (never with a player standing on it).
*/
if (time < CQ_baseDefNext) exitWith {};
CQ_baseDefNext = time + 60;
{
    private _s = _x;
    private _guns = (_s get "objs") select { _x isKindOf "StaticWeapon" };
    private _ok = (_guns findIf { alive _x && { alive gunner _x } }) > -1;
    if (_ok) then { _s set ["lostT", -1]; continue };
    if ((_s get "lostT") < 0) then { _s set ["lostT", time]; continue };
    if (time - (_s get "lostT") > CQ_baseDefRespawn && { (allPlayers findIf { _x distance2D (_s get "pos") < 30 }) == -1 }) then {
        [_s] call CQ_fnc_baseDefBuild;
        ["Base defence spot at %1 rebuilt", [mapGridPosition (_s get "pos")]] call CQ_fnc_log;
    };
} forEach CQ_baseDefs;
