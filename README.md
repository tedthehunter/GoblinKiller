# Goblin Killer

A Godot 4 dungeon-crawler vertical slice with reusable actor scenes, authored room layouts, data-driven combat encounters, and two connected floors.

## Run

Open `project.godot` in Godot 4.2 or newer and press **F6** or **F5**. Select a class, move with WASD or the arrow keys, then click in the game window or press Space to attack. Esc pauses. Press R after victory or defeat to restart.

## Phase 1 vertical slice

- Class-selection UI for Warrior, Mage, and Thief
- Reusable Player and Goblin scenes with shared health, optional mana, damage, and attack-speed stats
- Warrior: delayed melee cleave with no Mana
- Thief: ranged throwing-dagger projectile with no Mana
- Mage: Mana-regenerating, Mana-consuming fireball with area damage
- Two authored floors made of bounded rooms and hallways; both player and enemies obey the room boundaries
- Data-driven room encounters in `data/encounters/`, including per-encounter health and damage modifiers
- Floor 1 stairs load Floor 2 after its encounters are cleared
- Floor 2 ends at a victory altar after its encounters are cleared

Phase 2 systems (fog of war, minimap, non-combat encounters, items, and gear) are intentionally not included.
