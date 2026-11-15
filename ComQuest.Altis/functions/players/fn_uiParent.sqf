/*
    CQ_fnc_uiParent  (client)
    private _d = (call CQ_fnc_uiParent) createDisplay "RscDisplayEmpty";
    The display a window opens on: the map (12) while it is open, else the game screen (46).
    A window opened on the game screen is drawn under the open map (its pictures and panels
    were lost there).
*/
private _map = findDisplay 12;
if (visibleMap && { !isNull _map }) exitWith { _map };
findDisplay 46
