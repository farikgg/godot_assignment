# AI log

Файлы, написанные или изменённые ИИ-ассистентом (Claude Code). Остальное написано автором, с одной оговоркой:

- `scripts/player.gd`: каркас (RigidBody3D, экспорты, цвет шара из профиля) — автор; ввод, приложение силы с ограничением скорости, прыжок и обработка столкновения с врагом написаны чат-ассистентом (не Claude Code), автор перенёс их в проект.

## Ключ, решётка и туннель

Созданы:
- `scripts/swing_door.gd` + `scenes/props/swing_door.tscn`: калитка из старого `door.gd`/`door.tscn` (коммит `1866152`): `Body` на шарнире, датчик `Sensor`, открывается от игрока и закрывается при отъезде. Tween заменён клипами `swing_pos` / `swing_neg` (0 → ±100°, 0.6 с), закрытие — тот же клип задом наперёд (`play_backwards`), поэтому при повторном въезде на середине дверь не дёргается. Сторона выбирается только из закрытого положения.
- `scripts/key_pickup.gd` + `scenes/props/key_pickup.tscn`: ключ в группе `key`, сигнал `collected`, по образцу монеты. Модель `key.glb` ×1.5, клип `spin_bob`.
- `scenes/props/tunnel.tscn`: арка `wall-opening` и коридор из сегментов `wall` (ширина 2 м, глубина 6 м), торцевая стена, тёмный пол.
- `scenes/props/saw_trap.tscn`, `scenes/props/saw_trap_patrol.tscn`: круглые пилы из примитивов (диск r 0.9, 14 зубьев, втулка, терракотовое основание), `Body` — AnimatableBody3D в группе `enemy`. Клип `spin` (1 оборот/с) вращает только визуальный узел `Blade`: коллизия — цилиндр, при вращении она не меняется. У патрульной клип `patrol` 4 с: `Body` x 0 → 3 → 0 и 4 оборота диска, плюс рейка.
- `assets/Map/iron-fence.glb`: модель решётки.

Изменены:
- `scenes/props/door.tscn` → `locked_gate.tscn`, `scripts/door.gd` → `locked_gate.gd` (`git mv`): модель `iron-fence.glb` ×2 по центру, тёмный металл, бокс по габаритам, группа `locked_gate`. Клипы `closed`/`open` двигают `Body:position:y` (open: 0 → 2.058 за 0.8 с, без цикла); AnimationTree не тронут.
- `scenes/props/exit.tscn`: чистый триггер (бокс 1.8×1.5×1.8), без сундука; `PulseZone` у входа.
- `scripts/main.gd`: монеты только считаются; ключ (`has_key`) открывает группу `locked_gate`; подсказка «Нужен ключ» от `GateHint`; победа на выходе без проверки монет.
- `scenes/map.tscn`: `Door` → калитка; `Tunnel`, `LockedGate`, `GateHint`, `KeyPickup`, `Exit` в конце туннеля; `KeyLabel` в HUD; `Saw`/`SawPatrol` вместо лезвий; удалена `MovingPlatform`.
- `tools/test_anim.gd`: восстановлен и переписан под решётку, пилы, ключ.

## Лабораторная A5 — анимация (3D)

Ворота (`scenes/props/door.tscn`, клипы и AnimationTree собраны автором; позже переименованы в `locked_gate`, см. выше):
- Причина самопроизвольного открытия: у AnimationTree было сохранено `parameters/conditions/open = true`, поэтому переход closed → open (Auto, условие `open`, Immediate) срабатывал сразу. Значение удалено, у экземпляра Door в `map.tscn` переопределений не было.
- Удалён узел `Sensor` с коллизией. `door.gd` (автора): `add_to_group("gate")` и `open()`.
- `scripts/main.gd`: убраны отладочный `print`, ссылка на несуществующий `$AnimationTree` и `add_to_group("gate")` у Main (иначе `call_group("gate", "open")` вызывал бы `open()` у Main). Ворота открывались в `_on_coin_collected`, когда собраны все монеты (позже заменено открытием по ключу).

Созданы:
- `scenes/props/blade_trap.tscn`: AnimatableBody3D в группе `enemy`, лезвие 2×0.2×0.3 на y 0.5, клип `spin`. Позже заменено пилами и удалено.
- `scenes/props/moving_platform.tscn`: Node3D с AnimatableBody3D `Body`, плита 2×0.2×2, клип `move` по `Body:position:x`. Позже удалена.
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
- `tools/prep_ui_assets.py` (автор удалил его в `44a8097`; готовые текстуры в `assets/ui_gen/` остались): готовил текстуры из исходников в `assets/UI/` (палитровые PNG 2752×1536, сгенерированные рендеры; файлы ищутся по префиксу имени, потому что в имени есть метка времени).
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
- `scripts/door.gd` (историческое описание, версия ЛР4): открывал и закрывал `AnimatableBody3D` «Body» через Tween (`TWEEN_PROCESS_PHYSICS`) по сигналам датчика «Sensor». Сейчас этот файл — `locked_gate.gd`, а калитка с датчиком живёт в `swing_door.gd` на клипах.
- `scenes/props/enemy.tscn`: `StaticBody3D` в группе `enemy`, твёрдый бокс, модель `trap.glb`.
- `scenes/props/exit.tscn`: `Area3D` в группе `exit` со скриптом `exit.gd`, модель `chest.glb` (сундук позже убран, см. «Ключ, решётка и туннель»).
- `scenes/props/door.tscn` (историческое описание, версия ЛР4): `Node3D` с детьми `Body` (`AnimatableBody3D`, `sync_to_physics`, модель `gate.glb`) и `Sensor` (`Area3D` вне `Body`).
- `scripts/door.gd.uid` и `scripts/exit.gd.uid` сгенерированы Godot.

Изменены:
- `scripts/main.gd`: логика монет (`coins_total`, счётчик «Монеты: x / y») и выхода (победа, подсказка на 2 секунды, защита от повторов).
- `scenes/map.tscn`: узел `Enemies` (2 врага), `Exit`, `Door`, `UI/MessageLabel`.

## Ранее (уровень и декор)

- `scenes/props/*.tscn` (24 сцены-обёртки декора): сгенерированы ИИ. `stairs`, `wall-opening`, `stones`, `wood-structure` и `wood-support` потом правил автор.
- `scenes/coin.tscn`: модель `coin.glb` вместо цилиндра.
- `scenes/map.tscn`: раскладка `Decor` по референсу, сброс поворотов монет.
- `scenes/player.tscn`: настройка ортогональной камеры. Позже автор перенёс камеру в `map.tscn`.
