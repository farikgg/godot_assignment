# AI log

Файлы, написанные или изменённые ИИ-ассистентом (Claude Code). Всё остальное в проекте, включая `player.tscn` / `player.gd`, написано автором.

## Единый стиль меню и HUD

Созданы:
- `tools/prep_ui_assets.py`: готовит текстуры из исходников `assets_src/ui/` (палитровые PNG 2752×1536, сгенерированные рендеры).
  - Переводит в RGBA и обрезает по bbox (alpha > 10, отступ 2 px).
  - Убирает розовую кайму: всем пикселям с alpha < 250 ставит RGB ближайшего непрозрачного пикселя (`scipy.ndimage.distance_transform_edt`), альфа не меняется.
  - Уменьшает LANCZOS, рисует бегунок слайдера с суперсэмплингом ×8. С ключом `--preview` пишет наложения на тёмный и светлый фон.
  - Порог 250, а не 255, потому что после квантования палитры тело картинки имеет alpha 250–254, а ровно 255 почти нет.
- `assets_src/ui/` (исходники и `.gdignore`), `assets/ui_gen/*.png|jpg`: результат скрипта.
- `assets/ui_gen/ui_theme.tres`: глобальная тема. Шрифт Rubik-Bold. Стили Button и OptionButton, PopupMenu, LineEdit, PanelContainer, HSlider, Label, плюс вариации `HudPanel` (рамка `frame_small`) и `ClearPanel` (прозрачная панель).
- `scripts/title_label.gd`: константа `GAME_TITLE` («Dungeon Roller»), ставится в Label на вывеске. В `config/name` то же значение.
- `scripts/message_panel.gd`: показывает панель сообщения, только пока в `MessageLabel` есть текст. `main.gd` пишет только текст, поэтому видимость рамки решает панель.

Изменены:
- `project.godot`: `config/name`, секция `[gui]` (`theme/custom`, `theme/custom_font`).
- `scenes/main_menu.tscn`:
  - Фон и вывеска с названием.
  - Колонка меню без рамки, с y = 520.
  - SettingsPanel в рамке, с заголовком и подписями.
  - Убрана явная ссылка на старый `theme.tres` (сам файл оставлен).
  - Тексты кнопок переведены на русский.
- `scenes/map.tscn`: HUD перестроен на `HudPanel` (NameRow + CoinLabel) и `MessagePanel`. У `CoinLabel`, `NameLabel` и `MessageLabel` включён `unique_name_in_owner`.
- `scripts/main.gd`: только пути `@onready`: `$UI/CoinLabel` → `%CoinLabel`, `$UI/NameLabel` → `%NameLabel`, `$UI/MessageLabel` → `%MessageLabel`.

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
