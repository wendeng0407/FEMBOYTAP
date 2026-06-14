--[[
    file: femboytap_changer.lua
    汉化内容: 物品名称（武器、刀、手套）、日志提示、交互反馈
    注：SKINS表中的皮肤名称因数量巨大且多为专有名词，保留原英文，但主要界面（武器列表等）已完全汉化。
]]
local ffi  = ffi
local band, rshift, bxor, lshift = bit.band, bit.rshift, bit.bxor, bit.lshift
local floor = math.floor

local off = {}

local DUMPER = "https://raw.githubusercontent.com/a2x/cs2-dumper/main/output/"

local FIELDS = {
    m_pWeaponServices      = "m_pWeaponServices",
    m_hMyWeapons           = "m_hMyWeapons",
    m_hActiveWeapon        = "m_hActiveWeapon",
    m_AttributeManager     = { "m_AttributeManager", "C_EconEntity" },
    m_Item                 = "m_Item",
    m_pGameSceneNode       = "m_pGameSceneNode",
    m_modelState           = { "m_modelState", "CSkeletonInstance" },
    m_hModel               = { "m_hModel", "CModelState" },
    m_nSubclassID          = "m_nSubclassID",
    m_iTeamNum             = "m_iTeamNum",
    m_iHealth              = "m_iHealth",
    m_lifeState            = "m_lifeState",
    m_hOwnerEntity         = "m_hOwnerEntity",
    m_hPlayerPawn          = "m_hPlayerPawn",
    m_steamID              = "m_steamID",
    m_iItemDefinitionIndex = "m_iItemDefinitionIndex",
    m_bRestoreCustomMat    = "m_bRestoreCustomMaterialAfterPrecache",
    m_iEntityQuality       = "m_iEntityQuality",
    m_iItemIDLow           = "m_iItemIDLow",
    m_iItemIDHigh          = "m_iItemIDHigh",
    m_iAccountID           = "m_iAccountID",
    m_OriginalOwnerXuidLow = { "m_OriginalOwnerXuidLow", "C_EconEntity" },
    m_bInitialized         = "m_bInitialized",
    m_bDisallowSOC         = "m_bDisallowSOC",
    m_AttributeList        = "m_AttributeList",
    m_Attributes           = "m_Attributes",
    m_nFallbackPaintKit    = { "m_nFallbackPaintKit", "C_EconEntity" },
    m_nFallbackSeed        = { "m_nFallbackSeed", "C_EconEntity" },
    m_flFallbackWear       = { "m_flFallbackWear", "C_EconEntity" },
    m_nFallbackStatTrak    = { "m_nFallbackStatTrak", "C_EconEntity" },
    m_EconGloves           = { "m_EconGloves", "C_CSPlayerPawn" },
    m_bNeedToReApplyGloves = { "m_bNeedToReApplyGloves", "C_CSPlayerPawn" },

}
local function pull_offset(j, name, after)
    local init = 1

    if after then local p = j:find('"' .. after .. '"%s*:%s*{'); if p then init = p end end
    local v = j:match('"' .. name .. '"%s*:%s*(%d+)', init)
    return v and tonumber(v) or nil
end
pcall(function()
    local j = http.Get(DUMPER .. "client_dll.json")
    if type(j) ~= "string" then return end
    for key, spec in pairs(FIELDS) do
        local name, after = spec, nil
        if type(spec) == "table" then name, after = spec[1], spec[2] end
        local v = pull_offset(j, name, after)
        if v then off[key] = v end
    end
end)
off.m_szWorldModel = 48
off.m_modelState = off.m_modelState or 336
off.m_hModel     = off.m_hModel     or 160

