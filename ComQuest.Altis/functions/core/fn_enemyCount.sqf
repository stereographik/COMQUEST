/*
    CQ_fnc_enemyCount
    Live CSAT AI on the map (crews and statics included). The CQ_maxAI safety cap is checked against this.
    Not counted: the corridor outpost, posted guards (CQ_noCap), events (group CQ_event: EMP, crash, hostage, sabotage, hunters).
*/
{ alive _x && { side group _x == east } && { !(_x getVariable ["CQ_outpost", false]) } && { !(_x getVariable ["CQ_noCap", false]) } && { !((group _x) getVariable ["CQ_event", false]) } } count allUnits   // out of the caps: the corridor outpost, posted guards, events
