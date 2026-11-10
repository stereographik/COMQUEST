/*
    CQ_fnc_heatTick  (server, director task, every CQ_heatEvery s)
    MAGPIE heatmap. The map is cut in CQ_heatCell squares, each with two values 0..1:
      scan  set to 1 when a flying MAGPIE drone's sensor covers the cell (cold colour)
      heat  enemies her drones see right now, weighted by type (CQ_heatWeights, summed, max 1)
    Both fade with a half-life (CQ_heatHalfHeat, CQ_heatHalfScan): the map shows where things
    were, and cools as the information gets old. Every CQ_heatPubEvery s the non-empty cells
    go to every client as one packed number each (CQ_heatPub): cell index x 256 + scan x 16 +
    heat (scan and heat on 0..15), drawn by CQ_fnc_heatMapClient.
*/
if (time < (missionNamespace getVariable ["CQ_heatNext", 0])) exitWith {};
private _dt = time - (missionNamespace getVariable ["CQ_heatLast", time]);
CQ_heatLast = time;
CQ_heatNext = time + CQ_heatEvery;
if (isNil "CQ_heat") then { CQ_heat = createHashMap };

private _n = ceil (worldSize / CQ_heatCell);
private _ks = 0.5 ^ (_dt / CQ_heatHalfScan);
private _kh = 0.5 ^ (_dt / CQ_heatHalfHeat);
// fade
{
    _y set [0, (_y select 0) * _ks];
    _y set [1, (_y select 1) * _kh];
} forEach CQ_heat;
{ CQ_heat deleteAt _x } forEach ((keys CQ_heat) select { private _v = CQ_heat get _x; (_v select 0) <= 0.03 && { (_v select 1) <= 0.03 } });

// scan: every cell under a flying drone's sensor
CQ_magSensor params ["_r0", "_rk", "_rmax"];
{
    private _alt = (getPosATL _x) select 2;
    if (_alt < 40) then { continue };
    private _r = ((_r0 + _alt * _rk) min _rmax) * 0.8;
    private _p = getPosATL _x;
    private _cr = ceil (_r / CQ_heatCell);
    private _cx = floor ((_p select 0) / CQ_heatCell);
    private _cy = floor ((_p select 1) / CQ_heatCell);
    for "_i" from (_cx - _cr) to (_cx + _cr) do {
        for "_j" from (_cy - _cr) to (_cy + _cr) do {
            if (_i < 0 || { _j < 0 } || { _i >= _n } || { _j >= _n }) then { continue };
            private _c = [(_i + 0.5) * CQ_heatCell, (_j + 0.5) * CQ_heatCell];
            if (_c distance2D _p > _r) then { continue };
            if (surfaceIsWater _c) then { continue };
            private _k = _i * _n + _j;
            private _v = CQ_heat getOrDefault [_k, [0, 0]];
            _v set [0, 1];
            CQ_heat set [_k, _v];
        };
    };
} forEach ((missionNamespace getVariable ["CQ_magVehs", []]) select { alive _x });

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
    private _v = CQ_heat getOrDefault [_x, [1, 0]];
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
