/*
    CQ_fnc_enemyInfantry
    Live enemy foot soldiers: on foot or riding as passengers. Drivers, gunners, commanders
    and pilots of vehicles, helicopters and static weapons are not counted. The
    CQ_maxInfantry cap is checked against this. Not counted either: groups marked CQ_noInfCap
    (support teams, events, hunters, sabotage): only the all-AI budget (CQ_maxAI) holds them.
    Not counted (2026-11-19, garrison target): armed civilians (CQ_role "guerilla"), the
    commanders' escorts ("escort") and vehicle crews on foot (assigned driver / gunner seat):
    HQ fixtures, not the infantry the waves bring.
*/
{
    alive _x && { side group _x == east } && { !(_x getVariable ["CQ_outpost", false]) } && { !(_x getVariable ["CQ_noCap", false]) } && { !((group _x) getVariable ["CQ_noInfCap", false]) } && {
        !(((group _x) getVariable ["CQ_role", ""]) in ["guerilla", "escort"]) && {
        private _v = vehicle _x;
        private _r = (assignedVehicleRole _x) param [0, ""];
        (_v == _x && { !(_r in ["driver", "turret"]) }) || { _r == "cargo" } }
    }
} count allUnits
