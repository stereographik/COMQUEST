/*
    CQ_fnc_netTick  (server, director task, every CQ_netEvery s)            nGD: "break the net"
    The enemy radio network, the spine of the game:
      nodes   built enemy HQs whose radio tower stands
      links   two nodes within CQ_commsRange of each other
      trunk   the carrier talks to every ROOT HQ (parent -1) whose tower stands
    An HQ reached from the trunk through links is CONNECTED. A built HQ that is not (its own
    tower down, or every path to the trunk cut) is ISOLATED:
      - no reinforcement waves (CQ_fnc_hqRequestWave), no supply trucks or flights (CQ_fnc_logiTick)
      - nobody answers its calls for help, and it does not answer others (CQ_fnc_callReinf)
      - its troops dig in: nervousness FORTRESS (CQ_fnc_hqNerves)
    Published for every player's map (CQ_fnc_magMapClient): CQ_netPub =
      [nodes [[id, pos, connected]], links [[posA, posB, connected]], trunk [[rootPos, carrierPos]],
       relays [[pos, coverRadius]], base coverage radius]
    Also here, once per tick:
      - player scaling: enemy caps and wave pace follow the number of players (CQ_fnc_netScale)
      - base threat: CROSSROAD warns once when a built HQ is close enough to assault the base
*/
if (time < (missionNamespace getVariable ["CQ_netNext", 0])) exitWith {};
CQ_netNext = time + CQ_netEvery;
if (isNil "CQ_relays") then { CQ_relays = [] };

call CQ_fnc_netScale;

private _built = (values CQ_hqs) select { (_x get "state") in CQ_activeStates && { _x get "buildDone" } };
private _nodes = _built select { alive (_x get "radio") };
private _roots = _nodes select { (_x getOrDefault ["parent", -1]) == -1 };

// breadth-first search from the trunk
private _seen = _roots apply { _x get "id" };
private _queue = +_roots;
while { _queue isNotEqualTo [] } do {
    private _cur = _queue deleteAt 0;
    {
        private _id = _x get "id";
        if (!(_id in _seen) && { ((_x get "pos") distance2D (_cur get "pos")) <= CQ_commsRange }) then {
            _seen pushBack _id;
            _queue pushBack _x;
        };
    } forEach _nodes;
};

// isolation changes
{
    private _h = _x;
    private _id = _h get "id";
    private _iso = !(_id in _seen);
    if (_iso != (_h getOrDefault ["isolated", false])) then {
        _h set ["isolated", _iso];
        if (_iso) then {
            ["Enemy HQ isolated", format ["%1 is cut off from the enemy network: no reinforcements, no supplies, no help", [_id] call CQ_fnc_objName]] call CQ_fnc_announce;
            ["netCut", [[_id] call CQ_fnc_objName]] call CQ_fnc_say;
            [_h] call CQ_fnc_hqNerves;
        } else {
            ["Enemy HQ reconnected", format ["%1 is back on the enemy network", [_id] call CQ_fnc_objName]] call CQ_fnc_announce;
        };
        [_h] call CQ_fnc_hqStatusMarker;
    };
    // base threat: close enough to send an assault (CQ_assaultRange), once per HQ
    if (!(_h getOrDefault ["threatSaid", false]) && { (_h get "pos") distance2D CQ_basePos < CQ_assaultRange }) then {
        _h set ["threatSaid", true];
        ["baseThreat", [[_id] call CQ_fnc_objName, round (((_h get "pos") distance2D CQ_basePos) / 100) / 10]] call CQ_fnc_say;
        ["Base threatened", format ["%1 is %2 m from the base: it will assault it with its next wave", [_id] call CQ_fnc_objName, round ((_h get "pos") distance2D CQ_basePos)]] call CQ_fnc_announce;
    };
} forEach _built;

// relays: drop the destroyed ones
private _lost = CQ_relays select { !alive (_x select 1) };
if (_lost isNotEqualTo []) then {
    CQ_relays = CQ_relays - _lost;
    { ["Relay lost", format ["The friendly relay at grid %1 is destroyed: MAGPIE loses that coverage", mapGridPosition (_x select 2)]] call CQ_fnc_announce } forEach _lost;
    ["relayLost", []] call CQ_fnc_say;
    call CQ_fnc_relaySites;
};

// map picture for every player
private _links = [];
{
    private _a = _x;
    {
        if ((_x get "id") > (_a get "id") && { ((_x get "pos") distance2D (_a get "pos")) <= CQ_commsRange }) then {
            _links pushBack [_a get "pos", _x get "pos", (_a get "id") in _seen];
        };
    } forEach _nodes;
} forEach _nodes;
private _carrier = missionNamespace getVariable ["CQ_carrierPos", []];
private _pub = [
    _built apply { [_x get "id", _x get "pos", (_x get "id") in _seen] },
    _links,
    if (_carrier isEqualTo []) then { [] } else { _roots apply { [_x get "pos", _carrier] } },
    CQ_relays apply { [_x select 2, CQ_netCoverRelay] },
    CQ_netCoverBase
];
if !(_pub isEqualTo (missionNamespace getVariable ["CQ_netPub", []])) then {
    CQ_netPub = _pub;
    publicVariable "CQ_netPub";
};
