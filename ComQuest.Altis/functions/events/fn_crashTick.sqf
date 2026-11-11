/*
    CQ_fnc_crashTick  (server, director task, every 5 s)
    The crash event (see CQ_fnc_crashStart):
      when      the front has not moved for CQ_crashStagnant s (no HQ built, fallen or launched,
                no relay change), at most every CQ_crashCooldown s; plus a CQ_crashEarlyChance
                chance of one in the first CQ_crashEarlyWindow s
      contact   the survivors' first contact with us starts the hidden CQ_crashTimer countdown
                (CQ_crashAlarm: "enemy securing device" under the signal panel)
      drop      not secured in time: the carrier paradrops one of CQ_crashDropClasses with a
                squad (CQ_fnc_crashRoam)
      decrypt   once secured: every enemy HQ and radio tower on the map for CQ_crashDecrypt s
*/
if (!CQ_crash) exitWith {};
if (time < (missionNamespace getVariable ["CQ_crashNext", 0])) exitWith {};
CQ_crashNext = time + 5;
if (isNil "CQ_crashLastT") then { CQ_crashLastT = -1e6 };
if (isNil "CQ_crashFrontT") then { CQ_crashFrontT = time; CQ_crashFrontSig = "" };
if (isNil "CQ_crashEarlyT") then {
    CQ_crashEarlyT = if (random 1 < CQ_crashEarlyChance) then { 60 + random (CQ_crashEarlyWindow - 60) } else { -1 };
    if (CQ_crashEarlyT > 0) then { ["Crash event: an early one is due at %1 s", [round CQ_crashEarlyT]] call CQ_fnc_log };
};

// ---- front signature: any HQ built, fallen or launched, any relay change resets the clock
private _sig = str (((values CQ_hqs) apply { [_x get "id", _x get "state", _x getOrDefault ["buildDone", false]] })
    + [count ((missionNamespace getVariable ["CQ_relays", []]) select { alive (_x select 1) })]);
if (_sig != CQ_crashFrontSig) then { CQ_crashFrontSig = _sig; CQ_crashFrontT = time };

// ---- trigger
private _busy = !isNil "CQ_crashState" && { !(CQ_crashState get "secured") } && { time - (CQ_crashState get "t0") < CQ_crashCooldown };
if (!_busy && { missionNamespace getVariable ["CQ_missionStarted", false] } && { time - CQ_crashLastT > CQ_crashCooldown }) then {
    private _early = CQ_crashEarlyT > 0 && { time >= CQ_crashEarlyT };
    private _stale = time - CQ_crashFrontT > CQ_crashStagnant;
    if (_early || _stale) then {
        if (_early) then { CQ_crashEarlyT = -1 };
        ["Crash event: triggered (%1)", [["front still for " + str round ((time - CQ_crashFrontT) / 60) + " min", "early roll"] select _early]] call CQ_fnc_log;
        if (call CQ_fnc_crashStart) then { CQ_crashFrontT = time } else { CQ_crashLastT = time - CQ_crashCooldown + 120 };   // no site: retry in 2 min
    };
};

// ---- the active site
if (!isNil "CQ_crashState" && { !(CQ_crashState get "secured") }) then {
    private _s = CQ_crashState;
    private _g = _s get "group";
    if ((_s get "contactT") < 0) then {
        private _men = units _g;
        private _contact = (_men findIf { !alive _x || { damage _x > 0.05 } }) > -1
            || { behaviour (leader _g) == "COMBAT" }
            || { (allPlayers findIf { alive _x && { (leader _g) knowsAbout _x > 1.5 } }) > -1 };
        if (_contact) then {
            _s set ["contactT", time];
            CQ_crashAlarm = true; publicVariable "CQ_crashAlarm";
            ["Crash event: first contact at the wreck, the carrier drops help in %1 s", [CQ_crashTimer]] call CQ_fnc_log;
            ["crashContact", []] call CQ_fnc_say;
        };
    } else {
        private _left = CQ_crashTimer - (time - (_s get "contactT"));
        if (!(_s get "warned") && { _left <= CQ_crashWarn }) then { _s set ["warned", true]; ["crashLate", []] call CQ_fnc_say };
        if (time - (_s getOrDefault ["logT", -1e6]) > 60) then { _s set ["logT", time]; ["Crash event: %1 s before the carrier drops", [round (_left max 0)]] call CQ_fnc_log };
        if (!(_s get "dropped") && { _left <= 0 }) then { call CQ_fnc_crashDrop };
    };
};

// ---- decryption: every enemy HQ and radio tower on the map while it lasts
private _until = missionNamespace getVariable ["CQ_decryptUntil", -1];
if (_until > 0) then {
    if (time >= _until) then {
        { deleteMarker _x } forEach (missionNamespace getVariable ["CQ_decryptMarks", []]);
        CQ_decryptMarks = [];
        CQ_decryptUntil = -1; publicVariable "CQ_decryptUntil";
        ["Crash event: decryption over"] call CQ_fnc_log;
        ["decryptEnd", []] call CQ_fnc_say;
    } else {
        if (time >= (missionNamespace getVariable ["CQ_decryptNext", 0])) then {
            CQ_decryptNext = time + 30;
            { deleteMarker _x } forEach (missionNamespace getVariable ["CQ_decryptMarks", []]);
            CQ_decryptMarks = [];
            {
                private _h = _x;
                if !((_h get "state") in CQ_activeStates) then { continue };
                private _id = _h get "id";
                private _m = createMarker [format ["cq_dec_hq_%1", _id], _h get "pos"];
                _m setMarkerType CQ_hqMarkerType;
                _m setMarkerColor "ColorOPFOR";
                _m setMarkerText format ["%1 (decrypted)", [_id] call CQ_fnc_objName];
                CQ_decryptMarks pushBack _m;
                private _r = _h getOrDefault ["radio", objNull];
                if (alive _r) then {
                    private _mr = createMarker [format ["cq_dec_tw_%1", _id], getPosATL _r];
                    _mr setMarkerType "loc_Transmitter";
                    _mr setMarkerColor "ColorOPFOR";
                    _mr setMarkerText "tower";
                    CQ_decryptMarks pushBack _mr;
                };
            } forEach (values CQ_hqs);
        };
    };
};
