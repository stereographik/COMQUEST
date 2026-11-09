/*
    CQ_fnc_enemyInfantry
    Live enemy foot soldiers: on foot or riding as passengers. Drivers, gunners, commanders
    and pilots of vehicles, helicopters and static weapons are not counted. The
    CQ_maxInfantry cap is checked against this.
*/
{
    alive _x && { side group _x == east } && {
        private _v = vehicle _x;
        _v == _x || { (assignedVehicleRole _x) param [0, ""] == "cargo" }
    }
} count allUnits
