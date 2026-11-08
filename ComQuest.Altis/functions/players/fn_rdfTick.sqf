/*
    CQ_fnc_rdfTick  (server, director task, every 10 s)
    Publishes the enemy radio emitters for the players' direction finder (CQ_fnc_rdfClient):
    CQ_rdfSources = [[pos, power], ...]
      built HQ with its radio tower standing   power 1
      HQ still being set up (field radios)     power CQ_rdfFieldPower
      radio tower destroyed / HQ gone          silent
*/
if (time < CQ_rdfNext) exitWith {};
CQ_rdfNext = time + 10;
private _src = [];
{
    private _h = _y;
    if !((_h get "state") in (CQ_activeStates - ["Inbound"])) then { continue };
    if (_h get "buildDone") then {
        if (alive (_h get "radio")) then { _src pushBack [getPosATL (_h get "radio"), 1] };
    } else {
        _src pushBack [_h get "pos", CQ_rdfFieldPower];
    };
} forEach CQ_hqs;
if (_src isNotEqualTo (missionNamespace getVariable ["CQ_rdfSources", []])) then {
    CQ_rdfSources = _src;
    publicVariable "CQ_rdfSources";
};
