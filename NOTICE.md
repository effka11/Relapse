# NOTICE — Relapse

**Relapse** is a **Flora Studio** product.

It is **not** Flora Ecosystem, **not** Flora Social, and is **not** licensed under the GNU Affero
General Public License (AGPL). A Flora Studio credit on Relapse does not relicense the gamemode.

**Copyright in Relapse original work © 2026 Egor Ozerskikh (Егор Озерских) / Flora Studio.**
Commercial / legal: **e.ozerskikh@gmail.com**.

This file is the map of which license applies to which materials. Preserve it in copies and
derivative distributions of Relapse.

Кратко: Relapse — продукт Flora Studio на базе Zombie Survival (JetBoom, лицензия JBGM). Код режима
не AGPL. Дизайн — отдельно, см. [`LICENSE-DESIGN.md`](LICENSE-DESIGN.md).

## 1. Software (gamemode, Lua, addons)

Relapse is an unofficial derivative of **Zombie Survival** by William “JetBoom” Moodhe.

All software in this repository that is Zombie Survival, or that edits it, or that depends on it
to run — including Relapse Lua (theme, VGUI, usefulness, weapons glue, and other modifications) —
is distributed under the **JBGM LICENSE**. The license text is [`LICENSE`](LICENSE) (also copied as
`gamemodes/zombiesurvival/license.txt`). That file must not be modified.

Relapse-original program code is copyright Flora Studio / Egor Ozerskikh and is licensed **under
the JBGM LICENSE as part of that derivative**, not under AGPL, MIT, Apache, or a Flora Ecosystem
code license.

You may copy, distribute, and create further derivatives only as JBGM allows, including its
restrictions on revenue-generating gameplay modifications and on denying the Author (William Moodhe)
access needed to see whether the gamemode was modified.

This is **not** an official JetBoom, noxiousnet, Facepunch, or Valve product.

### Upstream pin

Relapse is derived from this exact Zombie Survival snapshot. Later JetBoom commits are **not**
part of Relapse unless they are merged on purpose after reviewing their license text. This pin
records the copy and JBGM terms Relapse received. It does not relicense Zombie Survival or bind
JetBoom.

| | |
|---|---|
| Repository | <https://github.com/JetBoom/zombiesurvival> |
| Commit | `82bea3f0573f751c4c78d2962e295d3dd142b54a` (`82bea3f`) |
| Date (UTC) | 2025-06-10 20:51:18 |
| Author | William Moodhe |
| Message | Merge pull request #257 from piqey/breakable-door-support |
| Tree | `b86e7f2ba57905727f5da93d558df0d432e72781` |
| Permalink | <https://github.com/JetBoom/zombiesurvival/commit/82bea3f0573f751c4c78d2962e295d3dd142b54a> |
| License as received | JBGM LICENSE VERSION Xx420xX4, 05 May 2018 — [`LICENSE`](LICENSE) |
| Git tag (this repo) | `upstream-jetboom-82bea3f` (points at the upstream commit object, not at Relapse `main`) |

## 2. Design and non-code materials

Documentation under `documents/`, Relapse visual identity, UI/UX concepts, and other non-code
Relapse materials are licensed under [`LICENSE-DESIGN.md`](LICENSE-DESIGN.md)
(**CC BY-SA 4.0** or a commercial content license from the copyright holder).

The Relapse adaptation of the Flora design language is licensed there as Relapse design, **not**
under AGPLv3, and does **not** relicense Flora Ecosystem source.

Code that implements that design in-game remains section 1 (JBGM).

## 3. Third-party components (not relicensed)

These remain under their own terms. Relapse licenses do not replace them.

| Material | Notes |
|---|---|
| **Zombie Survival** | William Moodhe — JBGM LICENSE ([`LICENSE`](LICENSE)) |
| **Manrope** | SIL Open Font License 1.1 — `gamemodes/zombiesurvival/content/resource/fonts/OFL.txt` |
| **Modern Warfare 2019 SWEPs / Sykov** (`addons/zzz_relapse_mw_sykov`, `reference/mw2019_sykov`, Workshop) | Third-party GMod port; models, sounds, and related assets originate with Activision / Infinity Ward and the SWEP authors. **Not** Flora Studio content; **not** licensed by this repository |
| **Garry’s Mod, Source, Half-Life 2** | Facepunch / Valve. Relapse is an unofficial mod and does not grant rights in those works |
| Other credited sounds, models, and translations | See in-game credits (`GM.RelapseCreditSections`) and original ZS attribution; still not relicensed here |

## 4. Names and marks

**Relapse** and **Flora Studio** designate this game and its publisher.

**Flora**, **Flora Ecosystem**, and **Flora Social** designate a separate Flora Studio work. They
are not names for this gamemode. Relapse must not be presented as Flora Ecosystem, as an official
Flora network product, or as licensed under AGPL.

JBGM, Zombie Survival, and JetBoom remain marks / names of their respective holders.

No trademark license is granted by [`LICENSE`](LICENSE) or [`LICENSE-DESIGN.md`](LICENSE-DESIGN.md)
except the limited descriptive attribution required to keep these notices accurate.

## 5. Contacts

- Relapse / Flora Studio copyright and commercial licensing: **Egor Ozerskikh — e.ozerskikh@gmail.com**
- Zombie Survival / JBGM: **William Moodhe — williammoodhe@gmail.com** (noxiousnet.com)
