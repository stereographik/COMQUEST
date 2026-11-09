/*
    CQ_fnc_baseRepairTick  (server, director task, every 5 s)
    Repair stations at the end of the base vehicle rays (CQ_repairPoints): any friendly
    vehicle standing still within CQ_repairRadius is repaired and refuelled 10 % per pass
    (about 50 s from badly damaged / empty to full) and rearmed at once.
*/
if (time < CQ_repairNext) exitWith {};
CQ_repairNext = time + 5;
{
    private _rp = _x;
    {
        private _v = _x;
        if (!alive _v || { speed _v > 2 } || { side group effectiveCommander _v == east }) then { continue };
        private _dmg = damage _v;
        if (_dmg > 0) then { _v setDamage ((_dmg - 0.1) max 0) };
        if (fuel _v < 1) then { [_v, ((fuel _v) + 0.1) min 1] remoteExec ["setFuel", _v] };
        [_v, 1] remoteExec ["setVehicleAmmo", _v];
    } forEach (nearestObjects [_rp, ["LandVehicle", "Air"], CQ_repairRadius]);
} forEach (missionNamespace getVariable ["CQ_repairPoints", []]);
