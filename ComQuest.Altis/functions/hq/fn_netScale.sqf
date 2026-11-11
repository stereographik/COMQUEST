/*
    CQ_fnc_netScale  (server, from CQ_fnc_netTick)                           nGD tuning
    Enemy strength follows the number of players. Full power (factor 1) is CQ_fullPowerPlayers
    players (4 full squads); fewer players scale down to CQ_scaleMin at most:
      CQ_maxInfantry  x factor
      CQ_maxAI        x (0.5 + 0.5 x factor)   (crews and statics shrink less)
      CQ_waveInterval / factor, at most twice the base interval
    CQ_testFullPower (debug panel "Full power"): play as if CQ_fullPowerPlayers were connected.
    The base values are the ones from cfg/settings.sqf (debug overrides included), kept once.
*/
if (isNil "CQ_scaleBase") then { CQ_scaleBase = [CQ_maxInfantry, CQ_maxAI, CQ_waveInterval]; CQ_scale = -1 };
CQ_scaleBase params ["_inf", "_ai", "_wave"];
private _n = if (missionNamespace getVariable ["CQ_testFullPower", false]) then { CQ_fullPowerPlayers } else {
    count (allPlayers select { alive _x && { side group _x == west } })
};
private _s = ((_n / CQ_fullPowerPlayers) max CQ_scaleMin) min 1;
_s = (round (_s * 20)) / 20;           // steps of 5 %: no churn on every join / leave
if (_s == CQ_scale) exitWith {};
CQ_scale = _s;
CQ_maxInfantry = round (_inf * _s);
CQ_maxAI = round (_ai * (0.5 + 0.5 * _s));
CQ_waveInterval = round ((_wave / _s) min (_wave * 2));
publicVariable "CQ_scale";
["Enemy scaling: %1 players%2 -> factor %3: infantry cap %4, AI cap %5, wave every %6 s", [_n,
    ["", " (FULL POWER test)"] select (missionNamespace getVariable ["CQ_testFullPower", false]), _s, CQ_maxInfantry, CQ_maxAI, CQ_waveInterval]] call CQ_fnc_log;
