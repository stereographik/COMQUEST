/*
    CQ_fnc_empProgram  (server, from the terminal holder's confirmed map pin: CQ_fnc_empClient)
    [_player, _pos] remoteExec ["CQ_fnc_empProgram", 2];
    The captured EMP's target, once and final: shown to everyone (cq_emp_tgt), the terminal taken
    from the player (it has done its job), the Stomper goes there after loading the device (its
    plan stacks, CQ_fnc_empStomper). CQ_empPtsStrike points go to _player when it goes off.
*/
params ["_p", "_pos"];
if (!isServer || { isNil "CQ_empState" } || { CQ_empPhase != "defused" }) exitWith {};
private _s = CQ_empState;
if ((_s get "target") isNotEqualTo []) exitWith {};      // already programmed: final
_pos = [_pos select 0, _pos select 1, 0];
_s set ["target", _pos];
_s set ["programmer", _p];
CQ_empProgrammed = true; publicVariable "CQ_empProgrammed";
// the terminal goes (local commands on its holder's machine)
[_p, "B_UavTerminal"] remoteExec ["unlinkItem", _p];
[_p, "B_UavTerminal"] remoteExec ["removeItem", _p];
private _m = createMarker ["cq_emp_tgt", _pos];
_m setMarkerType "mil_destroy";
_m setMarkerColor "ColorOrange";
_m setMarkerText " EMP target";
private _m2 = createMarker ["cq_emp_tgtR", _pos];
_m2 setMarkerShape "ELLIPSE";
_m2 setMarkerSize [CQ_empHitR, CQ_empHitR];
_m2 setMarkerBrush "Border";
_m2 setMarkerColor "ColorOrange";
["EMP event: target programmed by %1 at %2 (%3 m from the Stomper, device loaded: %4)",
    [name _p, mapGridPosition _pos, round ((_s get "stomper") distance2D _pos), _s get "loaded"]] call CQ_fnc_log;
["empProgrammed", [name _p, mapGridPosition _pos]] call CQ_fnc_say;
if (!isNil "CQ_empKey") then { [CQ_empKey, 1, "EMP device", format ["defused, target grid %1", mapGridPosition _pos], _p] call CQ_fnc_opSide };
