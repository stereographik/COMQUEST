/*
    CQ_fnc_heatTick  (server, director task, every CQ_heatEvery s)
    MAGPIE heatmap, contacts only. The map is cut in CQ_heatCell squares; heat 0..1 = enemies
    her drones see right now, weighted by type (CQ_heatWeights, summed, max 1). It fades with a
    half-life (CQ_heatHalfHeat): the map shows where they were, and cools as it gets old.
    (The packet still carries a scan field, always 0.) Every CQ_heatPubEvery s the non-empty cells
    go to every client as one packed number each (CQ_heatPub): cell index x 256 + scan x 16 +
    heat (scan and heat on 0..15), drawn by CQ_fnc_heatMapClient.
*/
if (time < (missionNamespace getVariable ["CQ_heatNext", 0])) exitWith {};
private _dt = time - (missionNamespace getVariable ["CQ_heatLast", time]);
CQ_heatLast = time;
CQ_heatNext = time + CQ_heatEvery;
if (isNil "CQ_heat") then { CQ_heat = createHashMap };

private _n = ceil (worldSize / CQ_heatCell);

private _kh = 0.5 ^ (_dt / CQ_heatHalfHeat);
// fade
{
    _y set [0, 0];
    _y set [1, (_y select 1) * _kh];
} forEach CQ_heat;
{ CQ_heat deleteAt _x } forEach ((keys CQ_heat) select { private _v = CQ_heat get _x; (_v select 0) <= 0.03 && { (_v select 1) <= 0.03 } });

// heat: enemies seen during this tick
private _sum = createHashMap;
{
    _x params ["_o", "", "_last", "", "_cat"];
    if (time - _last > CQ_heatEvery + 1 || { !alive _o } || { _o getVariable ["CQ_hunterHidden", false] }) then { continue };
    private _p = getPosATL _o;
    private _k = (floor ((_p select 0) / CQ_heatCell)) * _n + floor ((_p select 1) / CQ_heatCell);
    _sum set [_k, (_sum getOrDefault [_k, 0]) + (CQ_heatWeights getOrDefault [_cat, 0.2])];
} forEach (values (missionNamespace getVariable ["CQ_magSeen", createHashMap]));
{
    private _v = CQ_heat getOrDefault [_x, [0, 0]];
    _v set [1, (_v select 1) max (_y min 1)];
    CQ_heat set [_x, _v];
} forEach _sum;

// publish
if (time >= (missionNamespace getVariable ["CQ_heatPubNext", 0])) then {
    CQ_heatPubNext = time + CQ_heatPubEvery;
    CQ_heatSerial = (missionNamespace getVariable ["CQ_heatSerial", 0]) + 1;
    CQ_heatPub = [_n, CQ_heatCell, [], CQ_heatSerial];
    private _out = CQ_heatPub select 2;
    {
        private _s = round ((_y select 0) * 15);
        private _h = round ((_y select 1) * 15);
        if (_s + _h > 0) then { _out pushBack (_x * 256 + _s * 16 + _h) };
    } forEach CQ_heat;
    publicVariable "CQ_heatPub";
};
if (time - (missionNamespace getVariable ["CQ_heatLogT", -1e6]) > 120) then {
    CQ_heatLogT = time;
    ["Heatmap: %1 cells (%2 hot)", [count CQ_heat, count ((values CQ_heat) select { (_x select 1) > 0.05 })]] call CQ_fnc_log;
};
