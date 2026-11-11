/*
    CQ_fnc_rankBoard  (client, from initPlayerLocal)
    Squad ranking under the banner of the base billboard (CQ_billboard), drawn in 3D when the
    player is within CQ_rankRange m:
        SQUAD RANKING
        [gold rifle]    1st  Alpha    1250 pts
        [silver rifle]  2nd  Bravo     830 pts
        [bronze rifle]  3rd  Charlie   410 pts
    Score = CQ_sqScore of the squad (every squad point earned, shop spending not counted;
    CQ_fnc_statsAdd, Spectre bounties). Real squads only (not the unassigned players).
    The top 3 is refreshed every 2 s; drawn every frame.
*/
if (!hasInterface) exitWith {};
CQ_rankTop = [];
[] spawn {
    while { true } do {
        private _sq = allGroups select { side _x == west && { !(_x getVariable ["CQ_solo", false]) } && { (units _x findIf { isPlayer _x }) > -1 } };
        _sq = [_sq, [], { _x getVariable ["CQ_sqScore", 0] }, "DESCEND"] call BIS_fnc_sortBy;
        CQ_rankTop = (_sq select [0, 3]) apply { [groupId _x, _x getVariable ["CQ_sqScore", 0]] };
        sleep 2;
    };
};
addMissionEventHandler ["Draw3D", {
    private _bb = missionNamespace getVariable ["CQ_billboard", objNull];
    if (isNull _bb || { player distance _bb > CQ_rankRange }) exitWith {};
    // in front of the board's lower part, on the courtyard side
    private _base = (getPosATLVisual _bb) vectorAdd ((vectorDirVisual _bb) vectorMultiply ([-0.6, 0.6] select CQ_billboardFlip));
    CQ_rankHeight params ["_top", "_step"];
    drawIcon3D ["", [0.95, 0.94, 0.87, 1], _base vectorAdd [0, 0, _top], 0, 0, 0, "SQUAD RANKING", 2, 0.045, "PuristaBold", "center"];
    if (CQ_rankTop isEqualTo []) exitWith {
        drawIcon3D ["", [0.65, 0.64, 0.51, 1], _base vectorAdd [0, 0, _top - _step], 0, 0, 0, "no squad yet", 2, 0.035, "PuristaMedium", "center"];
    };
    {
        _x params ["_name", "_pts"];
        drawIcon3D ["\A3\ui_f\data\igui\cfg\simpleTasks\types\rifle_ca.paa", CQ_rankColors select _forEachIndex,
            _base vectorAdd [0, 0, _top - _step * (_forEachIndex + 1)], 1.2, 1.2, 0,
            format ["%1  %2   %3 pts", ["1st", "2nd", "3rd"] select _forEachIndex, _name, _pts], 2, 0.04, "PuristaMedium", "center"];
    } forEach CQ_rankTop;
}];
