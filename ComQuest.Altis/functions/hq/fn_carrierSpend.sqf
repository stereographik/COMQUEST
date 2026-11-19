/*
    CQ_fnc_carrierSpend  (server)
    [_kind, _what] call CQ_fnc_carrierSpend  ->  true when paid (or not La Lance)
    La Lance economy: the carrier holds CQ_lanceBudget points (CQ_carrierLeft / CQ_carrierHqs) and
    pays for everything it sends: _kind in CQ_lanceCost (wave, flight, truck, kajman, position,
    rebuild). Not enough left, or the all-in has started: refused (nothing is sent).
    The carrier marker follows; the acts, the tide and the all-in follow in CQ_fnc_actTick.
*/
params ["_kind", ["_what", ""]];
if (!CQ_lanceOn) exitWith { true };
if (missionNamespace getVariable ["CQ_lanceAllIn", false]) exitWith { false };
private _cost = CQ_lanceCost getOrDefault [_kind, 0];
private _left = missionNamespace getVariable ["CQ_carrierLeft", CQ_carrierHqs];
if (_left < _cost) exitWith {
    // one line per kind every 5 min at most
    if (isNil "CQ_spendLogT") then { CQ_spendLogT = createHashMap };
    if (time - (CQ_spendLogT getOrDefault [_kind, -1e6]) > 300) then {
        CQ_spendLogT set [_kind, time];
        ["Carrier: cannot pay %1 (%2 pts, %3 left): %4 not sent", [_kind, _cost, round _left, _what]] call CQ_fnc_log;
    };
    false
};
CQ_carrierLeft = _left - _cost;
call CQ_fnc_carrierMarker;
CQ_carrierSpent = (missionNamespace getVariable ["CQ_carrierSpent", createHashMap]);
CQ_carrierSpent set [_kind, (CQ_carrierSpent getOrDefault [_kind, 0]) + _cost];
["Carrier: -%1 pts for %2 (%3), %4 / %5 left (%6%%)", [_cost, _kind, _what, round CQ_carrierLeft, CQ_carrierHqs, round (100 * CQ_carrierLeft / (CQ_carrierHqs max 1))]] call CQ_fnc_log;
true
