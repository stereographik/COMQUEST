/*
    CQ_fnc_actTick  (server, director task, every 15 s)
    Campaign rhythm.
    - Act from the carrier's supplies (CQ_carrierLeft / CQ_carrierHqs):
        1 landing > 60 %   2 expansion > 30 %   3 last push > 0 %   4 endgame (carrier empty)
      Published as CQ_act; each new act opens with its CROSSROAD line (act2, act3, act4).
      CQ_fnc_say picks the act's own variants ("key@<act>") when they exist.
    - SITREP every CQ_sitrepEvery s: carrier %, enemy positions known to the players (seen by
      MAGPIE or revealed by a captured commander), our losses over the last period.
      Held back while the radio is silent after a fallen HQ.
    - "quiet" when nobody has fought for CQ_quietAfter s.
*/
if (time < (missionNamespace getVariable ["CQ_actNext", 0])) exitWith {};
CQ_actNext = time + 15;
if (missionNamespace getVariable ["CQ_playerView", false]) then { call CQ_fnc_playerViewMarkers };

private _left = missionNamespace getVariable ["CQ_carrierLeft", CQ_carrierHqs];
private _pct = (_left max 0) / (CQ_carrierHqs max 1);
private _act = switch (true) do {
    case (_pct > 0.6): { 1 };
    case (_pct > 0.3): { 2 };
    case (_pct > 0): { 3 };
    default { 4 };
};
private _was = missionNamespace getVariable ["CQ_act", 1];
if (_act > _was) then {
    CQ_act = _act;
    publicVariable "CQ_act";
    [format ["act%1", _act], []] call CQ_fnc_say;
    ["Story: act %1 (carrier %2%%)", [_act, round (_pct * 100)]] call CQ_fnc_log;
};

// SITREP
if (isNil "CQ_sitrepT") then { CQ_sitrepT = time };
if (time - CQ_sitrepT >= CQ_sitrepEvery && { time >= (missionNamespace getVariable ["CQ_storyQuietUntil", -1]) }) then {
    CQ_sitrepT = time;
    private _known = { (_x get "state") in CQ_activeStates && { (_x get "id") in (missionNamespace getVariable ["CQ_magHqSeen", createHashMap]) || { _x getOrDefault ["revealed", false] } } } count (values CQ_hqs);
    private _deaths = { time - _x < CQ_sitrepEvery } count (missionNamespace getVariable ["CQ_deathTimes", []]);
    private _loss = switch (true) do {
        case (_deaths == 0): { "none" };
        case (_deaths <= 3): { "light" };
        case (_deaths <= 8): { "moderate" };
        default { "heavy" };
    };
    ["sitrep", [round (_pct * 100), _known, _loss]] call CQ_fnc_say;
};

// long quiet
if (isNil "CQ_lastFightT") then { CQ_lastFightT = time };
if (time - CQ_lastFightT > CQ_quietAfter && { time - (missionNamespace getVariable ["CQ_quietSaidT", -1e6]) > CQ_quietAfter }) then {
    CQ_quietSaidT = time;
    ["quiet", []] call CQ_fnc_say;
};
