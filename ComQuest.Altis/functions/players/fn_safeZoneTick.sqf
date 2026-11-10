/*
    CQ_fnc_safeZoneTick  (server, director task, every 5 s)
    Weapons-safe perimeter: players cannot fire within CQ_safeZoneRadius of the base
    (CQ_fnc_safeZoneFired, client) unless the base is under attack, i.e. a live enemy (on
    foot, in a vehicle or in the air) is inside the perimeter. CQ_baseHot stays true
    CQ_safeZoneHold s after the last enemy has gone. Clients read CQ_baseHot when they fire.
*/
private _enemy = ((CQ_basePos nearEntities [["CAManBase", "LandVehicle", "Air", "Ship"], CQ_safeZoneRadius])
    findIf { alive _x && { side group effectiveCommander _x == east } }) > -1;
if (_enemy) then { CQ_baseHotT = time };
private _hot = time - (missionNamespace getVariable ["CQ_baseHotT", -1e6]) < CQ_safeZoneHold;
if (_hot isEqualTo (missionNamespace getVariable ["CQ_baseHot", false])) exitWith {};
CQ_baseHot = _hot;
publicVariable "CQ_baseHot";
if (_hot) then {
    ["Base under attack", "Enemies inside the perimeter: weapons free"] call CQ_fnc_announce;
    "BASE UNDER ATTACK: weapons free inside the perimeter" remoteExec ["systemChat", 0];
} else {
    ["Base secure", "Perimeter clear: weapons safe again"] call CQ_fnc_announce;
    "Base secure: weapons safe again inside the perimeter" remoteExec ["systemChat", 0];
};
