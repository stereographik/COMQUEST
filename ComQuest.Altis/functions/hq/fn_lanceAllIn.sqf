/*
    CQ_fnc_lanceAllIn  (server, from CQ_fnc_actTick when the carrier cannot pay anything more)
    La Lance, last push: no more waves, flights or trucks (CQ_fnc_carrierSpend refuses), and every
    surviving CSAT ground group goes for the player base (CQ_role "assault", driven by
    CQ_fnc_assaultTick: approach, sweep, breach). Left out: events, the corridor outpost, posted
    guards, static weapons, aircraft and the HQ commanders (still to capture).
    Victory once every group of the all-in is dead (CQ_fnc_hqTick).
*/
if (missionNamespace getVariable ["CQ_lanceAllIn", false]) exitWith {};
CQ_lanceAllIn = true;
private _cmds = (values CQ_hqs) apply { _x getOrDefault ["cmdGroup", grpNull] };
private _gs = allGroups select {
    private _g = _x;
    private _l = leader _g;
    side _g == east && { ({ alive _x } count units _g) > 0 }
    && { !(_g getVariable ["CQ_event", false]) }
    && { !((_g getVariable ["CQ_role", ""]) in ["post", "assault"]) }
    && { (units _g) findIf { _x getVariable ["CQ_outpost", false] } < 0 }
    && { !(_g in _cmds) }
    && { !(vehicle _l isKindOf "StaticWeapon") } && { !(vehicle _l isKindOf "Air") }
};
{
    [_x] call CQ_fnc_clearWaypoints;
    _x setVariable ["CQ_role", "assault"];
    _x setVariable ["CQ_aHq", -1];
    _x setVariable ["CQ_aStage", ""];
    _x setVariable ["CQ_allIn", true];
    _x enableDynamicSimulation false;
} forEach _gs;
// the vehicles they ride are theirs now: nothing else takes them
{ { (vehicle _x) setVariable ["CQ_busy", true] } forEach units _x } forEach _gs;
CQ_lanceAllInGroups = _gs;
private _men = 0; { _men = _men + ({ alive _x } count units _x) } forEach _gs;
["THE CARRIER IS EMPTY: ALL-IN", format ["CSAT has nothing left to send. %1 soldiers in %2 groups are coming for your base. Hold, and the island is yours.", _men, count _gs]] call CQ_fnc_announce;
["assault", ["every position"]] call CQ_fnc_say;
["Lance all-in: %1 groups, %2 men sent against the base", [count _gs, _men]] call CQ_fnc_log;
