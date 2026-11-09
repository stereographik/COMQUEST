/*
    CQ_fnc_hqRequestWave  (server, from CQ_fnc_hqTick)
    [_hq] call CQ_fnc_hqRequestWave;
    Asks for a reinforcement wave. Refused (retried later) when the AI cap would be exceeded
    or the HQ's radio tower is down.
*/
params ["_hq"];
private _id = _hq get "id";

if ((call CQ_fnc_enemyCount) > CQ_maxAI - CQ_waveSize || { (call CQ_fnc_enemyInfantry) > CQ_maxInfantry - CQ_waveSize }) exitWith {
    _hq set ["state", "Holding"];
    _hq set ["nextWaveT", time + 60];
    ["HQ #%1: wave postponed, cap (infantry %2/%3, all AI %4/%5)", [_id, call CQ_fnc_enemyInfantry, CQ_maxInfantry, call CQ_fnc_enemyCount, CQ_maxAI]] call CQ_fnc_log;
};
if ((_hq get "buildDone") && { !alive (_hq get "radio") }) exitWith {
    _hq set ["state", "Holding"];
    _hq set ["nextWaveT", time + CQ_waveInterval];
    ["HQ #%1: radio down, cannot call reinforcements", [_id]] call CQ_fnc_log;
};

_hq set ["state", "WaitingReinf"];
_hq set ["stateT", time];
_hq set ["waveResult", []];
["Enemy calling reinforcements", format ["HQ #%1 is waiting for a reinforcement convoy", _id]] call CQ_fnc_announce;
[_hq] spawn CQ_fnc_waveSend;
