/*
    cfg\story.sqf - ComQuest storytelling: what the players hear.  (loaded by CQ_fnc_settings)

    Tone: serious milsim with the gentle rudeness of an old staff officer. No humour on alarms.
    NO LOCATIONS in any line (grids and places go to the debug log only).

    Speakers
      CROSSROAD  friendly HQ, Colonel Harlan. Backhanded compliments, understatement,
                 impatience dressed as politeness. Zero irony on alarms.
      MAGPIE     UAV operator (CQ_fnc_magTick). Dry facts, one barb at most. Speaks only for her
                 drones: her lines are played only for keys starting with "mag".
      COMHAT     enemy radio, translated. Heard only through a standing radio tower. Rude to its
                 own side, never to the players. Cut mid-sentence if its tower falls.

    Acts (CQ_fnc_actTick, from the carrier's supplies)
      1 landing (> 60 %)   2 expansion (> 30 %)   3 last push (> 0 %)   4 endgame (carrier empty)
    A key may have act variants "key@1".."key@4": the current act's variants are used when they
    exist, else the plain "key". A variant is not repeated before all the others were used.

    Format: key -> list of variants; variant -> lines [speaker, text] said in order.
    %1, %2... are filled by the caller (noted above each key).
*/
CQ_objNames = ["ALPHA","BRAVO","CHARLIE","DELTA","ECHO","FOXTROT","GOLF","HOTEL","INDIA","JULIET","KILO","LIMA","MIKE",
    "NOVEMBER","OSCAR","PAPA","QUEBEC","ROMEO","SIERRA","TANGO","UNIFORM","VICTOR","WHISKEY","XRAY","YANKEE","ZULU"];

