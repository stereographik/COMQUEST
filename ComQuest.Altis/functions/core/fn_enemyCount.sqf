/*
    CQ_fnc_enemyCount
    Live CSAT AI on the map (crews and statics included). The 200 cap is checked against this.
*/
{ alive _x && { side group _x == east } } count allUnits
