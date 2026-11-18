/*
    CQ_fnc_aiRoom  (server)
    [_n, "who"] call CQ_fnc_aiRoom  ->  true when _n more enemy AI fit under CQ_maxAI
    The one enemy AI budget: every spawner that is not a wave (waves check it in
    CQ_fnc_hqRequestWave) asks here first: special teams, roots. Events (hostage, hunters,
    sabotage, crash, EMP) always get room: they are out of the caps.
    (roots get CQ_rootCapBonus extra room so a landing is never blocked for good).
    No room: the spawner waits and asks again later; a refusal is logged once a minute per spawner.
*/
params [["_n", 0], ["_who", "?"], ["_bonus", 0]];
// events never wait: they are out of the caps and start on time
if (_who in ["hostage", "hunters", "sabotage", "crash", "EMP"]) exitWith { true };
private _now = call CQ_fnc_enemyCount;
if (_now + _n <= CQ_maxAI + _bonus) exitWith { true };
if (isNil "CQ_aiRoomLog") then { CQ_aiRoomLog = createHashMap };
if (time - (CQ_aiRoomLog getOrDefault [_who, -1e6]) > 60) then {
    CQ_aiRoomLog set [_who, time];
    ["AI budget: %1 waits (%2 + %3 > %4)", [_who, _now, _n, CQ_maxAI + _bonus]] call CQ_fnc_log;
};
false
