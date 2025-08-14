-- Weapon XP + real Atk/Def + element (left-hand preferred), revscriptsys

local XP_PER_KILL        = 5
local BASE_CAP           = 100
local CAP_GROWTH         = 1.25
local MAX_LEVEL          = 10

local BASE_ELEMENT_DMG   = 11   -- elementDamage at +0
local ELEM_PER_LEVEL     = 1    -- elementDamage growth per level

local EXTRA_PHYS_PER_LVL = 1    -- fallback extra physical damage per hit
local ELEM_EXTRA_MIN     = 15   -- fallback element min damage per hit
local ELEM_EXTRA_MAX     = 35   -- fallback element max damage per hit

local WXP_MODAL_ID       = 6010

local WEAPON_SKILL_BY_TYPE = { [WEAPON_SWORD]=true, [WEAPON_AXE]=true, [WEAPON_CLUB]=true }

local ELEM = {
	fire     = { type = COMBAT_FIREDAMAGE,     effect = CONST_ME_HITBYFIRE,    label = "Fire"     },
	ice      = { type = COMBAT_ICEDAMAGE,      effect = CONST_ME_ICEATTACK,    label = "Ice"      },
	energy   = { type = COMBAT_ENERGYDAMAGE,   effect = CONST_ME_ENERGYHIT,    label = "Energy"   },
	earth    = { type = COMBAT_EARTHDAMAGE,    effect = CONST_ME_POISONATTACK, label = "Earth"    },
	holy     = { type = COMBAT_HOLYDAMAGE,     effect = CONST_ME_HOLYDAMAGE,   label = "Holy"     },
	death    = { type = COMBAT_DEATHDAMAGE,    effect = CONST_ME_MORTAREA,     label = "Death"    },
	poison   = { type = COMBAT_EARTHDAMAGE,    effect = CONST_ME_POISONATTACK, label = "Poison"   },
	physical = { type = COMBAT_PHYSICALDAMAGE, effect = CONST_ME_DRAWBLOOD,    label = "Physical" },
}

local ELEM_CHOICES = {
	{id=1,key="fire"},{id=2,key="ice"},{id=3,key="energy"},{id=4,key="earth"},
	{id=5,key="holy"},{id=6,key="death"},{id=7,key="poison"},{id=8,key="physical"},
}

-- state in item.text: WXP;l=5;x=15;c=195;e=fire;a=14;d=12;t=
local function encode(w)
	return string.format("WXP;l=%d;x=%d;c=%d;e=%s;a=%d;d=%d;t=%s",
		w.level or 0, w.xp or 0, w.cap or BASE_CAP, w.elem or "", w.baseAtk or 0, w.baseDef or 0, w.l10 or "")
end
local function decode(s)
	if not s or s=="" or not s:find("^WXP;") then return nil end
	local w={level=0,xp=0,cap=BASE_CAP,elem="",baseAtk=0,baseDef=0,l10=""}
	w.level=tonumber(s:match("l=(%d+)")or"0")or 0
	w.xp   =tonumber(s:match("x=(%d+)")or"0")or 0
	w.cap  =tonumber(s:match("c=(%d+)")or"0")or BASE_CAP
	w.elem =s:match("e=([%a]+)") or ""
	w.baseAtk=tonumber(s:match("a=(%d+)")or"0")or 0
	w.baseDef=tonumber(s:match("d=(%d+)")or"0")or 0
	w.l10  =s:match("t=([%w_,%-]+)") or ""
	return w
end
local function defaultCapForLevel(lvl)
	local cap=BASE_CAP; for i=2,lvl do cap=math.floor(cap*CAP_GROWTH+0.5) end; return cap
end
local function readWxp(item)
	local t=item:getAttribute("text")
	local w=decode(t)
	if not w then
		local it=ItemType(item:getId())
		w={level=0,xp=0,cap=BASE_CAP,elem="",baseAtk=it:getAttack(),baseDef=it:getDefense(),l10=""}
	end
	return w
