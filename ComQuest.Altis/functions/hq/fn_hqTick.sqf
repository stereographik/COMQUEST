/*
    CQ_fnc_hqTick  (server, director task)
    - A holding HQ is destroyed when its commander is dead AND its supply depot is destroyed.
    - Victory once every root insertion has happened and no HQ is left alive.
*/
{
    private _hq = _y;
    if ((_hq get "state") == "Holding") then {
        if (!alive (_hq get "commander") && { !alive (_hq get "depot") }) then {
            _hq set ["state", "Destroyed"];
            { deleteMarker _x } forEach (_hq get "markers");
            ["Enemy HQ destroyed", format ["HQ #%1 has fallen. Enemy AI left on the map: %2", _hq get "id", call CQ_fnc_enemyCount]] call CQ_fnc_announce;
        };
    };
} forEach CQ_hqs;

if (isNil "CQ_victory" && { CQ_rootsLaunched >= CQ_maxRoots }) then {
    private _alive = (values CQ_hqs) findIf { (_x get "state") in ["Inbound", "Establishing", "Holding"] };
    if (_alive == -1) then {
        CQ_victory = true;
        ["VICTORY", format ["All %1 enemy insertions defeated, every HQ destroyed", CQ_maxRoots]] call CQ_fnc_announce;
        [] spawn { sleep 15; "EveryoneWon" call BIS_fnc_endMissionServer };
    };
};