CQ_story = createHashMapFromArray [

    // ================================================================ campaign
    // [] - mission start (act 1 opening)
    ["carrier", [
        [["CROSSROAD", "CROSSROAD to all stations. CSAT has parked a carrier group offshore. They didn't come for the beaches."], ["CROSSROAD", "Get your stuff up fast, soldiers. Pick your class and kit at the base, grab a ride, and find out where they intend to land."]],
        [["CROSSROAD", "CROSSROAD to all stations. Enemy carrier group off our coast. They intend to stay. We intend otherwise."], ["CROSSROAD", "Get your stuff up fast, soldiers. Pick your class and kit at the base, grab a ride, and find out where they intend to land."]],
        [["CROSSROAD", "Good morning, all stations. CSAT has brought a carrier and a great deal of confidence. Let's relieve them of both."], ["CROSSROAD", "Get your stuff up fast, soldiers. Pick your class and kit at the base, grab a ride, and find out where they intend to land."]]
    ]],
    // [] - act openings
    ["act2", [
        [["CROSSROAD", "CROSSROAD to all stations. They're no longer landing, they're settling in. Adjust accordingly."]],
        [["CROSSROAD", "All stations. The enemy has stopped testing the water and started building on it. The polite phase is over."]],
        [["CROSSROAD", "CROSSROAD to all stations. Their network is growing faster than our patience. Pick up the pace."]]
    ]],
    ["act3", [
        [["CROSSROAD", "All stations. The carrier is scraping the bottom of the barrel. So, I suspect, are you. Finish it."]],
        [["CROSSROAD", "CROSSROAD to all stations. They're down to their last reserves. Wounded animals bite. Act accordingly."]],
        [["CROSSROAD", "All stations. One more push and their carrier has nothing left to send. Don't stop now."]]
    ]],
    ["act4", [
        [["CROSSROAD", "The carrier has turned for home. Whatever is left on Altis is all they have. Hunt it down."]],
        [["CROSSROAD", "All stations. No more ships, no more drops. What remains on the island is stranded. Clean it up."]],
        [["CROSSROAD", "Their carrier is empty. Every position still standing is a position that knows it's alone. Remind them."]]
    ]],
    // [] - friendly commander killed: mission lost, no humour
    ["defeat", [
        [["CROSSROAD", "All stations, this is CROSSROAD. Colonel Harlan is down. The operation is over. Fall back to the coast."]],
        [["CROSSROAD", "All stations. Command is lost. Colonel Harlan is dead. Break contact and withdraw. CROSSROAD out."]]
    ]],
    // []
    ["victory", [
        [["CROSSROAD", "Last position has fallen. The CSAT landing on Altis is broken. Mission accomplished. Bring them home."]],
        [["CROSSROAD", "All stations. No enemy positions remain. Well done. Genuinely. Don't let it go to your heads."]],
        [["CROSSROAD", "That's the last of them. Altis is ours. I'll be writing very dull reports about this for months. Thank you."]]
    ]],

    // ================================================================ SITREP every 20 min
    // [carrier %, known positions, our losses (word)]
    ["sitrep@1", [
        [["CROSSROAD", "SITREP. Carrier at %1 percent. We know of %2 positions. Losses %3. Find me more."]],
        [["CROSSROAD", "SITREP. Carrier stocks at %1 percent. %2 enemy positions known. Our losses: %3. Early days."]],
        [["CROSSROAD", "SITREP. Carrier at %1 percent, %2 positions on our board, losses %3. Keep feeding me better numbers."]]
    ]],
    ["sitrep@2", [
        [["CROSSROAD", "SITREP. %2 positions known, carrier at %1 percent, our losses %3. Momentum matters now."]],
        [["CROSSROAD", "SITREP. Carrier at %1 percent. %2 enemy positions known. Losses %3. They're spreading. So should we."]],
        [["CROSSROAD", "SITREP. %2 known positions, carrier down to %1 percent, our losses %3. The map is getting crowded."]]
    ]],
    ["sitrep@3", [
        [["CROSSROAD", "SITREP. Carrier nearly dry at %1 percent. %2 positions known. Losses %3. Don't ease off."]],
        [["CROSSROAD", "SITREP. Carrier at %1 percent and falling. %2 positions left on our board. Losses %3. Nearly there."]],
        [["CROSSROAD", "SITREP. They have %1 percent left on that ship. %2 known positions. Losses %3. Close it out."]]
    ]],
    ["sitrep@4", [
        [["CROSSROAD", "SITREP. Their carrier is gone. %2 positions holding out. Losses %3. Patience and thoroughness."]],
        [["CROSSROAD", "SITREP. Carrier empty. %2 known positions still holding. Our losses: %3. Finish the job."]],
        [["CROSSROAD", "SITREP. No more reinforcements for them. %2 positions to go. Losses %3. Tidy up, gentlemen."]]
    ]],

    // ================================================================ enemy HQs
    // [obj] - construction (no players' knowledge: heard only through the HQ's own tower)
    ["hqNew", []],
    ["stage1", []],
    ["stage3", []],
    // [obj] - HQ finished
    ["operational@1", [
        [["COMHAT", "...%1 reporting operational. Mast up, depot stocked."], ["CROSSROAD", "%1 is open for business. Let's close it."]],
        [["COMHAT", "...%1 to command, all stations operational. Ready to receive."], ["CROSSROAD", "%1 is up and running. In my experience it's cheaper to knock things down before the paint dries."]],
        [["COMHAT", "...%1, construction complete, mast is live."], ["CROSSROAD", "They've finished %1. Radio mast, depot, triple-A. Priority target. Bring friends."]]
    ]],
    ["operational@2", [
        [["COMHAT", "...%1 operational. Second shift can sleep now."], ["CROSSROAD", "%1 is up. They're getting good at this. Discourage them."]],
        [["COMHAT", "...%1 operational, awaiting orders."], ["CROSSROAD", "Another one. %1 is operational. They're building faster than you're demolishing."]],
        [["COMHAT", "...%1 is up. Send the next team forward."], ["CROSSROAD", "%1 is live. That's a habit of theirs I'd like broken."]]
    ]],
    ["operational@3", [
        [["COMHAT", "...%1 operational. Don't lean on the walls."], ["CROSSROAD", "%1 is up, held together by optimism. Test it."]],
        [["COMHAT", "...%1 operational. Barely. Half the crates are empty."], ["CROSSROAD", "%1 is up, held together with spit and hope. Knock it over."]],
        [["COMHAT", "...%1, we're up. Don't ask what we built it with."], ["CROSSROAD", "%1 is operational, technically. A stiff breeze would do. A satchel charge would do better."]]
    ]],
    // [obj, remaining positions]
    ["fallen@1", [
        [["CROSSROAD", "%1 is rubble. %2 left. Splendid. Now do it again, slightly faster."]],
        [["CROSSROAD", "%1 has fallen. Well done. Do try to make a habit of it."]],
        [["CROSSROAD", "%1 is gone. %2 positions remain. A promising start. Don't let it be the only one."]],
        [["CROSSROAD", "Confirmed, %1 destroyed. %2 to go. The war, regrettably, does not stop for tea."]]
    ]],
    ["fallen@2", [
        [["CROSSROAD", "%1 destroyed. %2 to go. I shan't applaud, but I did nod."]],
        [["CROSSROAD", "%1 has fallen. %2 positions left on the island. Don't get comfortable."]],
        [["CROSSROAD", "%1 is finished. Good. %2 more, and then you may have a sandwich."]],
        [["CROSSROAD", "Scratch %1. %2 remain. They'll notice that one."]]
    ]],
    ["fallen@3", [
        [["CROSSROAD", "%1 gone. %2 remaining. Their maps are getting very empty."]],
        [["CROSSROAD", "%1 is down. %2 left. They're running out of island and of ideas."]],
        [["CROSSROAD", "%1 has fallen. %2 positions remain. You can smell the end from here."]],
        [["CROSSROAD", "Good. %1 is done. %2 to go, and their carrier can't replace much more."]]
    ]],
    ["fallen@4", [
        [["CROSSROAD", "%1 is finished. %2 left to mop up. Be thorough, not heroic."]],
        [["CROSSROAD", "%1 has fallen. %2 left, and nobody is coming for them."]],
        [["CROSSROAD", "%1 destroyed. %2 stranded positions remain. Finish it cleanly."]],
        [["CROSSROAD", "Another one gone. %2 left. I can almost see my desk again."]]
    ]],
    // [obj] - destroyed before it was finished
    ["fallenEarly", [
        [["CROSSROAD", "%1 died in the cradle. Efficient. Slightly unsporting. I approve."]],
        [["CROSSROAD", "%1 wiped out before they could finish it. Textbook."]],
        [["CROSSROAD", "%1 never got its roof on. That's how it's done."]],
        [["CROSSROAD", "%1 is gone before the paint dried. I may frame this one."]]
    ]],
    // [obj]
    ["killCommander", [
        [["COMHAT", "...%1 command post, respond. Respond!"], ["CROSSROAD", "They're calling a dead man. Let them keep trying."]],
        [["COMHAT", "The commander is down! Who has command?"], ["CROSSROAD", "Good question. Let's keep them asking."]],
        [["COMHAT", "...%1, commander is dead, repeat, commander is dead!"], ["CROSSROAD", "Their commander at %1 has resigned. Rather abruptly."]],
        [["COMHAT", "...who's in charge at %1? Anyone?"], ["CROSSROAD", "Nobody, by the sound of it. Excellent."]]
    ]],
    // [obj, positions revealed]
    ["cmdCaptured", [
        [["CROSSROAD", "The %1 commander is in the bag. %2 positions on your maps. He asked for a lawyer. We gave him a biscuit."]],
        [["CROSSROAD", "Commander from %1 in custody. He's been unusually talkative. %2 enemy positions now on your maps."]],
        [["CROSSROAD", "We have the %1 commander. A cup of tea and he sang. %2 positions marked."]],
        [["CROSSROAD", "%1's commander is ours. He's given us %2 positions and a list of complaints about his superiors."]]
    ]],
    // [obj]
    ["killDepot", [
        [["CROSSROAD", "%1 depot destroyed. That's their next week of ammunition, gone in a minute."]],
        [["CROSSROAD", "Large secondary at %1. That was their ammunition depot. Was."]],
        [["CROSSROAD", "%1's depot just went up. Their quartermaster will be having a difficult afternoon."]],
        [["CROSSROAD", "Depot destroyed at %1. Nice fireworks. Let's not make it a festival."]]
    ]],
    ["killTower", [
        [["CROSSROAD", "Mast down at %1. Their radio net just got a lot quieter."]],
        [["CROSSROAD", "%1 has gone quiet on the net. Silence suits them."]],
        [["CROSSROAD", "Radio mast down at %1. They'll have to shout. Badly."]],
        [["CROSSROAD", "%1 is off the air. One less voice in my ear."]]
    ]],

    // ================================================================ enemy logistics
    // [obj] - heard through the main HQ's tower
    ["airSupply@1", [
        [["COMHAT", "...%1, resupply landed, everything accounted for."]],
        [["COMHAT", "...%1, supply drop received, over."], ["CROSSROAD", "%1 just restocked. Somebody should look into their logistics. With explosives."]],
        [["COMHAT", "...%1, pod on the ground, ammunition and fuel, over."]]
    ]],
    ["airSupply@2", [
        [["COMHAT", "...%1, pod received. Someone tell the carrier the fuel is short. Again."]],
        [["COMHAT", "...%1, resupply received. Tell the carrier we need twice that."], ["CROSSROAD", "Their supply birds are getting through. That's a flight path someone should ruin."]],
        [["COMHAT", "...%1, pod down. Short again. Who signed for this?"]]
    ]],
    ["airSupply@3", [
        [["COMHAT", "...%1, drop received. One pod. They said two."], ["CROSSROAD", "Their supply line is gasping. Help it along."]],
        [["COMHAT", "...%1, drop received. It's half empty. Is this a joke?"], ["CROSSROAD", "They're getting scraps now. Keep it that way."]],
        [["COMHAT", "...%1, last pod they could spare, apparently. Make it count."]]
    ]],
    ["truckSupply@1", [
        [["COMHAT", "...%1, convoy in, depot restocked."]],
        [["COMHAT", "...%1, convoy arrived, fuel and ammunition."]],
        [["COMHAT", "...%1, supply truck in, unloading now."]]
    ]],
    ["truckSupply@2", [
        [["COMHAT", "...%1, convoy arrived. Who loaded this truck? Half of it is tents."]],
        [["COMHAT", "...%1, convoy finally in. Tell the driver he can walk back to the carrier."]],
        [["COMHAT", "...%1, truck arrived. Late. Again."]]
    ]],
    ["truckSupply@3", [
        [["COMHAT", "...%1, last convoy for a while. Count every round."]],
        [["COMHAT", "...%1, truck's in. One truck. That's all they sent."]],
        [["COMHAT", "...%1, convoy arrived with what's left. Ration it."]]
    ]],
    // [obj]
    ["reinf@1", [
        [["COMHAT", "...%1, two sections in, deploying to the perimeter."]],
        [["COMHAT", "...reinforcements at %1, two sections."]],
        [["COMHAT", "...%1, fresh troops arrived, over."]]
    ]],
    ["reinf@2", [
        [["COMHAT", "...%1, reinforcements arrived. Try not to lose these ones."]],
        [["COMHAT", "...%1, reinforcements in. Spread them out, they're not tourists."]],
        [["COMHAT", "...%1, two sections arrived. Keep them away from the depot, they eat everything."]]
    ]],
    ["reinf@3", [
        [["COMHAT", "...%1, more men. Fewer rifles than men, but more men."]],
        [["COMHAT", "...%1, these are the last sections they'll send us. Don't waste them."]],
        [["COMHAT", "...%1, reinforcements. Cooks and drivers, mostly. Hand them rifles."]]
    ]],
    // []
    ["killSupplyBird", [
        [["CROSSROAD", "Supply flight shot down. That's a great deal of ammunition now decorating the hillside."]],
        [["CROSSROAD", "Supply bird down. Somewhere a CSAT quartermaster is filling out a very long form."]],
        [["CROSSROAD", "Their supply helicopter is in pieces. That's a lot of ammunition that won't be shot at you."]],
        [["CROSSROAD", "Supply flight destroyed. Excellent. Do it again when they send another."]]
    ]],

    // ================================================================ combat (no humour)
    // [] - an HQ spotted the players
    ["contact@1", [
        [["COMHAT", "...contact! Enemy patrol, all units respond!"], ["CROSSROAD", "You've been spotted. They'll be calling friends. Be ready."]],
        [["COMHAT", "Contact! Enemy infantry, requesting support!"], ["CROSSROAD", "You've been made. Expect company, likely airborne."]],
        [["COMHAT", "...contact, contact! All patrols converge!"], ["CROSSROAD", "They've seen you. Reinforcements inbound. Stay sharp."]]
    ]],
    ["contact@2", [
        [["COMHAT", "...enemy contact, requesting everything in range!"], ["CROSSROAD", "Spotted. Their patrols are converging. Pick your ground."]],
        [["COMHAT", "Enemy in the perimeter! Every squad, move!"], ["CROSSROAD", "You're spotted. Their patrols are closing in. Move or dig in."]],
        [["COMHAT", "...contact! Send everything nearby!"], ["CROSSROAD", "They know you're there. Expect a crowd."]]
    ]],
    ["contact@3", [
        [["COMHAT", "...contact! We can't hold them alone!"], ["CROSSROAD", "They've seen you and they're scared. Scared men shoot first."]],
        [["COMHAT", "They're here! They're here! Anyone, respond!"], ["CROSSROAD", "You've been spotted. They're desperate, which makes them dangerous."]],
        [["COMHAT", "...contact, we need help, now!"], ["CROSSROAD", "Contact. They'll throw whatever they have left. Hold."]]
    ]],
    ["contact@4", [
        [["COMHAT", "...contact. Make it count, there's no one left to call."], ["CROSSROAD", "Contact. They're cornered. Careful."]],
        [["COMHAT", "...they found us. Hold the line."], ["CROSSROAD", "Contact. No help is coming for them. Make it quick."]],
        [["COMHAT", "...enemy contact. Everyone to the perimeter."], ["CROSSROAD", "They've seen you. They have nowhere to go. Neither should they."]]
    ]],
    // [obj] - red flare
    ["huntLaunch", [
        [["COMHAT", "...%1 to command, request Spectre. Find them. Bring back their tags."]],
        [["COMHAT", "...%1, Spectre authorised. High jump, tonight's guests are the ones with the rifles."]],
        [["COMHAT", "...command to %1, Spectre is in the air. Stop crying on the net."]]
    ]],
    ["huntContact", [
        [["CROSSROAD", "That last contact was quiet, quick and well-led. Special forces. They're hunting a squad of ours. Watch your trail."]],
        [["CROSSROAD", "Suppressed fire, good discipline. That's not a garrison. Somebody sent professionals after you."]],
        [["CROSSROAD", "All stations, enemy special forces in the field. They don't patrol, they hunt. Move like it."]]
    ]],
    ["huntDown", [
        [["CROSSROAD", "Their special forces team is down. Somewhere a colonel is filing a very awkward report."]],
        [["CROSSROAD", "Spectre team neutralised. Good work. The squad that did it has earned a bonus."]],
        [["CROSSROAD", "That was their best, and it's lying in the grass. Well done."]]
    ]],
    ["flare", [
        [["CROSSROAD", "Red flare. They're emptying the garrison on you. Stand fast."]],
        [["CROSSROAD", "Red flare over %1. They're calling everything they have."]],
        [["CROSSROAD", "Red flare at %1. Heavy support inbound. Brace."]],
        [["CROSSROAD", "Flare over %1. Their garrison and roaming squads are coming. Get ready."]]
    ]],
    // [obj] - the root HQ is attacked
    ["rootDefend", [
        [["COMHAT", "...all units, %1 under attack, converge, converge!"], ["CROSSROAD", "You've kicked the hornets' nest. Everything they own is heading your way."]],
        [["COMHAT", "...%1 is the heart, protect %1! Everyone!"], ["CROSSROAD", "Every position they founded is sending troops. Dig in."]],
        [["COMHAT", "...all positions, rally to %1, now!"], ["CROSSROAD", "That got their attention. The whole network is coming. Hold."]]
    ]],
    // [obj] - attack on the base
    ["assault", [
        [["CROSSROAD", "FLASH, FLASH. Enemy assault force moving on the airfield from %1. All units, defend the base."]],
        [["CROSSROAD", "FLASH. Enemy force inbound on the base. All units return and defend."]],
        [["CROSSROAD", "FLASH, FLASH. The airfield is under threat. Everyone back. Now."]]
    ]],
    // nGD [hq name] - an enemy HQ cut off from its network
    ["netCut", [
        [["CROSSROAD", "%1 just went dark on their net. No reinforcements will reach it. Finish it."]],
        [["CROSSROAD", "That's %1 cut off. They're on their own now. They'll dig in, so go in heavy."]],
        [["CROSSROAD", "Network break at %1. Nothing gets in, nothing gets out. Good work."]]
    ]],
    // nGD [hq name, km] - a built HQ close enough to assault the base
    ["baseThreat", [
        [["CROSSROAD", "%1 sits %2 km from the airfield. Close enough to come for me. Deal with it, or get ready to defend."]],
        [["CROSSROAD", "Heads up: %1 is %2 km out. Their next wave comes here, not west."]]
    ]],
    // nGD [hq name] - a relay put up on a fallen HQ's tower site
    ["relayUp", [
        [["CROSSROAD", "Relay up on the ruins of %1. MAGPIE has eyes out there now."]],
        [["CROSSROAD", "Good. %1 is our node now. Expect them to want it back."]]
    ]],
    // nGD [] - a friendly relay destroyed
    ["relayLost", [
        [["CROSSROAD", "We've lost a relay. MAGPIE is blind out there again."]],
        [["CROSSROAD", "Relay down. Somebody go put it back."]]
    ]],
    // [] - assault infantry storming the command post
    ["breach", [
        [["CROSSROAD", "They're at my door. I'd appreciate company. Armed company."]],
        [["CROSSROAD", "Hostiles in the command post. Get in here, all of you."]],
        [["COMHAT", "...we're inside their command post. Find the colonel!"], ["CROSSROAD", "They're inside. I'm holding the stairs with a pistol and strong opinions."]]
    ]],

    // ================================================================ players
    // [] - several friendly deaths in a few minutes
    ["lossStreak", [
        [["CROSSROAD", "Medics are running out of bandages and I'm running out of patience. Fewer funerals, please."]],
        [["CROSSROAD", "Whoever is leading this charge, stop. Count heads, then think."]],
        [["CROSSROAD", "Gentlemen, the enemy is meant to die. Not you. Do try to keep up."]],
        [["CROSSROAD", "We're losing people. Slow down, pick your fights, and stop walking into their arcs."]],
        [["CROSSROAD", "I've signed more casualty slips in ten minutes than in the last hour. Regroup."]],
        [["CROSSROAD", "That's enough heroics. Pull back, reorganise, try again with a plan."]]
    ]],
    // [] - no fighting for a long time
    ["quiet", [
        [["CROSSROAD", "Long silence. Either you're very stealthy or very lost. I'd like to know which."]],
        [["CROSSROAD", "The enemy is building while you're admiring the view. Move."]],
        [["CROSSROAD", "It's very quiet. I don't care for quiet. Somebody find me a target."]],
        [["CROSSROAD", "All stations. The enemy is not going to destroy itself. More's the pity."]],
        [["CROSSROAD", "Fifteen minutes without a shot fired. Are we sightseeing?"]],
        [["CROSSROAD", "Gentlemen, the direction finders work best when you actually walk somewhere."]]
    ]],
    // [vehicle name] - a base vehicle destroyed
    ["baseVehLost", [
        [["CROSSROAD", "One %1 less in the motor pool. Do we have a policy on driving lessons?"]],
        [["CROSSROAD", "%1 lost. The mechanics have asked me to pass on some words. I won't."]],
        [["CROSSROAD", "We've lost a %1. Squad leaders, a reminder that the vehicles are on loan. From the taxpayer. Who would like them back."]],
        [["CROSSROAD", "Another %1 written off. The motor pool sends its regards."]],
        [["CROSSROAD", "%1 destroyed. Replacement on its way. Try to bring this one back."]]
    ]],
    // [squad, vehicle name]
    ["shopBuy", [
        [["CROSSROAD", "%1 has bought themselves a %2. Points well spent, one hopes."]],
        [["CROSSROAD", "%1 has requisitioned a %2. Don't scratch it."]],
        [["CROSSROAD", "A %2 for %1. Earned, I'm told. Spend it wisely."]],
        [["CROSSROAD", "%1, your %2 is on the pad. I'd like it back in one piece. Ideally."]]
    ]],

    // ================================================================ MAGPIE (her UAVs)
    // [summary]
    ["magReport@1", [
        [["MAGPIE", "Sweep report. Still early.%1"]],
        [["MAGPIE", "First picture.%1"]],
        [["MAGPIE", "Picture so far.%1"]]
    ]],
    ["magReport@2", [
        [["MAGPIE", "Updated picture. They're spreading out.%1"]],
        [["MAGPIE", "Sweep report. Busy out there.%1"]],
        [["MAGPIE", "Sweep report.%1"]]
    ]],
    ["magReport@3", [
        [["MAGPIE", "Sweep report. Fewer than last time.%1"]],
        [["MAGPIE", "Updated picture. They're scraping the barrel.%1"]],
        [["MAGPIE", "Sweep report.%1"]]
    ]],
    ["magReport@4", [
        [["MAGPIE", "Sweep report. Stragglers, mostly.%1"]],
        [["MAGPIE", "Updated picture. Not much left to find.%1"]],
        [["MAGPIE", "Leftovers.%1"]]
    ]],
    // [] - first contact / new focus: every drone encircles it
    ["magFocus", [
        [["MAGPIE", "Contact. Pulling every bird in around it."]],
        [["MAGPIE", "Got something. All drones, circle and tighten."]],
        [["MAGPIE", "New focus. I'm ringing it from every side."]]
    ]],
    // [] - a drone found an anti-air vehicle
    ["magAa", [
        [["MAGPIE", "Tigris on the ground. I'm keeping my birds out of its reach. Expect thinner coverage there."]],
        [["MAGPIE", "Anti-air spotted. I'm not feeding it drones. That area goes dark for me."]],
        [["MAGPIE", "I've found their Tigris. Lovely radar. I'll stay well clear, which means you'll see less."]]
    ]],
    // [airframe] - a Sentinel airborne
    ["magLaunch", [
        [["MAGPIE", "%1 is up. Try not to hide from it, it's on your side."]],
        [["MAGPIE", "%1 is airborne. Eyes up shortly."]],
        [["MAGPIE", "%1 off the runway. I'll tell you what I see. Try to look at it."]],
        [["MAGPIE", "%1 climbing out. Keep your heads down, I'm working."]]
    ]],
    // [airframe, minutes to the replacement] - a Sentinel shot down
    ["magDown", [
        [["MAGPIE", "Lost %1. Replacement airframe in %2 minutes."]],
        [["MAGPIE", "%1 is down. I'm starting to take it personally. Another one in %2."]],
        [["MAGPIE", "%1 shot down. Their AA is awake. Next one on the runway in %2 minutes."]],
        [["MAGPIE", "Lost %1. I'll have another one up in %2. Do something useful meanwhile."]]
    ]],
    // [] - three empty reports in a row
    ["magQuiet", [
        [["MAGPIE", "Three sweeps, nothing new. Either they've learned, or there's nothing left. I doubt the first."]],
        [["MAGPIE", "Nothing new for a while. Either they're hiding, or you've done my job for me."]],
        [["MAGPIE", "Still nothing. I'm widening the search."]],
        [["MAGPIE", "Quiet out there. I don't trust quiet."]]
    ]]
];

