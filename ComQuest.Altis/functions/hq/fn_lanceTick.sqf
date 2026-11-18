/*
    CQ_fnc_lanceTick  (server, director task "lance", La Lance only)
    A Tete de pont that moved forward (role "headOld") packs up once the new Tete is built:
    its troops, vehicles and aircraft join the nearest standing HQ (CQ_fnc_hqFallen does the move,
    and its depot and tanker are blown by the leaving troops), its map markers go, and it leaves
    the game as "Withdrawn" (not a fallen HQ: no score, not in the destroyed count).
    The new Tete failed on the way (colonists lost): the old one stays the Tete.
*/
if (!CQ_lanceOn) exitWith {};
{
    private _old = _y;
    if ((_old getOrDefault ["lRole", ""]) != "headOld" || { !((_old get "state") in CQ_activeStates) }) then { continue };
    private _heads = (values CQ_hqs) select { (_x getOrDefault ["lRole", ""]) == "head" && { (_x get "state") in CQ_activeStates } };
    if (_heads isEqualTo []) then {
        _old set ["lRole", "head"];
        ["Lance: the new Tete de pont is lost, HQ #%1 stays the Tete", [_old get "id"]] call CQ_fnc_log;
        continue;
    };
    private _new = _heads select 0;
    if !(_new get "buildDone") then { continue };
    private _id = _old get "id";
    _old set ["state", "Withdrawn"];
    _old set ["stateT", time];
    { deleteMarker format [_x, _id] } forEach ["cq_st_%1", "cq_ao_%1", "cq_aoh_%1"];
    { deleteMarker format ["cq_obj_%1_%2", _id, _forEachIndex] } forEach (_old getOrDefault ["installations", []]);
    [_old] spawn CQ_fnc_hqFallen;
    ["CSAT abandons a position", format ["HQ #%1 at grid %2 packs up: its troops join the new spearhead, HQ #%3", _id, mapGridPosition (_old get "pos"), _new get "id"]] call CQ_fnc_announce;
} forEach CQ_hqs;
