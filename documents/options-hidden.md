# Скрытые настройки F4

UI обрезан. Cvar'ы и колбэки в `cl_options.lua` живые — значения с консоли и из конфига игрока по-прежнему работают. Возвращать по одному в `gamemodes/zombiesurvival/gamemode/vgui/poptions.lua`.

Хук `GM:AddExtraOptions` в `cl_init.lua` пустой. Раньше вызывался в конце вкладки Игра.

## Сейчас на экране

Вкладка **Игра**: шаг поворота пропа (`zs_proprotationsnap`, combo 0 / 15 / 30 / 45). Заголовок Магазин: база пачки патронов (`zs_ammopackpoints`, слайдер 5–45 шаг 5, по умолчанию 15), сохранять выбор из шопа (`zs_ammopackremember`, по умолчанию вкл.), рамка (`zs_ammopackremembermode`: window / game / always).

Строка: `LANGUAGE.options_prop_snap`. RU: «Шаг поворота пропа», не «пропана».

Вкладка **Интерфейс** (`options_tab_hud`): счётчик XP (`zs_drawxp`, `options_draw_xp`). HUD-панель `ZSExperienceHUD` под поинтами.

## Как вернуть

1. Создать скролл вкладки: `RelapseUI.MakeOptionsScroll(propertysheet)`.
2. Добавить контролы из таблицы ниже.
3. `propertysheet:AddSheet(RelapseUI.T("options_tab_*"), tab)`.
4. Хелпер чекбоксов:

```lua
local function Checks(parent, rows)
	for _, row in ipairs(rows) do
		RelapseUI.OptionsCheck(parent, RelapseUI.T(row[1]), row[2])
	end
end
```

Combo / slider / color: `RelapseUI.OptionsCombo`, `OptionsSlider`, `OptionsColor`.

---

## Игра (`options_tab_game`)

| Ключ | EN | RU | Cvar | Тип |
|---|---|---|---|---|
| `options_always_nails` | Always display nail health | Всегда показывать здоровье гвоздей | `zs_alwaysshownails` | check |
| `options_thirdperson_knockdown` | Always third person knockdown camera | Камера нокдауна всегда от третьего лица | `zs_thirdpersonknockdown` | check |
| `options_always_quickbuy` | Always quick buy from arsenal and remantler | Всегда быстрая покупка в арсенале и ремонтнике | `zs_alwaysquickbuy` | check |
| `options_suicide_on_change` | Automatic suicide when changing classes | Самоубийство при смене класса | `zs_suicideonchange` | check |
| `options_no_redeem` | Disable automatic redeeming (next round) | Отключить авто-возрождение (со следующего раунда) | `zs_noredeem` | check |
| `options_no_use_deposit` | Disable pressing use to deposit ammo in deployables | Не класть патроны в постройки по Use | `zs_nousetodeposit` | check |
| `options_no_pickup_props` | Disable use to prop pickup (only pickup items) | Use не поднимает пропаны, только предметы | `zs_nopickupprops` | check |
| `options_no_boss_pick` | Prevent being picked as a boss zombie | Не выбирать меня боссом-зомби | `zs_nobosspick` | check |
| `options_prop_sens` | Prop rotation sensitivity | Чувствительность поворота пропа | `zs_proprotationsens` | slider 0.1–4, decimals 1 |

Чекбоксы Игра:

```lua
Checks(gameTab, {
	{ "options_always_nails", "zs_alwaysshownails" },
	{ "options_thirdperson_knockdown", "zs_thirdpersonknockdown" },
	{ "options_always_quickbuy", "zs_alwaysquickbuy" },
	{ "options_suicide_on_change", "zs_suicideonchange" },
	{ "options_no_redeem", "zs_noredeem" },
	{ "options_no_use_deposit", "zs_nousetodeposit" },
	{ "options_no_pickup_props", "zs_nopickupprops" },
	{ "options_no_boss_pick", "zs_nobosspick" }
})
```

Слайдер чувствительности пропа (после combo шага):

```lua
RelapseUI.OptionsSlider(gameTab, RelapseUI.T("options_prop_sens"), "zs_proprotationsens", 0.1, 4, 1)
```

Extra-хук в конце Игра:

```lua
local extras = {
	AddItem = function(_, pnl)
		if not IsValid(pnl) then return end
		pnl:SetParent(gameTab)
		pnl:Dock(TOP)
		pnl:DockMargin(0, 0, 0, RelapseUI.Grid15())
	end
}
gamemode.Call("AddExtraOptions", extras, frame)
```

