# AI log

Файлы, написанные или изменённые ИИ-ассистентом (Claude Code). Всё остальное в проекте, включая `player.tscn` / `player.gd`, написано автором.

## Лабораторная A5 — анимация (3D)

Ворота (`scenes/props/door.tscn`, клипы и AnimationTree собраны автором):
- Причина самопроизвольного открытия: у AnimationTree было сохранено `parameters/conditions/open = true`, поэтому переход closed → open (Auto, условие `open`, Immediate) срабатывал сразу. Значение удалено, у экземпляра Door в `map.tscn` переопределений не было.
- Удалён узел `Sensor` с коллизией. `door.gd` (автора): `add_to_group("gate")` и `open()`.
- `scripts/main.gd`: убраны отладочный `print`, ссылка на несуществующий `$AnimationTree` и `add_to_group("gate")` у Main (иначе `call_group("gate", "open")` вызывал бы `open()` у Main). Ворота открываются в `_on_coin_collected`, когда собраны все монеты.

Созданы:
- `scenes/props/blade_trap.tscn`: AnimatableBody3D в группе `enemy`, лезвие 2×0.2×0.3 на y 0.5, клип `spin`.
- `scenes/props/moving_platform.tscn`: Node3D с AnimatableBody3D `Body`, плита 2×0.2×2, клип `move` по `Body:position:x`. Анимируется дочернее тело, а не корень, чтобы экземпляр сохранял свою позицию на карте.
- `scenes/props/pulse_zone.tscn`: золотой светящийся диск r 1.4, клип `pulse` (масштаб диска).
- `tools/test_anim.gd`: headless-проверка ворот, движения всех анимированных объектов, `loop_mode`/`autoplay` циклов и `callback_mode_process` у проигрывателей, двигающих AnimatableBody3D. Печатает PASS/FAIL и выходит с кодом 0 или 1.

Изменены:
- `scenes/coin.tscn`: AnimationPlayer с клипом `spin_bob` на узел `Model`. `scripts/coin.gd`: убраны `_process` и связанные с ним переменные.
- `scenes/map.tscn`: `Enemies/Blade1` (7.78, 0.1, 1.33), `Enemies/Blade2` (−6, 0.1, −4), `MovingPlatform` (1.5, 0.1, 4.9).
- `scenes/props/exit.tscn`: дочерний `PulseZone` на y 0.012 над верхом пола.

## Ник над шаром

Создан:
- `scripts/name_tag.gd`: на Label3D «NameTag». Берёт текст из `Profile.player_name` и каждый кадр ставит `global_position` = позиция родителя + `follow_offset` (0, 1, 0). У узла включён `top_level`: шар-RigidBody вращается при качении, и обычный дочерний узел облетал бы его по кругу. Экспорт назван `follow_offset`, потому что у Label3D уже есть своё свойство `offset`.

Изменён:
- `scenes/player.tscn`: добавлен дочерний `NameTag` (billboard, no_depth_test, pixel_size 0.01, font_size 48, outline_size 12, цвета палитры). `player.gd` не менялся.

## Единый стиль меню и HUD

Созданы:
- `tools/prep_ui_assets.py`: готовит текстуры из исходников в `assets/UI/` (палитровые PNG 2752×1536, сгенерированные рендеры; файлы ищутся по префиксу имени, потому что в имени есть метка времени).
  - Переводит в RGBA и обрезает по bbox (alpha > 10, отступ 2 px).
  - Убирает розовую кайму: всем пикселям с alpha < 250 ставит RGB ближайшего непрозрачного пикселя (`scipy.ndimage.distance_transform_edt`), альфа не меняется.
  - Уменьшает LANCZOS, рисует бегунок слайдера с суперсэмплингом ×8. С ключом `--preview` пишет наложения на тёмный и светлый фон.
  - Порог 250, а не 255, потому что после квантования палитры тело картинки имеет alpha 250–254, а ровно 255 почти нет.
- `assets/ui_gen/*.png|jpg`: результат скрипта. Исходники автор хранит в `assets/UI/`; папка `assets_src/` удалена.
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
