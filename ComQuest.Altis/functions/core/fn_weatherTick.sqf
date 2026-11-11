/*
    CQ_fnc_weatherTick  (server, director task)
    Weather over the whole mission (every delay is in real seconds):
      start      clear sky or partly cloudy (random), light morning fog
      fog        fades out slowly, gone at CQ_wxFogGoneHour (in-game clock, e.g. 11:00)
      changes    every CQ_wxChangeEvery (15-30 min, random): clear <-> partly cloudy, or with
                 CQ_wxBadChance (10 %) cloudy or cloudy + rain (half and half)
      rain       never longer than CQ_wxRainMax (4 min) from first drop to last: fade in,
                 hold, fade out; then it stays cloudy until the next change
      every transition takes at least CQ_wxTransition (1 min)
    The server's weather is synced to every player by the engine.
*/
if (time < (missionNamespace getVariable ["CQ_wxNext", 0])) exitWith {};
CQ_wxNext = time + 5;

private _states = createHashMapFromArray [
    ["clear", [0.10, 0]], ["partly", [0.42, 0]], ["cloudy", [0.72, 0]], ["rain", [0.86, CQ_wxRainLevel]]
];
private _rnd = { params ["_mm"]; (_mm select 0) + random ((_mm select 1) - (_mm select 0)) };
private _tr = { [CQ_wxTransition] call _rnd };

// ---- first call: start state + morning fog
if (isNil "CQ_wxState") then {
    CQ_wxState = selectRandom ["clear", "partly"];
    (_states get CQ_wxState) params ["_oc"];
    0 setOvercast _oc;
    0 setRain 0;
    0 setFog CQ_wxFogMorning;
    forceWeatherChange;
    // fog gone at CQ_wxFogGoneHour in-game: the transition time is that many real seconds
    private _left = ((CQ_wxFogGoneHour - daytime) max 0) * 3600 / (timeMultiplier max 0.1);
    if (_left > 60) then { _left setFog [0, 0, 0] } else { 60 setFog [0, 0, 0] };
    CQ_wxChangeT = time + ([CQ_wxChangeEvery] call _rnd);
    CQ_wxRainEndT = -1;
    ["Weather: %1 at start, morning fog %2, gone in %3 min", [CQ_wxState, CQ_wxFogMorning select 0, round (_left / 60)]] call CQ_fnc_log;
};

// ---- rain end (max CQ_wxRainMax from the first drop to the last)
if (CQ_wxRainEndT > 0 && { time >= CQ_wxRainEndT }) then {
    CQ_wxRainEndT = -1;
    private _t = CQ_wxTransition select 0;       // fixed fade so the rain stays within CQ_wxRainMax
    _t setRain 0;
    CQ_wxState = "cloudy";
    ["Weather: rain stops (fade %1 s), stays cloudy", [round _t]] call CQ_fnc_log;
};

// ---- next change
if (time >= CQ_wxChangeT && { CQ_wxRainEndT < 0 }) then {
    private _next = if (random 1 < CQ_wxBadChance) then { selectRandom ["cloudy", "rain"] } else {
        if (CQ_wxState == "clear") then { "partly" } else { if (CQ_wxState == "partly") then { "clear" } else { selectRandom ["clear", "partly"] } }
    };
    (_states get _next) params ["_oc", "_rain"];
    private _t = call _tr;
    _t setOvercast _oc;
    if (_next == "rain") then {
        // the clouds build first, then the rain: fade in + hold + fade out <= CQ_wxRainMax
        private _fade = CQ_wxTransition select 0;
        private _hold = (CQ_wxRainMax - 2 * _fade) max 0;
        [_t, _fade, _rain] spawn { params ["_t", "_fade", "_rain"]; sleep _t; _fade setRain _rain };
        CQ_wxRainEndT = time + _t + _fade + (_hold * (0.5 + random 0.5));
    } else {
        _t setRain 0;
    };
    ["Weather: %1 -> %2 (transition %3 s)%4", [CQ_wxState, _next, round _t, ["", format [", rain ends in %1 s", round (CQ_wxRainEndT - time)]] select (_next == "rain")]] call CQ_fnc_log;
    CQ_wxState = _next;
    CQ_wxChangeT = time + ([CQ_wxChangeEvery] call _rnd);
};
