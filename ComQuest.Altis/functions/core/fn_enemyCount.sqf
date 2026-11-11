/*
    CQ_fnc_enemyCount
    Live CSAT AI on the map (crews and statics included). The CQ_maxAI safety cap is checked against this.
*/
{ alive _x && { side group _x == east } && { !(_x getVariable ["CQ_outpost", false]) } && { !(_x getVariable ["CQ_noCap", false]) } } count allUnits   // the corridor outpost is out of the caps
