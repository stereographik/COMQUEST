/*
    CQ_fnc_uiParent  (client)
    private _d = (call CQ_fnc_uiParent) createDisplay "RscDisplayEmpty";
    The display a window opens on: the map (12) while it is open, else the game screen (46).
    A window opened on the game screen is drawn under the open map (its pictures and panels
    were lost there). Waits 2 frames first when it can (a window just closed is gone by then).
*/
// a window closed just before (the U menu on the second U press) is removed only at the end of
// the frame: building the new one on the map meanwhile left its first controls undrawn. Wait 2
// frames when the caller can (spawned windows)
if (canSuspend) then { private _f = diag_frameNo; waitUntil { diag_frameNo >= _f + 2 } };
private _map = findDisplay 12;
// fallback (CQ_tabletCloseMap): close the map first, the window then opens on the game screen
if (visibleMap && { CQ_tabletCloseMap }) then { openMap false };
if (visibleMap && { !isNull _map }) exitWith { _map };
findDisplay 46