local function r_u8 (a) return ffi.cast("uint8_t*",  a)[0] end
local function r_u16(a) return ffi.cast("uint16_t*", a)[0] end
local function r_i32(a) return ffi.cast("int32_t*",  a)[0] end
local function r_u32(a) return ffi.cast("uint32_t*", a)[0] end
local function r_u64(a) return ffi.cast("uint64_t*", a)[0] end
local function r_ptr(a) return tonumber(ffi.cast("uint64_t*", a)[0]) end
local function w_u8 (a,v) ffi.cast("uint8_t*",  a)[0]=v end
local function w_u16(a,v) ffi.cast("uint16_t*", a)[0]=v end
local function w_i32(a,v) ffi.cast("int32_t*",  a)[0]=v end
local function w_u32(a,v) ffi.cast("uint32_t*", a)[0]=v end
local function w_u64(a,v) ffi.cast("uint64_t*", a)[0]=v end
local function w_f32(a,v) ffi.cast("float*",    a)[0]=v end
local function valid(p) return p ~= nil and p > 0x10000 and p < 0x7FFFFFFFFFFF end
local function read_cstr(a, max)
    if not valid(a) then return "" end
    local t = {}
    for i = 0, (max or 160) - 1 do
        local c = r_u8(a + i); if c == 0 then break end
        t[#t+1] = string.char(c)
    end
    return table.concat(t)
end

local function sig_rva(modBase, mod, pattern, instrLen)
    if not modBase then return nil end
    local a = mem.FindPattern(mod, pattern); if not a or a == 0 then return nil end
    a = tonumber(a)
    return (a + instrLen + r_i32(a + 3)) - modBase
end
local function sig_disp(mod, pattern)
    local a = mem.FindPattern(mod, pattern); if not a or a == 0 then return nil end
    return r_i32(tonumber(a) + 3)
end
do
    local cb = mem.GetModuleBase("client.dll")
    local eb = mem.GetModuleBase("engine2.dll")
    off.dwEntityList            = sig_rva(cb, "client.dll",  "48 89 0D ?? ?? ?? ?? E9 ?? ?? ?? ?? CC", 7)
    off.dwLocalPlayerController = sig_rva(cb, "client.dll",  "48 8B 05 ?? ?? ?? ?? 41 89 BE", 7)
    off.dwNetworkGameClient     = sig_rva(eb, "engine2.dll", "48 89 3D ?? ?? ?? ?? FF 87", 7)
    off.dwNetworkGameClient_signOnState = sig_disp("engine2.dll", "44 8B 81 ?? ?? ?? ?? 48 8D 0D")
    if not off.dwLocalPlayerController or not off.dwEntityList or not off.m_hMyWeapons then
        print("[更换器] 警告：特征码/网络变量未解析 —— 更换器不可用")
    else
        print(string.format("[更换器] 特征码正常：实体列表=%X 控制器=%X NGC=%s",
            off.dwEntityList, off.dwLocalPlayerController,
            off.dwNetworkGameClient and string.format("%X", off.dwNetworkGameClient) or "nil"))
    end
end

local function tou32(x) x = x % 0x100000000; if x < 0 then x = x + 0x100000000 end; return x end
local function mul32(a, b)
    a = a % 0x100000000; b = b % 0x100000000
    local ah, al = floor(a/0x10000), a%0x10000
    local bh = floor(b/0x10000)
    return (al*(b%0x10000) + ((al*bh + ah*(b%0x10000)) % 0x10000)*0x10000) % 0x100000000
end
local MM = 0x5bd1e995
local function murmur2(str, seed)
    local len = #str
    local h = tou32(bxor(seed, len))
    local i, rem = 1, len
    while rem >= 4 do
        local b0,b1,b2,b3 = str:byte(i, i+3)
        local k = b0 + b1*256 + b2*65536 + b3*16777216
        k = mul32(k, MM); k = tou32(bxor(k, rshift(k, 24))); k = mul32(k, MM)
        h = mul32(h, MM); h = tou32(bxor(h, k))
        i = i + 4; rem = rem - 4
    end
    if rem >= 3 then h = tou32(bxor(h, lshift(str:byte(i+2), 16))) end
    if rem >= 2 then h = tou32(bxor(h, lshift(str:byte(i+1), 8))) end
    if rem >= 1 then h = tou32(bxor(h, str:byte(i))); h = mul32(h, MM) end
    h = tou32(bxor(h, rshift(h, 13))); h = mul32(h, MM); h = tou32(bxor(h, rshift(h, 15)))
    return h
end
local function subclass_hash(def) return murmur2(tostring(def):lower(), 0x31415926) end

local DLL = "client.dll"
-- client.dll 
local sig = {
    set_model      = "40 53 48 83 EC ?? 48 8B D9 4C 8B C2 48 8B 0D ?? ?? ?? ?? 48 8D 54 24 40",  -- CBaseModelEntity::SetModel
    update_subclass= "4C 8B DC 53 48 81 EC ?? ?? ?? ?? 48 8B 41",                                 -- CEconItemView subclass refresh
    set_mesh_mask  = "48 89 5C 24 ?? 48 89 74 24 ?? 57 48 83 EC ?? 48 8D 99 ?? ?? ?? ?? 48 8B 71", -- CSkeletonInstance mesh mask
    regen_skins    = "48 83 EC ?? E8 ?? ?? ?? ?? 48 85 C0 0F 84 ?? ?? ?? ?? 48 8B 10",            -- regenerate custom skins
}
-- a + 5 + rel32 -> CBodyComponent::SetBodyGroup
local SBG_SIG = "E8 ?? ?? ?? ?? EB 0C 48 8B CF"
local fn, fnptr = {}, {}
local function resolve()
    for name, pattern in pairs(sig) do
        if not fn[name] then local a = mem.FindPattern(DLL, pattern); if a and a ~= 0 then fn[name] = a end end
    end
    if not fn.set_body_group then
        local a = mem.FindPattern(DLL, SBG_SIG)
        if a and a ~= 0 then fn.set_body_group = a + 5 + r_i32(a + 1) end
    end
    if fn.set_model       and not fnptr.set_model       then fnptr.set_model       = ffi.cast("void(*)(void*, const char*)", fn.set_model) end
    if fn.update_subclass and not fnptr.update_subclass then fnptr.update_subclass = ffi.cast("void(*)(void*)",              fn.update_subclass) end
    if fn.set_mesh_mask   and not fnptr.set_mesh_mask   then fnptr.set_mesh_mask   = ffi.cast("void(*)(void*, uint64_t)",    fn.set_mesh_mask) end
    if fn.regen_skins     and not fnptr.regen_skins     then fnptr.regen_skins     = ffi.cast("void(*)(void)",               fn.regen_skins) end
    if fn.set_body_group  and not fnptr.set_body_group  then fnptr.set_body_group  = ffi.cast("void(*)(void*, const char*, unsigned int)", fn.set_body_group) end
end
local function vfunc(this, index)
    if not valid(this) then return nil end
    local vt = r_ptr(this); if not valid(vt) then return nil end
    local f = r_ptr(vt + index*8); if not valid(f) then return nil end
    return f
end
local function vcall_void(this, index)
    local f = vfunc(this, index); if not f then return end
    ffi.cast("void(*)(void*)", f)(ffi.cast("void*", this))
end
local function vcall_void_bool(this, index, b)
    local f = vfunc(this, index); if not f then return end
    ffi.cast("void(*)(void*, int)", f)(ffi.cast("void*", this), b and 1 or 0)
end

local KNIVES = {
    { name = "默认 (不更换)", def = nil },
    { name = "刺刀",        def = 500 }, { name = "经典匕首",  def = 503 },
    { name = "折叠刀",     def = 505 }, { name = "穿肠刀",      def = 506 },
    { name = "爪子刀",       def = 507 }, { name = "M9 刺刀",     def = 508 },
    { name = "猎杀者匕首",       def = 509 }, { name = " Falchion 刀",       def = 512 },
    { name = "鲍伊猎刀",    def = 514 }, { name = "蝴蝶刀",      def = 515 },
    { name = "暗影双匕", def = 516 }, { name = "求生匕首", def = 517 },
    { name = "生存刀", def = 518 }, { name = "熊刀",    def = 519 },
    { name = " Navaja 刀",   def = 520 }, { name = "游牧长剑",    def = 521 },
    { name = "短剑",       def = 522 }, { name = "海豹短刀",    def = 523 },
    { name = "骷髅匕首", def = 525 }, { name = "库克利弯刀",    def = 526 },
}
local WEAPONS = {
    { name = "AK-47",        def = 7  }, { name = "M4A4",         def = 16 },
    { name = "M4A1 消音型",       def = 60 }, { name = "AWP",          def = 9  },
    { name = "SSG 08",       def = 40 }, { name = "SCAR-20",      def = 38 },
    { name = "G3SG1",        def = 11 }, { name = "SG 553",       def = 39 },
    { name = "AUG",          def = 8  }, { name = "FAMAS",        def = 10 },
    { name = "加利尔 AR",     def = 13 }, { name = "沙漠之鹰", def = 1  },
    { name = "R8 左轮手枪",  def = 64 }, { name = "双持贝瑞塔",def = 2  },
    { name = "FN57",   def = 3  }, { name = "格洛克 18",     def = 4  },
    { name = "Tec-9",        def = 30 }, { name = "P2000",        def = 32 },
    { name = "P250",         def = 36 }, { name = "USP 消音版",        def = 61 },
    { name = "CZ75 自动手枪",    def = 63 }, { name = "MAC-10",       def = 17 },
    { name = "P90",          def = 19 }, { name = "PP-Bizon",     def = 26 },
    { name = "MP5-SD",       def = 23 }, { name = "MP7",          def = 33 },
    { name = "MP9",          def = 34 }, { name = "UMP-45",       def = 24 },
    { name = "M249",         def = 14 }, { name = "Negev",        def = 28 },
    { name = "XM1014",       def = 25 }, { name = "MAG-7",        def = 27 },
    { name = "新星",         def = 35 }, { name = "截短霰弹枪",    def = 29 },
}
local GLOVES = {
    { name = "默认 (关闭)",      def = 0    },
    { name = "血猎手套",  def = 5027 }, { name = "运动手套",      def = 5030 },
    { name = "驾驶手套",      def = 5031 }, { name = "裹手",        def = 5032 },
    { name = "摩托手套",        def = 5033 }, { name = "专业手套", def = 5034 },
    { name = "九头蛇手套",       def = 5035 }, { name = "狂牙手套",def = 4725 },
}
local function is_knife(def) return def == 42 or def == 59 or (def >= 500 and def <= 526) end

-- SKINS 表保留原始英文皮肤名（数量巨大，非核心功能）
local SKINS = {
  [1]={{"Blaze",37},{"Blue Ply",945},{"Bronze Deco",425},{"Calligraffiti",114},{"Cobalt Disruption",231},{"Code Red",711},{"Conspiracy",351},{"Corinthian",509},{"Crimson Web",232},{"Directive",603},{"Emerald JГ¶rmungandr",757},{"Fennec Fox",764},{"Firebreathing",1430},{"Golden Koi",185},{"Hand Cannon",328},{"Heat Treated",1054},{"Heirloom",273},{"Hypnotic",61},{"Kumicho Dragon",527},{"Light Rail",841},{"Mecha Industries",805},{"Meteorite",296},{"Midnight Storm",468},{"Mint Fan",1257},{"Mudder",90},{"Mulberry",1318},{"Naga",397},{"Night",40},{"Night Heist",1006},{"Ocean Drive",1090},{"Oxide Blaze",645},{"Pilot",347},{"Printstream",962},{"Serpent Strike",1189},{"Sputnik",1056},{"Starcade",938},{"Sunset Storm еЈ±",469},{"Sunset Storm ејђ",470},{"The Bronze",992},{"The Daily Deagle",1360},{"Tilted",138},{"Trigger Discipline",1050},{"Urban DDPAT",17},{"Urban Rubble",237}},
  [2]={{"Angel Eyes",1347},{"Anodized Navy",28},{"Balance",895},{"Black Limba",190},{"BorDeux",1335},{"Briar",330},{"Cartel",528},{"Cobalt Quartz",249},{"Cobra Strike",658},{"Colony",47},{"Contractor",46},{"Demolition",153},{"Dezastre",978},{"Drift Wood",824},{"Dualing Dragons",491},{"Duelist",447},{"Elite 1.6",903},{"Emerald",453},{"Flora Carnivora",1156},{"Heist",1005},{"Hemoglobin",220},{"Hideout",1169},{"Hydro Strike",112},{"Marina",261},{"Melondrama",1126},{"Moon in Libra",450},{"Oil Change",1086},{"Panther",276},{"Polished Malachite",1290},{"Pyre",860},{"Retribution",307},{"Rose Nacre",1263},{"Royal Consorts",625},{"Shred",710},{"Silver Pour",1373},{"Stained",43},{"Sweet Little Angels",139},{"Switch Board",998},{"Tread",1091},{"Twin Turbo",747},{"Urban Shock",396},{"Ventilators",544}},
  [3]={{"Angry Mob",837},{"Anodized Gunmetal",210},{"Autumn Thicket",1336},{"Berries And Cherries",1002},{"Boost Protocol",1093},{"Buddy",906},{"Candy Apple",3},{"Capillary",646},{"Case Hardened",44},{"Contractor",46},{"Coolant",784},{"Copper Galaxy",274},{"Crimson Blossom",729},{"Dark Polymer",1429},{"Fairy Tale",979},{"Fall Hazard",1082},{"Flame Test",693},{"Forest Night",78},{"Fowl Play",352},{"Fraise Crane",1380},{"Heat Treated",831},{"Hot Shot",377},{"Hybrid",1168},{"Hyper Beast",660},{"Jungle",151},{"Kami",265},{"Midnight Paintover",1062},{"Monkey Business",427},{"Neon Kimono",464},{"Nightshade",223},{"Nitro",254},{"Orange Peel",141},{"Retrobution",510},{"Scrawl",1128},{"Scumbria",605},{"Silver Quartz",252},{"Sky Blue",1262},{"Triumvirate",530},{"Urban Hazard",387},{"Violent Daimyo",585},{"Withered Vine",932}},
  [4]={{"AXIA",832},{"Block-18",1167},{"Blue Fissure",278},{"Brass",159},{"Bullet Queen",957},{"Bunsen Burner",479},{"Candy Apple",3},{"Catacombs",399},{"Clear Polymer",1039},{"Coral Bloom",1312},{"Death Rattle",293},{"Dragon Tattoo",48},{"Fade",38},{"Franklin",1016},{"Fully Tuned",1421},{"Gamma Doppler",1119},{"Gamma Doppler",1120},{"Gamma Doppler",1121},{"Gamma Doppler",1122},{"Gamma Doppler",1123},{"Glockingbird",1282},{"Gold Toof",129},{"Green Line",1200},{"Grinder",381},{"Groundwater",2},{"High Beam",799},{"Ironwork",623},{"Mirror Mosaic",1348},{"Moonrise",694},{"Neo-Noir",988},{"Night",40},{"Nuclear Garden",789},{"Ocean Topo",1265},{"Off World",680},{"Oxide Blaze",808},{"Pink DDPAT",84},{"Ramese's Reach",1240},{"Reactor",367},{"Red Tire",1079},{"Royal Legion",532},{"Sacrifice",918},{"Sand Dune",208},{"Shinobu",1208},{"Snack Attack",1100},{"Steel Disruption",230},{"Synth Leaf",732},{"Teal Graf",152},{"Trace Lock",1357},{"Twilight Galaxy",437},{"Umbral Rabbit",1227},{"Vogue",963},{"Warhawk",713},{"Wasteland Rebel",586},{"Water Elemental",353},{"Weasel",607},{"Winterized",1158},{"Wraiths",495}},
  [7]={{"Aphrodite",1397},{"Aquamarine Revenge",474},{"Asiimov",801},{"B the Monster",142},{"Baroque Purple",745},{"Black Laminate",172},{"Bloodsport",639},{"Blue Laminate",226},{"Breakthrough",1358},{"Cartel",394},{"Case Hardened",44},{"Crane Flight",1425},{"Crossfade",912},{"Elite Build",422},{"Emerald Pinstripe",300},{"Fire Serpent",180},{"First Class",341},{"Frontside Misty",490},{"Fuel Injector",524},{"Gold Arabesque",921},{"Green Laminate",1070},{"Head Shot",1221},{"Hydroponic",456},{"Ice Coaled",1143},{"Inheritance",1171},{"Jaguar",316},{"Jet Set",340},{"Jungle Spray",122},{"Leet Museo",1087},{"Legion of Anubis",959},{"Midnight Laminate",1218},{"Neon Revolution",600},{"Neon Rider",707},{"Nightwish",1141},{"Nouveau Rouge",1309},{"Olive Polycam",1179},{"Orbit Mk01",656},{"Panthera onca",1018},{"Phantom Disruptor",941},{"Point Disarray",506},{"Predator",170},{"Rat Rod",885},{"Red Laminate",14},{"Redline",282},{"Safari Mesh",72},{"Safety Net",795},{"Searing Rage",1207},{"Slate",1035},{"Steel Delta",1238},{"The Empress",675},{"The Oligarch",1352},{"The Outsiders",113},{"Uncharted",836},{"VariCamo Grey",1288},{"Vulcan",302},{"Wasteland Rebel",380},{"Wild Lotus",724},{"Wintergreen",1283},{"X-Ray",1004}},
  [8]={{"Akihabara Accept",455},{"Amber Fade",246},{"Amber Slipstream",708},{"Anodized Navy",197},{"Arctic Wolf",886},{"Aristocrat",583},{"Bengal Tiger",9},{"Carved Jade",1033},{"Chameleon",280},{"Colony",47},{"Commando Company",1308},{"Condemned",110},{"Contractor",46},{"Copperhead",10},{"Creep",1362},{"Daedalus",444},{"Death by Puppy",913},{"Eye of Zapems",134},{"Flame JГ¶rmungandr",758},{"Fleet Flock",541},{"Hot Rod",33},{"Lil' Pig",173},{"Luxe Trim",121},{"Midnight Lily",727},{"Momentum",845},{"Navy Murano",740},{"Plague",1088},{"Radiation Hazard",375},{"Random Access",779},{"Ricochet",507},{"Sand Storm",823},{"Snake Pit",1249},{"Spalted Wood",927},{"Steel Sentinel",1198},{"Storm",100},{"Stymphalian",690},{"Surveillance