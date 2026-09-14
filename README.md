# Goblin Killer

A Godot 4 proof-of-concept dungeon crawler based on the supplied design document.

## Run

Open `project.godot` in Godot 4.7.2 and press **F6** or **F5**. Select a class, then click in the game window or press Space to attack. Press R after a win or loss to restart.

## Combat prototype coverage

- Class-selection UI for Warrior, Mage, and Thief
- Entity spawning for player and three goblins
- Shared health, optional mana, damage, and attack-speed stats
- Warrior: delayed melee cleave with no Mana
- Thief: ranged throwing-dagger projectile with no Mana
- Mage: Mana-regenerating, Mana-consuming fireball with area damage
- Damage resolves on the cleave impact or projectile collision, rather than on input
- Enemy damage and victory/defeat loop
