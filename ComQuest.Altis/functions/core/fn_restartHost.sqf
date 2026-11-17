/*
    CQ_fnc_restartHost  (the hosting player's machine: server + player)
    Sends Arma's "#restart" (the same mission reloads, every player keeps his slot). A server
    command from a hosted game is only accepted from a UI event, so it is sent from a hidden
    button's click.
*/
if (!isServer || { !hasInterface }) exitWith {};
disableSerialization;
private _d = findDisplay 46;
if (isNull _d) exitWith {};
private _b = _d ctrlCreate ["RscButton", -1];
_b ctrlSetPosition [-10, -10, 0.01, 0.01];
_b ctrlCommit 0;
_b ctrlAddEventHandler ["ButtonClick", { serverCommand "#restart" }];
ctrlActivate _b;
