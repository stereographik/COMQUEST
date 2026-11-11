/*
    CQ_fnc_relaySites  (server)                                               nGD takeover
    Publishes CQ_relaySites = [[hqId, towerPos], ...]: fallen enemy HQs whose tower site has
    no friendly relay yet. An engineer near one gets "Deploy relay" (CQ_fnc_relayDeploy).
*/
private _done = CQ_relays apply { _x select 0 };
CQ_relaySites = ((values CQ_hqs) select { (_x get "state") == "Destroyed" && { !((_x get "id") in _done) } && { (_x getOrDefault ["radioPos", []]) isNotEqualTo [] } })
    apply { [_x get "id", _x get "radioPos"] };
publicVariable "CQ_relaySites";
