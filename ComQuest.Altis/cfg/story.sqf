/*
    ComQuest storytelling: what the players hear.  (loaded by CQ_fnc_settings)
    Serious milsim, with the dry irony of an old staff officer who has seen several wars.
    Rules: no humour on alarms, no exact numbers, objectives by NATO name, intel stays thin:
    HQ building status, supplies received, reactions to the players' own kills, alarms.
    Speakers:
      CROSSROAD  friendly HQ           notification card + Side chat
      MAGPIE     drone operator         subtitle, facts only
      INTERCEPT  enemy radio, translated  red text; only heard while that HQ's radio works
    key -> list of variants (one picked at random); variant -> lines said in order.
    %1, %2... are filled by the caller (see the comment on each key).
*/
CQ_objNames = ["ALPHA","BRAVO","CHARLIE","DELTA","ECHO","FOXTROT","GOLF","HOTEL","INDIA","JULIET","KILO","LIMA","MIKE",
    "NOVEMBER","OSCAR","PAPA","QUEBEC","ROMEO","SIERRA","TANGO","UNIFORM","VICTOR","WHISKEY","XRAY","YANKEE","ZULU"];

CQ_story = createHashMapFromArray [
    // [] - mission start
    ["carrier", [
        [["CROSSROAD", "CROSSROAD to all stations. CSAT has parked a carrier off the east coast. They didn't come for the beaches."]]
    ]],
    // [obj, grid] - an HQ site is being secured
    ["hqNew", [
        [["MAGPIE", "New enemy position near grid %2, designated Objective %1. They're digging in."]],
        [["MAGPIE", "Enemy troops securing ground near grid %2. Designating it Objective %1."]]
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
        [["INTERCEPT", "...%1, supply drop received, over."], ["CROSSROAD", "%1 just restocked. Somebody should look into their logistics. With explosives."]],
        [["INTERCEPT", "...%1, pod on the ground, ammunition and fuel, over."]]
    ]],
    ["truckSupply", [
        [["INTERCEPT", "...%1, convoy arrived, fuel and ammunition."]],
        [["INTERCEPT", "...%1, supply truck in, unloading now."]]
    ]],
    ["reinf", [
        [["INTERCEPT", "...reinforcements at %1, two sections."]],
        [["INTERCEPT", "...%1, fresh troops arrived, over."]]
    ]],
    // [obj] - the players' own kills
    ["killTower", [
        [["CROSSROAD", "%1 has gone quiet on the net. Silence suits them."]]
    ]],
    ["killDepot", [
        [["CROSSROAD", "Large secondary at %1. That was their ammunition depot. Was."]]
    ]],
    ["killCommander", [
        [["INTERCEPT", "The commander is down! Who has command?"], ["CROSSROAD", "Good question. Let's keep them asking."]]
    ]],
    // []
    ["killSupplyBird", [
        [["CROSSROAD", "Supply bird down. Somewhere a CSAT quartermaster is filling out a very long form."]]
    ]],
    // [obj] - alarm, no humour
    ["assault", [
        [["CROSSROAD", "FLASH, FLASH. Enemy assault force moving on the airfield from %1. All units, defend the base."]]
    ]],
    // [grid] - an HQ spotted the players, no humour
    ["contact", [
        [["INTERCEPT", "Contact! Enemy infantry grid %1, requesting support!"], ["CROSSROAD", "You've been made. Expect company, likely airborne."]]
    ]],
    // []
    ["victory", [
        [["CROSSROAD", "Last position has fallen. The CSAT landing on Altis is broken. Mission accomplished. Bring them home."]]
    ]]
];
CQ_storyLineGap = 4;          // seconds between two lines of the same message
CQ_storyCooldown = 20;        // the same message about the same objective at most every 20 s
