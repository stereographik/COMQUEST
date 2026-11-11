/*
    CQ_fnc_opClient  (client, spawned once from initPlayerLocal)
    Shows the OPERATION briefing (CQ_opPub, CQ_fnc_opTick) in the map's "Operation" section:
    one section per objective type with its icon, one line per object, always the same list
    (done lines in red, active lines in cream, lines not available yet greyed out). A section
    stays hidden until its first objective is available.
    A single "Progress" record is kept and rewritten (never one more per respawn). When the
    content changes, COMHAT says what changed in simple words ("New AA pit (Not found #1). Radio
    tower destroyed (OVERLORD). Check map"; radio card + chat), at most every CQ_opNotifyGap s;
    changes in between are announced together. Changes with nothing to tell (counters) stay silent.
*/
if (!hasInterface) exitWith {};
private _render = {
    private _steps = missionNamespace getVariable ["CQ_opPub", []];
    private _txt = "<font face='PuristaSemibold' size='16' color='#F2F1DF'>OPERATION  ·  PROGRESS</font><br/><br/>";
    if (_steps isEqualTo []) then { _txt = _txt + "<font color='#A6A381'>Waiting for the operation to start.</font>" };
    // a category stays hidden until its first objective is available (a line not greyed)
    private _shown = _steps select { (_x select 3) isEqualTo [] || { ((_x select 3) findIf { (_x select 0) > 0 }) > -1 } };
    {
        _x params ["_done", "_title", "_detail", "_rows", ["_icon", ""]];
        _txt = _txt + format ["<img image='%6' width='18' height='18'/>  <font color='%1'>%2</font>  <font face='PuristaSemibold' color='#F2F1DF'>%3. %4</font><br/><font color='#A6A381'>             %5</font><br/>",
            ["#918C3B", "#BA392C"] select _done, ["[  ]", "[x]"] select _done, _forEachIndex + 1, _title, _detail, _icon];
        {
            _x params ["_st", "_l"];
            _txt = _txt + format ["<font color='%1'>             %2  %3</font><br/>", ["#55534A", "#F2F1DF", "#BA392C"] select _st, ["-", "·", "x"] select _st, _l];
        } forEach _rows;
        _txt = _txt + "<br/>";
    } forEach _shown;
    if !(player diarySubjectExists "CQ_op") then { player createDiarySubject ["CQ_op", "Operation"] };
    // the existing record (it survives respawns): rewrite it, drop any duplicate
    private _recs = (player allDiaryRecords "CQ_op") select { (_x select 1) == "Progress" };
    if (_recs isEqualTo []) then {
        player createDiaryRecord ["CQ_op", ["Progress", _txt]];
    } else {
        player setDiaryRecordText [["CQ_op", (_recs select 0) select 8], ["Progress", _txt]];
        { player removeDiaryRecord ["CQ_op", _x select 8] } forEach (_recs select [1, count _recs]);
    };
};
// what changed between two versions of the briefing, in plain words for the COMHAT notice:
// "New AA pit (Not found #1)", "Radio tower destroyed (OVERLORD)", "Enemy HQ identified: OVERLORD (root)"
private _sing = createHashMapFromArray [
    ["Hostile HQs", "Enemy HQ"], ["AA pits", "AA pit"], ["HMG towers", "HMG tower"], ["Radio towers", "Radio tower"],
    ["Supply depots", "Supply depot"], ["Fuel tankers", "Fuel tanker"], ["Supply convoys", "Supply convoy"],
    ["Supply flights", "Supply flight"], ["Special forces", "Spectre team"]
];
private _diff = {
    params ["_old", "_new"];
    private _out = [];
    // the row's name: the text before its first "  ·  "
    private _label = { private _i = _this find "  ·"; private _t = [_this, _this select [0, _i]] select (_i > -1); while { count _t > 0 && { (_t select [count _t - 1]) == " " } } do { _t = _t select [0, count _t - 1] }; _t };
    {
        _x params ["_done", "_title", "_detail", "_rows"];
        private _o = _old param [_old findIf { (_x select 1) == _title }, []];
        private _oRows = _o param [3, []];
        private _one = _sing getOrDefault [_title, _title];
        if (_rows isEqualTo [] ) then {
            if (_done && { !(_o param [0, false]) }) then { _out pushBack format ["%1: done", _title] };
            continue;
        };
        {
            _x params ["_st", "_txt"];
            if (_st == 0) then { continue };                       // greyed: nothing to say yet
            private _lb = _txt call _label;
            private _or = _oRows param [_forEachIndex, [0, ""]];
            _or params ["_ost", "_otxt"];
            private _olb = _otxt call _label;
            switch (true) do {
                case (_ost == 0): { _out pushBack format ["New %1 (%2)", _one, _lb] };
                case (_st == 2 && { _ost != 2 }): { _out pushBack format ["%1 destroyed (%2)", _one, _lb] };
                case ((_olb find "Not found") == 0 && { (_lb find "Not found") != 0 }): {
                    private _hq = (_lb splitString "#") select 0;
                    while { (_hq select [count _hq - 1]) == " " } do { _hq = _hq select [0, count _hq - 1] };
                    _out pushBackUnique format ["Enemy HQ identified: %1", _hq];
                };
            };
        } forEach _rows;
    } forEach _new;
    _out
};
// polled (a public-variable handler would not fire on a hosting player's own machine)
private _seen = 0;
private _first = true;
private _pending = false;
private _news = [];
private _lastNote = -1e6;
while { true } do {
    private _now = missionNamespace getVariable ["CQ_opPub", []];
    private _respawned = (missionNamespace getVariable ["CQ_opUnit", objNull]) != player;
    if (alive player && { !(_now isEqualTo _seen) || _respawned }) then {
        if (!(_now isEqualTo _seen) && { !_first } && { _now isNotEqualTo [] }) then {
            private _d = [[_seen, []] select (_seen isEqualType 0), _now] call _diff;
            { _news pushBackUnique _x } forEach _d;
            if (_d isNotEqualTo []) then { _pending = true };
        };
        call _render;
        _seen = +_now;
        _first = false;
        CQ_opUnit = player;
    };
    if (_pending && { time - _lastNote > CQ_opNotifyGap } && { alive player }) then {
        _pending = false;
        _lastNote = time;
        // told by COMHAT, with the radio cards (not in the radio log: it would fill it up)
        // what changed, in simple words (3 at most, then "+N more")
        private _msg = (_news select [0, 3]) joinString ". ";
        if (count _news > 3) then { _msg = _msg + format [". +%1 more", count _news - 3] };
        _msg = _msg + ". Check map";
        _news = [];
        playSound "CQ_radioIn";
        ["COMHAT", _msg] call CQ_fnc_storyUi;
        systemChat format ["[COMHAT] %1", _msg];
    };
    sleep 2;
};
