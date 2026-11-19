/*
    CQ_fnc_hqRequestWave  (server, from CQ_fnc_hqTick)
    [_hq] call CQ_fnc_hqRequestWave;
    Asks for a reinforcement wave. Refused (retried later) when the AI cap would be exceeded
    or the HQ's radio tower is down.
*/
params ["_hq"];
private _id = _hq get "id";

// GARRISON TARGET: refilling an HQ up to CQ_garrisonTarget always goes (caps ignored, the wave
// brings only what it is short of); the extra CQ_splitSize for a split waits for room under the caps
private _have = [(_hq get "infantry")] call CQ_fnc_aliveCount;
// ONE CAP (2026-11-19): every enemy AI alive (CQ_maxAI); how much of it is infantry is the garrison target's job
private _capFull = (call CQ_fnc_enemyCount) > CQ_maxAI - CQ_waveSize;
if (_capFull && { _have < CQ_garrisonTarget } && { (_hq get "buildDone") }) then {
    _hq set ["waveNeed", ((CQ_garrisonTarget - _have) max CQ_waveMin) min CQ_waveMax];
    ["HQ #%1: caps full, but %2 / %3 infantry: refill wave of %4 goes anyway", [_id, _have, CQ_garrisonTarget, _hq get "waveNeed"]] call CQ_fnc_log;
    _capFull = false;
};
if (_capFull) exitWith {
    _hq set ["state", "Holding"];
    _hq set ["nextWaveT", time + 60];
    ["HQ #%1: wave postponed, AI cap (%2/%3)", [_id, call CQ_fnc_enemyCount, CQ_maxAI]] call CQ_fnc_log;
};
// nGD: an HQ cut off from the network (own tower down, or no path to the carrier trunk) gets no wave
if ((_hq get "buildDone") && { !alive (_hq get "radio") || { _hq getOrDefault ["isolated", false] } }) exitWith {
    _hq set ["state", "Holding"];
    _hq set ["nextWaveT", time + CQ_waveInterval];
    ["HQ #%1: %2, cannot call reinforcements", [_id, ["isolated from the network", "radio down"] select !alive (_hq get "radio")]] call CQ_fnc_log;
};

// La Lance: the carrier pays for the wave
if !(["wave", format ["wave for HQ #%1", _id]] call CQ_fnc_carrierSpend) exitWith {
    _hq set ["state", "Holding"];
    _hq set ["nextWaveT", time + CQ_waveInterval];
};
_hq set ["state", "WaitingReinf"];
_hq set ["stateT", time];
_hq set ["waveResult", []];
["Enemy calling reinforcements", format ["HQ #%1 is waiting for a reinforcement convoy", _id]] call CQ_fnc_announce;
[_hq] spawn CQ_fnc_waveSend;
