/*
    CQ_fnc_opClient  (client, spawned once from initPlayerLocal)
    Shows the OPERATION briefing (CQ_opPub, CQ_fnc_opTick) in the map's "Operation" section:
    one section per objective type with its icon, one line per object, always the same list
    (done lines in red, active lines in cream, lines not available yet greyed out). A section
    stays hidden until its first objective is available.
    A single "Progress" record is kept and rewritten (never one more per respawn). When the
    content changes, COMHAT says "Objectives updated, check map" (radio card + chat) (at most every
    CQ_opNotifyGap s; changes in between are announced together).
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
// polled (a public-variable handler would not fire on a hosting player's own machine)
private _seen = 0;
private _first = true;
private _pending = false;
private _lastNote = -1e6;
while { true } do {
    private _now = missionNamespace getVariable ["CQ_opPub", []];
    private _respawned = (missionNamespace getVariable ["CQ_opUnit", objNull]) != player;
    if (alive player && { !(_now isEqualTo _seen) || _respawned }) then {
        if (!(_now isEqualTo _seen) && { !_first } && { _now isNotEqualTo [] }) then { _pending = true };
        call _render;
        _seen = +_now;
        _first = false;
        CQ_opUnit = player;
    };
    if (_pending && { time - _lastNote > CQ_opNotifyGap } && { alive player }) then {
        _pending = false;
        _lastNote = time;
        // told by COMHAT, with the radio cards (not in the radio log: it would fill it up)
        playSound "CQ_radioIn";
        ["COMHAT", "Objectives updated, check map"] call CQ_fnc_storyUi;
        systemChat "[COMHAT] Objectives updated, check map";
    };
    sleep 2;
};
