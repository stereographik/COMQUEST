/*
    CQ_fnc_dbgStates  (server, director task)
    While an admin has "States" on (debug panel, CQ_dbgStatesOn), every 5 s each crewed enemy
    vehicle gets a short state for the debug map (CQ_dbgSt, public): what it does, or why it waits.
*/
if (!(missionNamespace getVariable ["CQ_dbgStatesOn", false])) exitWith {};
if (time < (missionNamespace getVariable ["CQ_dbgStNext", 0])) exitWith {};
CQ_dbgStNext = time + 5;

private _airWord = createHashMapFromArray [
    ["parked", "parked"], ["toPark", "to base"], ["patrolling", "patrol"], ["ferry", "ferry"], ["btEscort", "escort truck"],
    ["rearming", "rearm"], ["toRearm", "to rearm"], ["landing", "landing"], ["leaving", "leaving"], ["hunting", "hunt"],
    ["unloaded", "unloaded"], ["postDrop", "drop done"], ["fleet", "fleet"]
];
private _roleWord = createHashMapFromArray [
    ["patrol", "patrol"], ["qrf", "qrf"], ["rearm", "rearm"], ["waitSupply", "wait: supply"], ["assault", "assault"],
    ["secure", "secure"], ["guard", "guard"], ["convoy", "convoy"], ["support", "support"]
];
{
    private _v = _x;
    if (!alive _v || { (crew _v) isEqualTo [] }) then { continue };
    private _g = group effectiveCommander _v;
    if !((side _g) in [east, independent]) then { continue };
    private _s = "";
    private _ai = CQ_air findIf { (_x get "veh") == _v };
    private _bt = _v getVariable ["CQ_btHq", -1];
    if (_ai > -1) then {
        private _st = (CQ_air select _ai) get "state";
        _s = _airWord getOrDefault [_st, _st];
    } else {
        if (_bt > -1) then {
            private _h = CQ_hqs getOrDefault [_bt, createHashMap];
            _s = switch (true) do {
                case (count _h == 0): { "no HQ" };
                case (_h getOrDefault ["buildDone", false]): { "done: HQ built" };
                case ("colWait" in _h): { _h get "colWait" };
                case ((_h get "state") == "Securing"): { "wait: perimeter" };
                case ("btPhase" in _h): { _h get "btPhase" };
                default { format ["wait: HQ %1", toLower (_h get "state")] };
            };
        } else {
            private _r = _g getVariable ["CQ_role", ""];
            _s = _roleWord getOrDefault [_r, _r];
            if (_s == "" && { _v getVariable ["CQ_busy", false] }) then { _s = "busy" };
        };
    };
    if (_ai < 0) then {
        private _mv = speed _v > 2;
        if (_s == "") then { _s = ["idle", "moving"] select _mv } else { if (!_mv && { _bt < 0 } && { _s find "wait" != 0 }) then { _s = _s + " (idle)" } };
    };
    switch (true) do {
        case (!canMove _v): { _s = "disabled" };
        case (fuel _v <= 0): { _s = "no fuel" };
        case (!alive driver _v && { !(_v isKindOf "StaticWeapon") }): { _s = "no driver" };
        case (behaviour effectiveCommander _v == "COMBAT"): { _s = "combat · " + _s };
    };
    if ((_v getVariable ["CQ_dbgSt", ""]) != _s) then { _v setVariable ["CQ_dbgSt", _s, true] };
} forEach vehicles;