end
local function writeWxp(item,w)
	item:setAttribute("text",encode(w))
	local it=ItemType(item:getId())
	local baseName=it:getName(); if baseName=="" then baseName="Weapon" end
	local lines={baseName,string.format("Upgrade: +%d",w.level or 0)}
	if w.elem~="" then lines[#lines+1]="Element: "..w.elem end
	if (w.level or 0)<MAX_LEVEL then lines[#lines+1]=string.format("Exp %d/%d",w.xp or 0,w.cap or BASE_CAP) else lines[#lines+1]="Max level" end
	item:setAttribute("description",table.concat(lines,"\n"))
end
local function getMeleeWeapon(player)
	local tool=player:getSlotItem(CONST_SLOT_LEFT) or player:getSlotItem(CONST_SLOT_RIGHT)
	if not tool then return nil,nil end
	local it=tool:getType(); if not it or not it.getWeaponType then return nil,nil end
	local wt=it:getWeaponType(); if not WEAPON_SKILL_BY_TYPE[wt] then return nil,nil end
	return tool,wt
end
local function refresh(item) item:transform(item:getId()); item:transform(item:getId()) end
local function tryApplyRealAtkDef(item,w)
	local okA=item.setAttribute and item:setAttribute("attack",(w.baseAtk or 0)+(w.level or 0))
	local okD=item.setAttribute and item:setAttribute("defense",(w.baseDef or 0)+(w.level or 0))
	if okA or okD then refresh(item); return true end
	return false
end
local function tryApplyRuntimeElement(item,elem,level)
	if not (item and elem and ELEM[elem]) then return false end
	local dmg=(BASE_ELEMENT_DMG + ELEM_PER_LEVEL*(level or 0))
	local okT=item.setAttribute and item:setAttribute("elementType", ELEM[elem].type)
	local okD=item.setAttribute and item:setAttribute("elementDamage", dmg)
	if okT or okD then refresh(item); return true end
	return false
end
local function dealDmg(player,target,typ,effect,minv,maxv)
	local c=Combat(); c:setParameter(COMBAT_PARAM_TYPE,typ); c:setParameter(COMBAT_PARAM_EFFECT,effect)
	c:setFormula(COMBAT_FORMULA_DAMAGE,0,-minv,0,-maxv); c:execute(player,numberToVariant(target:getId()))
end

-- XP per kill
local eKill=CreatureEvent("WXP_Kill")
function eKill.onKill(creature,target)
	local tgt=(type(target)=="number") and Creature(target) or (target and target.isMonster and target:isMonster() and target or nil)
	if not tgt or tgt:isPlayer() then return true end
	local player=(type(creature)=="number") and Player(creature) or (creature and creature.isPlayer and creature:isPlayer() and creature:getPlayer() or nil)
	if not player then return true end
	local tool,wt=getMeleeWeapon(player); if not tool then return true end
	local w=readWxp(tool)
	if (w.level or 0)<MAX_LEVEL then
		w.xp=(w.xp or 0)+XP_PER_KILL
		if w.xp>=(w.cap or BASE_CAP) then
			w.level=math.min(MAX_LEVEL,(w.level or 0)+1)
			w.xp=0; w.cap=defaultCapForLevel((w.level or 0)+1)
			writeWxp(tool,w)
			if not tryApplyRealAtkDef(tool,w) then
				player:sendTextMessage(MESSAGE_STATUS_CONSOLE_ORANGE,"Runtime Atk/Def not supported. Using simulated +dmg per hit.")
			end
			tryApplyRuntimeElement(tool,w.elem,(w.level or 0))
			player:sendTextMessage(MESSAGE_EVENT_ADVANCE,string.format("Bron +%d.",w.level))
		else
			writeWxp(tool,w)
			player:sendTextMessage(MESSAGE_STATUS_CONSOLE_ORANGE,string.format("Kill XP: %d/%d",w.xp,w.cap))
		end
	else
		writeWxp(tool,w)
	end
	return true
end
eKill:register()

-- Element + extra phys – on each positive hit (fallback if runtime element unsupported)
local eHit=CreatureEvent("WXP_Hit")
local WXP_GUARD = {}
function eHit.onHealthChange(creature,attacker,pdmg,ptype,sdmg,stype,origin)
	local tgt=Creature(creature); if not tgt or tgt:isPlayer() then return pdmg,ptype,sdmg,stype end
	local player=(type(attacker)=="number") and Player(attacker) or (attacker and attacker.isPlayer and attacker:isPlayer() and attacker:getPlayer() or nil)
	if not player then return pdmg,ptype,sdmg,stype end
	local tool,wt=getMeleeWeapon(player); if not tool then return pdmg,ptype,sdmg,stype end
	local w=readWxp(tool)
	-- anti-duplicate within one swing
	local key=(player:getId())..":"..(tgt:getId())
	if WXP_GUARD[key] then return pdmg,ptype,sdmg,stype end
	WXP_GUARD[key]=true
	addEvent(function() WXP_GUARD[key]=nil end, 150)
	-- elemental extra hit (fallback style) + visual
	if (w.level or 0)>=5 and w.elem~="" and ELEM[w.elem] then
		dealDmg(player,tgt,ELEM[w.elem].type,ELEM[w.elem].effect,ELEM_EXTRA_MIN,ELEM_EXTRA_MAX)
		local pos=tgt:getPosition(); if pos then pos:sendMagicEffect(ELEM[w.elem].effect) end
	end
	-- simulated +Atk extra
	local extra=(w.level or 0)*EXTRA_PHYS_PER_LVL
	if extra>0 then dealDmg(player,tgt,COMBAT_PHYSICALDAMAGE,CONST_ME_HITAREA,extra,extra) end
	return pdmg,ptype,sdmg,stype
end
eHit:register()

-- Modal + !skill – choose element
local eModal=CreatureEvent("WXP_Modal")
function eModal.onModalWindow(player,modalWindowId,buttonId,choiceId)
	if modalWindowId~=WXP_MODAL_ID or buttonId~=1 then return true end
	local tool,wt=getMeleeWeapon(player); if not tool then return true end
	local w=readWxp(tool); if (w.level or 0)<5 then player:sendCancelMessage("Element od +5."); return true end
	local chosen; for _,c in ipairs(ELEM_CHOICES) do if c.id==choiceId then chosen=c.key break end end
	if not chosen or not ELEM[chosen] then player:sendCancelMessage("Nieprawidlowy wybor."); return true end
	w.elem=chosen; writeWxp(tool,w)
	if not tryApplyRuntimeElement(tool,w.elem,(w.level or 0)) then
		-- fallback handled in onHealthChange
	end
	refresh(tool)
	player:sendTextMessage(MESSAGE_INFO_DESCR,"Ustawiono element: "..chosen)
	player:getPosition():sendMagicEffect(CONST_ME_MAGIC_BLUE)
	return true
end
eModal:register()

local tSkill=TalkAction("!skill")
function tSkill.onSay(player,words,param)
	-- ensure events registered even without relog
	player:registerEvent("WXP_Kill")
	player:registerEvent("WXP_Hit")
	player:registerEvent("WXP_Modal")
	local tool,wt=getMeleeWeapon(player)
	if not tool then player:sendCancelMessage("Nie masz broni melee w rece (preferowana lewa)."); return false end
	local w=readWxp(tool)
	if (w.level or 0)<5 then player:sendCancelMessage("Wybor elementu od +5."); return false end
	local mw=ModalWindow(WXP_MODAL_ID,"Wybierz element ataku","Wybierz dodatkowy atak dla broni w rece:")
	for _,c in ipairs(ELEM_CHOICES) do mw:addChoice(c.id,ELEM[c.key].label) end
	mw:addButton(1,"Wybierz"); mw:addButton(0,"Anuluj")
	mw:setDefaultEnterButton(1); mw:setDefaultEscapeButton(0)
	mw:setPriority(true); mw:sendToPlayer(player)
	return false
end
tSkill:register()

-- Ensure events on login
local eLogin=CreatureEvent("WXP_Login")
function eLogin.onLogin(player)
	player:registerEvent("WXP_Kill")
	player:registerEvent("WXP_Hit")
	player:registerEvent("WXP_Modal")
	-- tylko rejestracja i odświeżenie opisu, bez transformów/ustawiania atrybutów
	local tool,wt=getMeleeWeapon(player)
	if tool then
		local w=readWxp(tool); if not w.cap or w.cap<=0 then w.cap=BASE_CAP end
		writeWxp(tool,w)
	end
	return true
end
eLogin:register()