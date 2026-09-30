# AI log

Файлы, написанные или изменённые ИИ-ассистентом (Claude Code). Всё остальное в проекте, включая `player.tscn` / `player.gd`, написано автором.

## Поворот камеры (4 изометрических ракурса)

Создан:
- `scripts/camera_rig.gd`: скрипт на `CameraPivot`. По `camera_left` / `camera_right` поворачивает пивот на −90° / +90°. Используется Tween (`turn_duration` = 0.35 с, `TRANS_SINE` / `EASE_IN_OUT`) по `rotation_degrees:y`. Целевой угол накапливается и не сворачивается в 0–360.

Изменён:
- `scenes/map.tscn`: `Camera3D` перенесена в новый `CameraPivot` (`Node3D` в (0, 0, 0), yaw 45°, скрипт `camera_rig.gd`). Локальный трансформ камеры: наклон −35°, позиция (0, 8, 11.425). Мировой поворот тот же (−35, 45, 0), а центр кадра теперь в центре карты.

## Лабораторная 4 — физика (враги, выход, дверь)

Созданы:
- `scripts/exit.gd`: сигнал `reached` по `body_entered`, если тело в группе `player`.
- `scripts/door.gd`: открывает и закрывает `AnimatableBody3D` «Body» через Tween (`TWEEN_PROCESS_PHYSICS`) по сигналам датчика «Sensor».
- `scenes/props/enemy.tscn`: `StaticBody3D` в группе `enemy`, твёрдый бокс, модель `trap.glb`.
- `scenes/props/exit.tscn`: `Area3D` в группе `exit` со скриптом `exit.gd`, модель `chest.glb`.
- `scenes/props/door.tscn`: `Node3D` с детьми `Body` (`AnimatableBody3D`, `sync_to_physics`, модель `gate.glb`) и `Sensor` (`Area3D` вне `Body`).
- `scripts/door.gd.uid` и `scripts/exit.gd.uid` сгенерированы Godot.

Изменены:
- `scripts/main.gd`: логика монет (`coins_total`, счётчик «Монеты: x / y») и выхода (победа, подсказка на 2 секунды, защита от повторов).
- `scenes/map.tscn`: узел `Enemies` (2 врага), `Exit`, `Door`, `UI/MessageLabel`.

## Ранее (уровень и декор)

- `scenes/props/*.tscn` (24 сцены-обёртки декора): сгенерированы ИИ. `stairs`, `wall-opening`, `stones`, `wood-structure` и `wood-support` потом правил автор.
- `scenes/coin.tscn`: модель `coin.glb` вместо цилиндра.
- `scenes/map.tscn`: раскладка `Decor` по референсу, сброс поворотов монет.
- `scenes/player.tscn`: настройка ортогональной камеры. Позже автор перенёс камеру в `map.tscn`.
