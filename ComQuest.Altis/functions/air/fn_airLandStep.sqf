/*
    CQ_fnc_airLandStep  (server, call every tick until it returns true)
    [_heli, _padObject, _state] call CQ_fnc_airLandStep  ->  true once the heli is on the ground
    Robust landing on a pad:
      - farther than 150 m: doMove to the pad (re-issued every 10 s)
      - within 150 m: "land" order, re-issued every 20 s (the AI often ignores a single one)
      - still airborne 90 s after arriving over the pad: set down on the pad (fallback, logged)
    _state is any HashMap the caller keeps per heli (keys nearT, landT, moveT); reset its
    "nearT" to -1 whenever the heli gets a new destination.
*/
params ["_v", "_pad", "_st"];

private _pp = getPosATL _pad;
if (isTouchingGround _v || { (getPosATL _v select 2) < 1.5 }) exitWith { true };

if (_v distance2D _pp > 150) exitWith {
    if (time - (_st getOrDefault ["moveT", -100]) > 10) then { _v doMove _pp; _st set ["moveT", time] };
    _st set ["nearT", -1];
    false
};

if ((_st getOrDefault ["nearT", -1]) < 0) then { _st set ["nearT", time] };
if (time - (_st getOrDefault ["landT", -100]) > 20) then { _v land "LAND"; _st set ["landT", time] };

if (time - (_st get "nearT") > 90) exitWith {
    _v setVelocity [0, 0, 0];
    _v setPosATL [_pp select 0, _pp select 1, 0.3];
    ["Air: %1 kept hovering over its pad at %2, set down (fallback)", [typeOf _v, mapGridPosition _pp]] call CQ_fnc_log;
    true
};
false
