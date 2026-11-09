/*
    CQ_fnc_rdfTick  (server, director task, every 10 s)
    Publishes the enemy radio emitters for the players' direction finder (CQ_fnc_rdfClient):
    CQ_rdfSources = [[pos, power], ...]
      only FULLY BUILT HQs whose radio tower still stands emit (power 1);
      HQs being set up, radio tower destroyed or HQ gone: silent
*/
if (time < CQ_rdfNext) exitWith {};
CQ_rdfNext = time + 10;
private _src = [];
{
    private _h = _y;
    if !((_h get "state") in (CQ_activeStates - ["Inbound"])) then { continue };
    if ((_h get "buildDone") && { alive (_h get "radio") }) then { _src pushBack [getPosATL (_h get "radio"), 1] };
} forEach CQ_hqs;
if (_src isNotEqualTo (missionNamespace getVariable ["CQ_rdfSources", []])) then {
    CQ_rdfSources = _src;
    publicVariable "CQ_rdfSources";
};