---

## HUD (`options_tab_hud`) — на экране как **Интерфейс**

`options_draw_xp` уже в UI.

| Ключ | EN | RU | Cvar | Тип |
|---|---|---|---|---|
| `options_no_floaters` | Don't show point floaters | Не показывать всплывающие очки | `zs_nofloatingscore` | check |
| `options_hide_packs` | Don't hide arsenal and resupply packs | Не скрывать арсенал и ящики патронов | `zs_hidepacks` | check |
| `options_show_friends` | Don't hide friends via transparency | Не скрывать друзей прозрачностью | `zs_showfriends` | check |
| `options_film_mode` | Film mode (disable most of the HUD) | Режим съёмки (почти без HUD) | `zs_filmmode` | check |
| `options_font_effects` | Enable font effects | Эффекты шрифта | `zs_fonteffects` | check |
| `options_auras` | Enable human health auras | Ауры здоровья людей | `zs_auras` | check |
| `options_damage_floaters` | Enable damage indicators | Индикаторы урона | `zs_damagefloaters` | check |
| `options_damage_walls` | Show damage indicators through walls | Индикаторы урона сквозь стены | `zs_damagefloaterswalls` | check |
| `options_beacon_vis` | Enable message beacon visibility | Видимость маяков сообщений | `zs_messagebeaconshow` | check |
| `options_weapon_hud` | Weapon HUD display style | Отображение оружия в HUD | `zs_weaponhudmode` | combo |
| `options_health_style` | Health target display style | Отображение здоровья цели | `zs_healthtargetdisplay` | combo |
| `options_ui_scale` | Interface / HUD scale | Масштаб интерфейса / HUD | `zs_interfacesize` | slider 0.7–1.6, decimals 1 |
| `options_trans_radius` | Transparency radius | Радиус прозрачности | `zs_transparencyradius` | slider 0–`TransparencyRadiusMax`, decimals 0 |
| `options_trans_radius_3p` | Transparency radius in third person | Радиус прозрачности от третьего лица | `zs_transparencyradius3p` | slider 0–`TransparencyRadiusMax`, decimals 0 |
| `options_aura_full` | Health aura color — full health | Цвет ауры — полное здоровье | `zs_auracolor_full_r/g/b` | color |
| `options_aura_empty` | Health aura color — no health | Цвет ауры — нет здоровья | `zs_auracolor_empty_r/g/b` | color |

Combo HUD:

```lua
RelapseUI.OptionsCombo(hudTab, RelapseUI.T("options_weapon_hud"), {
	{ RelapseUI.T("options_whud_3d"), 0 },
	{ RelapseUI.T("options_whud_2d"), 1 },
	{ RelapseUI.T("options_whud_both"), 2 }
}, GAMEMODE.WeaponHUDMode or 0, function(data)
	RunConsoleCommand("zs_weaponhudmode", data)
end)
RelapseUI.OptionsCombo(hudTab, RelapseUI.T("options_health_style"), {
	{ RelapseUI.T("options_hp_pct"), 0 },
	{ RelapseUI.T("options_hp_amt"), 1 }
}, GAMEMODE.HealthTargetDisplay or 0, function(data)
	RunConsoleCommand("zs_healthtargetdisplay", data)
end)
```

---

## Вид (`options_tab_view`)

| Ключ | EN | RU | Cvar | Тип |
|---|---|---|---|---|
| `options_no_ironsights` | Disable iron sights view model translation | Отключить сдвиг viewmodel в прицеле | `zs_noironsights` | check |
| `options_no_crosshair_rotate` | Disable crosshair rotate | Не вращать прицел | `zs_nocrosshairrotate` | check |
| `options_no_scopes` | Disable ironsight scopes | Отключить оптические прицелы | `zs_disablescopes` | check |
| `options_ironsight_crosshair` | Draw crosshair in ironsights | Прицел в режиме прицеливания | `zs_ironsightscrosshair` | check |
| `options_hide_viewmodels` | Hide view models | Скрыть viewmodel | `zs_hideviewmodels` | check |
| `options_crosshair_lines` | Crosshair lines | Линии прицела | `zs_crosshairlines` | slider 2–8, decimals 0 |
| `options_crosshair_offset` | Crosshair offset | Смещение прицела | `zs_crosshairoffset` | slider 0–90, decimals 0 |
| `options_crosshair_thick` | Crosshair thickness | Толщина прицела | `zs_crosshairthickness` | slider 0.5–2, decimals 1 |
| `options_ironsight_zoom` | Ironsight zoom scale | Зум прицела | `zs_ironsightzoom` | slider 0–1, decimals 2 |
| `options_crosshair_pri` | Crosshair primary color | Основной цвет прицела | `zs_crosshair_colr/g/b/a` | color + alpha |
| `options_crosshair_sec` | Crosshair secondary color | Второй цвет прицела | `zs_crosshair_colr2/g2/b2/a2` | color + alpha |

