/*
    CQ_fnc_opClient  (client, spawned once from initPlayerLocal)
    Shows the OPERATION checklist (CQ_opPub, CQ_fnc_opTick) in the map's "Operation" section
    and rewrites it whenever the server publishes a change (and after a respawn).
*/
if (!hasInterface) exitWith {};
private _render = {
    private _steps = missionNamespace getVariable ["CQ_opPub", []];
    private _txt = "<font face='PuristaSemibold' size='16' color='#F2F1DF'>OPERATION  ·  PROGRESS</font><br/><br/>";
    if (_steps isEqualTo []) then { _txt = _txt + "<font color='#A6A381'>Waiting for the operation to start.</font>" };
    {
        _x params ["_done", "_title", "_detail", "_sub"];
        _txt = _txt + format ["<font color='%1'>%2</font>  <font face='PuristaSemibold' color='#F2F1DF'>%3. %4</font><br/><font color='#A6A381'>      %5</font><br/>",
            ["#918C3B", "#BA392C"] select _done, ["[  ]", "[x]"] select _done, _forEachIndex + 1, _title, _detail];
        { _x params ["_d", "_l"]; _txt = _txt + format ["<font color='%1'>        %2  %3</font><br/>", ["#A6A381", "#7A7860"] select _d, ["·", "x"] select _d, _l] } forEach _sub;
        _txt = _txt + "<br/>";
    } forEach _steps;
    if (isNil "CQ_opRec" || { (missionNamespace getVariable ["CQ_opUnit", objNull]) != player }) then {
        if !(player diarySubjectExists "CQ_op") then { player createDiarySubject ["CQ_op", "Operation"] };
        CQ_opRec = player createDiaryRecord ["CQ_op", ["Progress", _txt]];
        CQ_opUnit = player;
    } else {
        player setDiaryRecordText [["CQ_op", CQ_opRec], ["Progress", _txt]];
    };
};
// rewritten when the server publishes a change, and for the new unit after a respawn (a poll:
// a public-variable handler would not fire on a hosting player's own machine)
private _seen = 0;
while { true } do {
    private _now = missionNamespace getVariable ["CQ_opPub", []];
    if (!(_now isEqualTo _seen) || { (missionNamespace getVariable ["CQ_opUnit", objNull]) != player }) then {
        if (alive player) then { call _render; _seen = +_now };
    };
    sleep 2;
};
