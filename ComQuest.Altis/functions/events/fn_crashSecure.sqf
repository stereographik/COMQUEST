/*
    CQ_fnc_crashSecure  (server, from the crate's hold action, or the debug panel)
    [_player] remoteExec ["CQ_fnc_crashSecure", 2];
    The crate is ours: the drop countdown stops, and the decryption starts (CQ_crashDecrypt s):
    MAGPIE identifies everywhere (CQ_fnc_magTick) and every enemy HQ and radio tower is shown on
    the map (CQ_fnc_crashTick keeps the markers).
*/
params [["_p", objNull]];
if (!isServer) exitWith {};
if (!isNull _p && { isNil "CQ_crashState" || { CQ_crashState get "secured" } }) exitWith {};   // already taken (the debug button always works)
if (!isNil "CQ_crashState") then {
    CQ_crashState set ["secured", true];
    private _c = CQ_crashState get "crate";
    if (!isNull _c) then { _c setVariable ["CQ_secured", true, true] };
};
CQ_crashAlarm = false; publicVariable "CQ_crashAlarm";
deleteMarker "cq_crash";
CQ_decryptUntil = time + CQ_crashDecrypt;
publicVariable "CQ_decryptUntil";
CQ_decryptMarks = [];                         // rebuilt by CQ_fnc_crashTick at once
CQ_decryptNext = 0;
private _who = if (isNull _p) then { "Command" } else { name _p };
if (!isNull _p) then { [_p, 100, "crash crate"] call CQ_fnc_scoreAdd };
["Crash event: crate secured by %1, decryption for %2 s", [_who, CQ_crashDecrypt]] call CQ_fnc_log;
["crashSecured", [_who]] call CQ_fnc_say;