---

## Звук (`options_tab_audio`)

| Ключ | EN | RU | Cvar | Тип |
|---|---|---|---|---|
| `options_beats` | Enable ambient music | Фоновая музыка | `zs_beats` | check |
| `options_last_human_music` | Enable last human music | Музыка последнего человека | `zs_playmusic` | check |
| `options_music_vol` | Music volume | Громкость музыки | `zs_beatsvolume` | slider 0–100, decimals 0 |
| `options_beat_human` | Human ambient beat set | Набор битов людей | `zs_beatset_human` | combo из `BeatChoices()` |
| `options_beat_zombie` | Zombie ambient beat set | Набор битов зомби | `zs_beatset_zombie` | combo из `BeatChoices()` |

Выбор набора битов:

```lua
local function BeatChoices()
	local out = {}
	if GAMEMODE.Beats then
		for setname in pairs(GAMEMODE.Beats) do
			if setname ~= GAMEMODE.BeatSetHumanDefualt and setname ~= GAMEMODE.BeatSetZombieDefualt then
				out[#out + 1] = { setname, setname }
			end
		end
	end
	out[#out + 1] = { RelapseUI.T("options_beat_none"), "none" }
	out[#out + 1] = { RelapseUI.T("options_beat_default"), "default" }
	return out
end

local beats = BeatChoices()
local humanBeat = GAMEMODE.BeatSetHuman == GAMEMODE.BeatSetHumanDefault and "default" or GAMEMODE.BeatSetHuman
local zombieBeat = GAMEMODE.BeatSetZombie == GAMEMODE.BeatSetZombieDefault and "default" or GAMEMODE.BeatSetZombie
RelapseUI.OptionsCombo(audioTab, RelapseUI.T("options_beat_human"), beats, humanBeat, function(data)
	RunConsoleCommand("zs_beatset_human", data)
end)
RelapseUI.OptionsCombo(audioTab, RelapseUI.T("options_beat_zombie"), beats, zombieBeat, function(data)
	RunConsoleCommand("zs_beatset_zombie", data)
end)
```

Опечатка `BeatSetHumanDefualt` в фильтре — как было в оригинале.

---

## Эффекты (`options_tab_fx`)

| Ключ | EN | RU | Cvar | Тип |
|---|---|---|---|---|
| `options_postprocessing` | Enable post processing | Постобработка | `zs_postprocessing` | check |
| `options_filmgrain` | Enable film grain | Зерно плёнки | `zs_filmgrain` | check |
| `options_colormod` | Enable color mod | Цветокоррекция | `zs_colormod` | check |
| `options_pain_flashes` | Enable pain flashes | Вспышки боли | `zs_drawpainflash` | check |
| `options_view_roll` | Enable movement view roll | Крен камеры при движении | `zs_movementviewroll` | check |
| `options_filmgrain_amt` | Film grain | Зерно плёнки | `zs_filmgrainopacity` | slider 0–255, decimals 1 |
| `options_dmg_size` | Damage number size | Размер чисел урона | `zs_dmgnumberscale` | slider 0.5–2, decimals 1 |
| `options_dmg_speed` | Damage number speed | Скорость чисел урона | `zs_dmgnumberspeed` | slider 0–1, decimals 1 |
| `options_dmg_life` | Damage number lifetime | Время жизни чисел урона | `zs_dmgnumberlife` | slider 0.2–1.5, decimals 1 |

---

## Листы вкладок

Порядок AddSheet как было:

```lua
propertysheet:AddSheet(RelapseUI.T("options_tab_game"), gameTab)
propertysheet:AddSheet(RelapseUI.T("options_tab_hud"), hudTab)
propertysheet:AddSheet(RelapseUI.T("options_tab_view"), viewTab)
propertysheet:AddSheet(RelapseUI.T("options_tab_audio"), audioTab)
propertysheet:AddSheet(RelapseUI.T("options_tab_fx"), fxTab)
```
