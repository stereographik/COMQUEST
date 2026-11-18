/*
    CQ_fnc_hqFireWatch  (server, once at start)
    Enemy fire in an HQ's area (CQ_secureRadius m) resets its calm timer ("lastFireT"): an HQ splits
    only after CQ_splitAge s with no enemy shot there (CQ_fnc_hqSplit, CQ_fnc_hqTick).
    Every projectile fired by a CSAT unit local to the server (its AI) is checked, at most once a
    second (the check itself is cheap).
*/
if (!isServer) exitWith {};
CQ_fireChkNext = 0;
CQ_fireWatchEH = addMissionEventHandler ["ProjectileCreated", {
    params ["_proj"];
    if (diag_tickTime < CQ_fireChkNext) exitWith {};
    (getShotParents _proj) params [["_v", objNull], ["_who", objNull]];
    private _u = [_who, _v] select (isNull _who);
    if (isNull _u || { side group _u != east }) exitWith {};
    CQ_fireChkNext = diag_tickTime + 1;
    private _p = getPosATL _u;
    {
        if ((_y get "buildDone") && { (_y get "pos") distance2D _p < CQ_secureRadius }) then { _y set ["lastFireT", time] };
    } forEach CQ_hqs;
}];
["HQ fire watch %3: enemy fire within %1 m of an HQ resets its calm (%2 s needed to split)", [CQ_secureRadius, CQ_splitAge, ["NOT AVAILABLE (no ProjectileCreated event)", "on"] select (CQ_fireWatchEH > -1)]] call CQ_fnc_log;
