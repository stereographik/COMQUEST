/*
    CQ_fnc_outpostTick  (server, director task, every 5 s)
    The corridor outpost (CQ_fnc_outpostBuild), while it stands:
      jammer   on while the jammer stands, CQ_counterJam is off (crash crate) and the outpost holds:
               CQ_opJam / CQ_opJamPos for MAGPIE (CQ_fnc_magTick) and the signal panel
      marker   once MAGPIE has spotted it (CQ_outpostState "spotted", set by CQ_fnc_magTick): a black hatched
               circle around a point CQ_opFuzz m off while jammed, the exact spot otherwise
      mortar   fires on players its tower watcher sees within CQ_opMortarRange, after a delay
      fall     no outpost man left in the post: flights to its HQ come the long way round and its
               resupply is CQ_opSupplyDelay s later (CQ_corridorLost = that HQ's id)
*/
if (isNil "CQ_outpostState") exitWith {};
if (time < (missionNamespace getVariable ["CQ_opNext", 0])) exitWith {};
CQ_opNext = time + 5;
private _op = CQ_outpostState;
private _pos = _op get "pos";

// the HQ it serves: the active HQ nearest its HQ site
if ((_op get "hqId") < 0) then {
    private _hs = (values CQ_hqs) select { (_x get "pos") distance2D (_op get "hqSite") < 1500 };
    if (_hs isNotEqualTo []) then { _op set ["hqId", (([_hs, [], { (_x get "pos") distance2D (CQ_outpostState get "hqSite") }] call BIS_fnc_sortBy) select 0) get "id"] };
};

// ---- fall: nobody left in the post itself (gunboats apart)
if !(_op get "fallen") then {
    private _left = (_op get "men") select { alive _x && { _x distance2D _pos < 300 } };
    if (_left isEqualTo []) then {
        _op set ["fallen", true];
        CQ_corridorLost = _op get "hqId";
        ["Outpost: corridor outpost at %1 has fallen, flights to HQ #%2 rerouted, resupply +%3 s", [mapGridPosition _pos, CQ_corridorLost, CQ_opSupplyDelay]] call CQ_fnc_log;
        ["opFallen", [round (CQ_opSupplyDelay / 60)]] call CQ_fnc_say;
        // a resupply already planned for that HQ comes later too
        if (CQ_corridorLost == (missionNamespace getVariable ["CQ_hubId", -2]) && { (missionNamespace getVariable ["CQ_nextAmmoFlight", -1]) > 0 }) then {
            CQ_nextAmmoFlight = CQ_nextAmmoFlight + CQ_opSupplyDelay;
        };
    };
};

// ---- jammer
private _jam = alive (_op get "jammer") && { !(missionNamespace getVariable ["CQ_counterJam", false]) } && { !(_op get "fallen") };
if (_jam != (_op get "jam")) then {
    _op set ["jam", _jam];
    CQ_opJam = _jam; publicVariable "CQ_opJam";
    private _why = switch (true) do {
        case (_op get "fallen"): { "the outpost fell" };
        case (!alive (_op get "jammer")): { "jammer destroyed" };
        default { "counter-jamming (crash crate)" };
    };
    ["Outpost: jamming off (%1)", [_why]] call CQ_fnc_log;
    if (!(_op get "fallen") && { !alive (_op get "jammer") }) then { ["jamOff", []] call CQ_fnc_say };
};

// ---- marker: rough area while jammed, the exact spot otherwise (once spotted)
if (_op get "spotted") then {
    private _want = switch (true) do {
        case (_op get "fallen"): { "down" };
        case (_jam): { "rough" };
        default { "exact" };
    };
    if (_want != (_op get "mark")) then {
        if ((_op get "mark") == "") then { ["opSpotted", []] call CQ_fnc_say };
        if ((_op get "mark") == "rough" && { _want == "exact" }) then { ["opExact", []] call CQ_fnc_say };
        _op set ["mark", _want];
        deleteMarker "cq_op"; deleteMarker "cq_op_icon";
        if (_want == "rough") then {
            private _m = createMarker ["cq_op", _op get "fuzzPos"];
            _m setMarkerShape "ELLIPSE";
            _m setMarkerSize [CQ_opFuzzR, CQ_opFuzzR];
            _m setMarkerBrush "FDiagonal";
            _m setMarkerColor "ColorBlack";
            CQ_opMarkPos = _op get "fuzzPos";
        } else {
            private _m = createMarker ["cq_op_icon", _pos];
            _m setMarkerType (["mil_triangle", "o_installation"] select (isClass (configFile >> "CfgMarkers" >> "o_installation")));
            _m setMarkerColor (["ColorOPFOR", "ColorBlack"] select (_want == "down"));
            _m setMarkerText (["Corridor outpost", "Corridor outpost (destroyed)"] select (_want == "down"));
            CQ_opMarkPos = _pos;
        };
    };
};

// ---- mortar: only on what the tower watcher sees, after a delay, with spread
private _m = _op get "mortar";
private _w = _op get "watcher";
if (!(_op get "fallen") && { alive _m } && { alive gunner _m } && { alive _w }) then {
    private _aim = _op get "mortarAim";
    if (_aim isEqualTo []) then {
        if (time - (_op get "mortarT") < CQ_opMortarEvery) exitWith {};
        private _seen = allPlayers select {
            alive _x && { _x distance2D _pos < CQ_opMortarRange } && { _x distance2D _pos > 80 } && { _w knowsAbout _x > 1.5 } && { side group _x == west }
        };
        if (_seen isEqualTo []) exitWith {};
        private _t = ([_seen, [], { _x distance2D _pos }] call BIS_fnc_sortBy) select 0;
        _op set ["mortarAim", [_t, time + (CQ_opMortarDelay select 0) + random ((CQ_opMortarDelay select 1) - (CQ_opMortarDelay select 0))]];
    } else {
        _aim params ["_t", "_at"];
        if (time < _at) exitWith {};
        _op set ["mortarAim", []];
        _op set ["mortarT", time];
        if (!alive _t || { _t distance2D _pos > CQ_opMortarRange }) exitWith {};
        private _p = (getPosATL _t) getPos [random CQ_opMortarSpread, random 360];
        _m setVehicleAmmo 1;
        _m doArtilleryFire [[_p select 0, _p select 1, 0], "8Rnd_82mm_Mo_shells", 3];
        ["Outpost: mortar salvo on %1 at %2 (spotted by the watcher)", [name _t, mapGridPosition _p]] call CQ_fnc_log;
    };
};