// keys that ignore the speech budget and the silence after a fallen HQ (alarms, act openings)
CQ_storyPriority = ["huntContact", "huntDown", "carrier", "act2", "act3", "act4", "defeat", "victory", "contact", "flare", "rootDefend", "breach", "assault", "netCut", "baseThreat", "relayUp", "relayLost", "fallen", "fallenEarly"];

CQ_uiCardX = 19;                          // px from the screen's left edge to the card (its border then lines up with the vehicle panel, ~16 px)
CQ_uiCardY = 300;                         // px from the top: first card (below the map screen's menu)
CQ_uiCardTime = createHashMapFromArray [["MAGPIE", 6]];   // s on screen per speaker (others: 6 s + length of the text)
CQ_uiCardWidth = 620;                     // notification card width in pixels (message text block ~560 px)
CQ_uiCardBorder = 3;                      // notification card border thickness in pixels (0 = none)
CQ_uiCardBorderColor = [0.569, 0.549, 0.231, 1];   // olive #918C3B (default)
// border thickness per speaker, in pixels (others: CQ_uiCardBorder)
CQ_uiCardBorderPx = createHashMapFromArray [["COMHAT", 6]];
// border colour per speaker
CQ_uiCardBorderColors = createHashMapFromArray [
    ["COMHAT", [0.85, 0.68, 0.21, 1]],       // gold
    ["CROSSROAD", [0.78, 0.78, 0.76, 1]],    // light grey
    ["MAGPIE", [0.569, 0.549, 0.231, 1]]     // olive (as before)
];
CQ_uiCardMax = 5;                         // cards on screen at once (more wait in line)
CQ_storyLineGap = 4;          // seconds between two lines of the same message
CQ_storyCooldown = 20;        // the same message about the same objective at most every 20 s
CQ_storyBudget = 180;         // at most one non-priority CROSSROAD message every 3 min
CQ_storyQuietAfterFall = 150; // radio silence (non-priority) after an HQ falls
CQ_sitrepEvery = 1200;        // a CROSSROAD SITREP every 20 min
CQ_lossStreakCount = 4;       // friendly deaths ...
CQ_lossStreakWindow = 300;    // ... within 5 min -> "lossStreak" (at most every 10 min)
CQ_quietAfter = 900;          // no fighting for 15 min -> "quiet" (at most every 15 min)
