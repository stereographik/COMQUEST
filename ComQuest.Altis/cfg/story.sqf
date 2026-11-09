/*
    ComQuest storytelling: what the players hear.  (loaded by CQ_fnc_settings)
    Serious milsim, with the dry irony of an old staff officer who has seen several wars.
    Rules: no humour on alarms, no exact numbers, NO LOCATIONS (grids, places: debug log only;
    players find positions with the direction finder), objectives by NATO name, intel stays thin:
    HQ building status, supplies received, reactions to the players' own kills, alarms.
    Speakers:
      CROSSROAD  friendly HQ           notification card + Side chat
      MAGPIE     drone operator         reports only what her UAVs identify (CQ_fnc_magTick): the
                                        scripted MAGPIE lines below are no longer played
      COMHAT     enemy radio, translated  only heard through a standing radio tower
    key -> list of variants (one picked at random); variant -> lines said in order.
    %1, %2... are filled by the caller (see the comment on each key).
*/
CQ_objNames = ["ALPHA","BRAVO","CHARLIE","DELTA","ECHO","FOXTROT","GOLF","HOTEL","INDIA","JULIET","KILO","LIMA","MIKE",
    "NOVEMBER","OSCAR","PAPA","QUEBEC","ROMEO","SIERRA","TANGO","UNIFORM","VICTOR","WHISKEY","XRAY","YANKEE","ZULU"];

CQ_story = createHashMapFromArray [
    // [] - mission start
    ["carrier", [
        [["CROSSROAD", "CROSSROAD to all stations. CSAT has parked a carrier group offshore. They didn't come for the beaches."]]
    ]],
    // [obj] - an HQ site is being secured (no location: players find it with the RDF)
    ["hqNew", [
        [["MAGPIE", "New enemy position, designated Objective %1. They're digging in. Find it with your direction finder."]],
        [["MAGPIE", "Enemy troops securing ground somewhere out there. Designating it Objective %1."]]
    ]],
    // [obj] - construction stages
    ["stage1", [
        [["MAGPIE", "%1: command post going up."]]
    ]],
    ["stage3", [
        [["MAGPIE", "%1: sandbags and a depot. They plan to stay."]],
        [["MAGPIE", "%1: depot and radio mast going up."]]
    ]],
    ["operational", [
        [["CROSSROAD", "%1 is operational. Radio mast, depot, triple-A. In my experience it's cheaper to knock things down before the paint dries."]],
        [["CROSSROAD", "%1 is operational. Radio mast, depot, triple-A. Priority target. Bring friends."]]
    ]],
    // [obj, remaining positions]
    ["fallen", [
        [["CROSSROAD", "%1 has fallen. Well done. %2 positions remain. The war, regrettably, does not stop for tea."]],
        [["CROSSROAD", "%1 has fallen. Good work. %2 positions left on the island. Don't get comfortable."]]
    ]],
    ["fallenEarly", [
        [["CROSSROAD", "%1 wiped out before they could finish it. Textbook."]]
    ]],
    // [obj] - supplies received
    ["airSupply", [
        [["COMHAT", "...%1, supply drop received, over."], ["CROSSROAD", "%1 just restocked. Somebody should look into their logistics. With explosives."]],
        [["COMHAT", "...%1, pod on the ground, ammunition and fuel, over."]]
    ]],
    ["truckSupply", [
        [["COMHAT", "...%1, convoy arrived, fuel and ammunition."]],
        [["COMHAT", "...%1, supply truck in, unloading now."]]
    ]],
    ["reinf", [
        [["COMHAT", "...reinforcements at %1, two sections."]],
        [["COMHAT", "...%1, fresh troops arrived, over."]]
    ]],
    // [obj] - the players' own kills
    ["killTower", [
        [["CROSSROAD", "%1 has gone quiet on the net. Silence suits them."]]
    ]],
    ["killDepot", [
        [["CROSSROAD", "Large secondary at %1. That was their ammunition depot. Was."]]
    ]],
    ["killCommander", [
        [["COMHAT", "The commander is down! Who has command?"], ["CROSSROAD", "Good question. Let's keep them asking."]]
    ]],
    // []
    ["killSupplyBird", [
        [["CROSSROAD", "Supply bird down. Somewhere a CSAT quartermaster is filling out a very long form."]]
    ]],
    // [obj] - alarm, no humour
    ["assault", [
        [["CROSSROAD", "FLASH, FLASH. Enemy assault force moving on the airfield from %1. All units, defend the base."]]
    ]],
    // [] - an HQ spotted the players, no humour
    ["contact", [
        [["COMHAT", "Contact! Enemy infantry, requesting support!"], ["CROSSROAD", "You've been made. Expect company, likely airborne."]]
    ]],
    // [obj, n] - players captured an HQ commander: his network goes on the map
    ["cmdCaptured", [
        [["CROSSROAD", "Commander from %1 in custody. He's been unusually talkative. %2 enemy positions now on your maps."]]
    ]],
    // [] - the friendly commander is dead: mission lost, no humour
    ["defeat", [
        [["CROSSROAD", "All stations, this is CROSSROAD. Colonel Harlan is down. The operation is over. Fall back to the coast."]]
    ]],
    // [obj] - a red flare over an HQ: heavy support, no humour
    ["flare", [
        [["CROSSROAD", "Red flare over %1. They're calling everything they have."]]
    ]],
    // [obj] - the root HQ is attacked: every child HQ rallies to it
    ["rootDefend", [
        [["COMHAT", "...all units, %1 under attack, converge, converge!"], ["CROSSROAD", "You've kicked the hornets' nest. Everything they own is heading your way."]]
    ]],
    // []
    ["victory", [
        [["CROSSROAD", "Last position has fallen. The CSAT landing on Altis is broken. Mission accomplished. Bring them home."]]
    ]],
    // ---- MAGPIE, driven by the UAVs (CQ_fnc_magTick) ----
    // [summary] - every CQ_magReportEvery s, when there is something new
    ["magReport", [
        [["MAGPIE", "Sweep report. %1"]],
        [["MAGPIE", "Updated picture. %1"]]
    ]],
    // [airframe]
    ["magLaunch", [
        [["MAGPIE", "%1 is airborne. Eyes up shortly."]]
    ]],
    ["magDown", [
        [["MAGPIE", "Lost the %1. Replacement airframe in eight minutes."]],
        [["MAGPIE", "%1 is down. I'll have another one on the runway in eight."]]
    ]]
];
CQ_uiCardWidth = 620;                     // notification card width in pixels (message text block ~560 px)
CQ_uiCardMax = 5;                         // cards on screen at once (more wait in line)
CQ_storyLineGap = 4;          // seconds between two lines of the same message
CQ_storyCooldown = 20;        // the same message about the same objective at most every 20 s
