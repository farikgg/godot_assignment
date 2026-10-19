# AI log

Файлы, написанные или изменённые ИИ-ассистентами. Остальное написано автором, с оговоркой:

- `scripts/player.gd` и `scenes/player.tscn`: скелет автора (RigidBody3D, экспорты, цвет шара из профиля). Управление, силу с ограничением скорости, прыжок, проверку земли (`_integrate_forces`) и обработку врагов писал ИИ-ассистент Claude в чате; автор перенёс это в проект. Правки Claude Code в этих файлах перечислены в разделах ниже (NameTag, A6).
- Начиная с раздела «A6 — персонаж и выбор героя» `player.gd` и `player.tscn` целиком переписаны Claude Code под CharacterBody3D; версия с шаром осталась в истории git.

## Мидтерм — этап 1

Структура игры: главное меню → уровень 1 → уровень 2 → уровень 3 (арена) → экран победы.

Созданы:
- `scripts/game_flow.gd` (автозагрузка `GameFlow`): `LEVELS`, `current_index`, `total_coins`; `start_game` / `next_level(coins)` / `restart_level` / `go_to_win` / `go_to_menu`. Перед любой сменой сцены снимает паузу; `change_scene_to_file` с проверкой ошибки (`push_error`). `register_level` выставляет индекс, если уровень запущен напрямую (F6).
- `scripts/kill_zone.gd` + `scenes/props/kill_zone.tscn`: `Area3D` 400×2×400 и тёмная плоскость «бездны»; игрока убивает через `Health.kill()`, мимо неуязвимости. Стоит на y = −6 в каждом уровне.
- `scripts/props/floor_slab.gd` (`FloorSlab`, `@tool`) + `scenes/props/floor_slab.tscn`, `scenes/props/platform_block.tscn`: плиты пола и уступы с экспортами `size` / `thickness`; верх плиты в начале координат узла.
- `scenes/pickups/potion_pickup.tscn` (наследник `potion.tscn`, лежит «вечно»), `scenes/systems/spawner_cave_in.tscn` (наследник `spawner.tscn`: бочки и камни).
- `scenes/levels/level_2.tscn`, `scenes/levels/level_3_boss.tscn`: только инстансы, группирующие `Node3D` и `Marker3D BossSpawn`.
- `scripts/win_screen.gd` + `scenes/win_screen.tscn`: фон меню, «Ты выбрался на свет!», «Золота собрано: N» из `GameFlow.total_coins`, кнопка «В главное меню».
- `scripts/blob_shadow.gd`: круглая тень (полупрозрачный диск) под героем; луч вниз каждый физический кадр, уменьшается с высотой, над пропастью скрыта.
- `tools/test_flow.gd`: `start_game` → level_1; `next_level` 1 → 2 → 3 → победа и сумма монет; `go_to_menu`; `restart_level` перезагружает уровень новым экземпляром; пауза снята в момент смены сцены; KillZone убивает неуязвимого героя.

Изменены:
- `scripts/main.gd` → `scripts/level.gd` (`class_name Level`, `git mv`): экспорт `level_title` (тост на старте); выход → тост и `GameFlow.next_level` через 1.5 с; смерть → перезапуск через 1.5 с; таймер выживания A6 убран.
- `scenes/map.tscn` → `scenes/levels/level_1.tscn` (`git mv`): острова с пропастями 1.8–2 м, три уступа с монетами, лежащее зелье, KillZone; убраны сплошной пол, спавнер, патрульная пила и калитка.
- `scenes/props/moving_platform.tscn`: восстановлена из истории git, верх вровень с корнем, ширина 2.6 м; стоит в level_2.
- `scripts/health.gd`: `kill()`. `scripts/ui/hud.gd`, `scenes/ui/hud.tscn`: убрана строка таймера выживания.
- `scripts/main_menu.gd`, `scenes/main_menu.tscn`, `scripts/pause_menu.gd`: кнопки идут через `GameFlow`, «Выйти».
- `scripts/data/character_data.gd`: `anim_jump` / `anim_fall`. `scripts/player.gd`: в воздухе клип `jump` (вверх) или `fall` (вниз, зациклен), атака и смерть в приоритете; `jump_velocity` 5.0 → 5.5; экспорт `jump_sound_path` (пусто — тишина). `scenes/player.tscn`: `JumpSfx`, `BlobShadow`.
- `tools/test_anim.gd`: проверяет все три уровня (патрульная пила и движущаяся платформа — в level_2). `tools/test_a7.gd`: путь к level_1, спавнер необязателен.

Прыжок: v = 5.5 м/с, g = 9.8 → высота v²/2g ≈ 1.54 м (замер 1.59 м), время в воздухе ≈ 1.12 с, дальность по ровному при `move_speed` 5 ≈ 5.6 м. Самый высокий шаг (+1.4 м) берётся на спуске при t ≈ 0.73 с, до 3.66 м по горизонтали. Решётки (1.76 м) стоят под аркой туннеля, перепрыгнуть их нельзя.

## A7 — ввод и мобильное управление

Ассеты: `assets/Mobile/` — Kenney Mobile Controls (CC0), Style A + Highlights B. Использованы (Large 2×): `joystick_circle_pad_a` + `joystick_circle_pad_highlight` (фон стика), `joystick_circle_nub_b` (ручка), `button_circle` + `button_circle_highlight` (удар, пауза), `dpad_element_north` + `_highlight` (прыжок, стрелка вверх), `direction_left/right` + `_highlight` (поворот камеры). Иконок меча и паузы в наборе нет: на этих кнопках текст «Удар» и «II» шрифтом темы.

Input Map (`project.godot`):

| Действие | Биндинги |
|---|---|
| `move_left` / `move_right` | A / D, ← / →, левый стик ось 0 (−/+) |
| `move_forward` / `move_back` | W / S, ↑ / ↓, левый стик ось 1 (−/+) |
| `jump` | Space, кнопка 0 (A / Cross) |
| `attack` | ЛКМ, J, X, кнопка 2 (X / Square) |
| `pause` | Escape, P, кнопка 6 (Start) |
| `camera_left` / `camera_right` | Q / E, кнопки 9 / 10 (LB / RB) |

Все `move_*` — deadzone 0.2, устройство «все». Сначала стрелки были отданы камере; в правках A7 они вернулись в движение (композиты WASD + стрелки), камера переехала на Q / E.

Созданы:
- `scripts/input/player_input_handler.gd` (`PlayerInputHandler`, дочерний узел игрока): в `_unhandled_input` хранит силу `move_*` по каждому источнику (тип устройства + id; итог — максимум, чтобы стик в нуле не отменял зажатую клавишу), `move = (right − left, back − forward)` с `limit_length(1)`, сигналы `jump_pressed` / `attack_pressed` без эха и не на паузе; на паузе продолжает отслеживать отпускания, при потере фокуса сбрасывается.
- `scripts/ui/virtual_stick.gd` (`VirtualStick`), `scripts/ui/touch_action_button.gd` (`TouchActionButton`), `scripts/ui/touch_controls.gd` + `scenes/ui/touch_controls.tscn`: стик эмулирует левый стик геймпада (`InputEventJoypadMotion`, виртуальное устройство 8), кнопки шлют `InputEventAction`; обводка при нажатии, кнопки уменьшаются до 0.92; мультитач по индексу пальца; использованные события помечаются обработанными, поэтому клик по стику не становится ударом. `is_primary_click()` в стике — единственное место с `MOUSE_BUTTON_LEFT`. `show_on_desktop`, слой работает и на паузе.
- `tools/test_a7.gd`: ось 0 и клавиша D дают `move.x = 1`, вместе — длина ≤ 1; `InputEventAction(jump)` → `jump_pressed`; в `scripts/` нет `KEY_*` / `MOUSE_BUTTON_*` / `Input.is_key_pressed` (кроме `virtual_stick.gd`); экранный стик двигает героя, отпускание шлёт 0; клик по стику не бьёт, клик мимо — бьёт.

Изменены:
- `scripts/player.gd`: не читает `Input`; движение из `input_handler.move`, прыжок и атака по сигналам обработчика. `scenes/player.tscn`: узел `InputHandler`.
- `scripts/weapons/sword.gd`: больше не слушает ввод сам, `try_attack()` вызывает игрок.
- `scripts/ui/hud.gd`: строки про ключ от решётки переименованы в `HAS_KEY_TEXT` / `NO_KEY_TEXT`, чтобы проверка на `KEY_*` не давала ложных срабатываний.
- `project.godot`: stretch `canvas_items` + aspect `expand`, ориентация `sensor_landscape`, эмуляция тача мышью и мыши тачем.
- `scenes/map.tscn`: инстанс `TouchControls`.
- `tools/test_a6.gd`, `tools/test_anim.gd`: восстановлены (удалены в `1cc7562`).

Правки A7:
- Стрелки вернулись в `move_*`, камера на Q / E (таблица выше); подсказка про меч: «J, X или ЛКМ — удар». `test_a7`: стрелка → двигает и не поворачивает камеру, Q / E поворачивают.
- Уведомления — тост вместо баннера: `scenes/ui/toast.tscn` + `scripts/ui/toast.gd` (`Toast`) внутри HUD. Плашка `HudPanel` (рамка `frame_small`), сверху по центру с отступом 24 px, ширина по тексту, не больше 40 % экрана, дальше перенос строк; шрифт темы 28. `show_toast(text, duration = 2.5)`: появление 0.2 с (прозрачность + сдвиг сверху), ожидание, исчезновение 0.3 с; новый тост заменяет текст и перезапускает ожидание; `duration <= 0` — до следующего сообщения (победа, смерть). Режим паузы твина выбирается при показе: вызванный на паузе тост играет на паузе, обычный замирает вместе с игрой. Плашка переподгоняется по сигналу `minimum_size_changed`, потому что `Label` с переносом пересчитывает строки на кадр позже.
- `scripts/ui/hud.gd`: `show_message` / `clear_message` с прежними сигнатурами идут в тост; `MessagePanel` и `scripts/message_panel.gd` удалены.
- `test_a7`: длинный текст переносится и не шире 40 %, тост не перекрывает панель HUD, замена без наложения, поведение на паузе.

## A6 — правки

Камера:
- `scripts/camera_rig.gd`: пока идёт поворот, `camera_left` / `camera_right` игнорируются; после поворота угол сворачивается `fposmod` в 0–360. Слежение не менялось.

Ресурсы героев:
- `git mv data resources`: `resources/characters/*.tres`, `resources/character_roster.tres`; путь в автозагрузке `Roster` обновлён. У ресурсов теперь есть uid (у `female_a` — тот, что уже выдал редактор автора), ростер ссылается на героев по uid и пути. Проверено: uid разрешаются в новые пути, ростер грузится по uid.

Разделение `map.tscn` (в карте остались `Main` со скриптом, инстансы сцен с трансформами и пустые группирующие `Decor` / `Enemies`):
- `WorldEnvironment` (+ небо и окружение) и `DirectionalLight3D` → `scenes/systems/lighting.tscn`;
- `Floor` (StaticBody3D, коллизия, меш) → `scenes/props/floor.tscn`;
- `GateHint` (Area3D + форма) → `scenes/props/gate_hint.tscn`;
- `Spawner` (скрипт и список опасностей) → `scenes/systems/spawner.tscn`;
- `CameraPivot` (`camera_rig.gd`) + `Camera3D` → `scenes/systems/camera_rig.tscn`;
- `UI` (HudPanel, HeartsBox, CoinLabel, KeyLabel, SurvivalLabel, MessagePanel) → `scenes/ui/hud.tscn` + `scripts/ui/hud.gd` (`set_player_name`, `set_hearts`, `set_coins`, `set_key`, `set_survival_time`, `show_message`, `clear_message`); `main.gd` обращается к HUD только через эти методы;
- `PickupSfx` → звук подбора у самих монеты и ключа (`Sfx.play`, доигрывает после `queue_free`).

Спавн:
- `scripts/spawner.gd`: `spawn_weights` параллельно `hazard_scenes`, выбор через `rand_weighted`; пустой список, несовпадение длин, отрицательный вес или нулевая сумма — `push_error`, спавнер не запускается. В карте: бочка 1.0, камень 0.0, зелье 0.0.

Меч:
- `scenes/pickups/sword_pickup.tscn` + `scripts/pickups/sword_pickup.gd`: меч на полу (клип `spin_bob`), при входе игрока вызывает `equip_weapon` и удаляется; подсказка «Меч найден. J или ЛКМ — удар».
- `scripts/player.gd`: `equip_weapon(scene)` / `has_weapon()`; `Sword` убран из `player.tscn`, без оружия атака ничего не делает.
- `scripts/weapons/sword.gd`: рукоять в кулаке (0.92 руки от плеча), клинок вперёд и вверх (37°) в позе idle; поворот считается в пространстве кости из наклона руки в idle (45°, одинаково у всех 12 моделей), поэтому отдельный `weapon_offset` на героя не понадобился. `blade_length` в метрах (0.35 ≈ 0.9 руки).

Звуки:
- Все пути к звукам по умолчанию пустые; пустой путь — тишина без сообщений, предупреждение только для непустого пути к отсутствующему файлу.

Тесты:
- `tools/test_a6.gd`: веса 1/0/0 дают только бочки, несовпадение длин — ошибка без падения; до подбора атака не создаёт Slash, после `equip_weapon` создаёт.

## A6 — персонаж и выбор героя

Найдено в моделях (`assets/Characters/character-{male,female}-{a..f}.glb`, 12 штук, у всех одинаково):
- кости: `root`, `leg-left`, `leg-right`, `torso`, `arm-left`, `arm-right`, `head`; рука в T-позе вдоль −X кости, длина около 0.28 единицы модели;
- анимации (32): `static`, `idle`, `walk`, `sprint`, `jump`, `fall`, `crouch`, `sit`, `drive`, `die`, `pick-up`, `emote-yes`, `emote-no`, `holding-*`, `attack-melee-right/left`, `attack-kick-right/left`, `interact-*`, `wheelchair-*`. Клипа «получил удар» нет, поэтому `anim_hit` пустой и пропускается.

Созданы:
- `scripts/data/character_data.gd` (`CharacterData`): id, имя, модель, цена (пока не используется), `unlocked_by_default`, `model_scale`, `hand_bone`, `arm_length`, имена анимаций (пустая строка = нет).
- `scripts/data/character_roster.gd` (`CharacterRoster`) + `data/character_roster.tres` + `data/characters/*.tres` (12 героев; позже перенесены в `resources/`) + автозагрузка `scripts/roster.gd` (`Roster`): `get_by_id` при неизвестном id откатывается на первого с `push_warning`.
- `scenes/ui/character_select.tscn` + `scripts/ui/character_select.gd`: панель «Выбери героя», стрелки, имя, 3D-превью в SubViewport (модель вращается и играет idle), «Выбрать» сохраняет `Profile.character_id`. Стрелки — иконки `assets/ui_gen/arrow_{left,right}.png`: в Rubik нет ◀ ▶.
- `scripts/fx/one_shot_fx.gd` + `scenes/fx/dust_puff.tscn`, `explosion_burst.tscn`: одноразовые GPUParticles3D, удаляются сами (по `finished` и по таймеру, т. к. без рендера `finished` не приходит).

Изменены:
- `scripts/profile.gd`: `ball_color_index` → `character_id`; старое сохранение с одним цветом мигрирует на первого героя. `save_path` можно подменить (для теста).
- `scripts/player.gd`, `scenes/player.tscn`: CharacterBody3D (капсула r 0.3, h 1.1, начало координат у ног), движение относительно камеры с ускорением, гравитация, прыжок; `Visual` с моделью из ростера (×1.4), поворот через `lerp_angle`; анимации idle/run/attack/hit/die с пропуском отсутствующих, idle и run зацикливаются в коде (glTF импортируется без цикла); урон через `Hurtbox` + отталкивание скоростью; `get_hand_socket()` — BoneAttachment3D на `hand_bone`, иначе Marker3D с предупреждением. `jump_velocity` 5.0, чтобы не перепрыгивать закрытую решётку.
- `scripts/name_tag.gd`: только текст; тело больше не вращается, `top_level` и слежение не нужны.
- `scripts/weapons/sword.gd`, `sword.tscn`: меч в правой руке, клинок = 0.65 длины руки; удар — `anim_attack` героя, иначе tween.
- `scripts/spawner.gd`: обвал — высота 6 м, тень-предупреждение растёт 0.8 с, затем падение; ожидающие падения учитываются в `max_alive`.
- `scripts/hazards/rock.gd` (пыль при приземлении), `bomb_hazard.gd` (частицы вместо сферы), `scenes/hazards/bomb.tscn` — пороховая бочка `barrel.glb`.
- `scripts/sfx.gd`: `load_stream(path)` — нет файла = одно предупреждение и тишина. Пути к звукам — экспорты (`res://assets/audio/*.ogg`) в мече, игроке, зелье, бомбе, `main.gd`, спавнере; сгенерированные wav удалены.
- Тексты (константы в начале каждого скрипта): «Dungeon Delver», «Спуститься», «Герои», «Имя героя», «Золото», «Обвал стихнет через N», сообщения решётки, смерти и победы, «Привал».
- `scenes/main_menu.tscn`, `scripts/main_menu.gd`: кнопка «Герои» вместо выбора цвета шара.
- `tools/test_a6.gd`, `tools/test_anim.gd`: восстановлены (автор удалил `tools/` в `5215d53`), test_a6 дополнен проверками героя, ростера и миграции профиля.

## Лабораторная A6 — Scripting I

Созданы:
- `scripts/health.gd` (`class_name Health`): сигналы `changed(current, max_hp)` и `died`, `take_damage` / `heal`. Урон не проходит во время неуязвимости и после смерти, лечение не выше `max_hp`. Корутина `_invincibility()` мигает `blink_target` через `create_timer(blink_interval, false)` (замирает на паузе) и в конце всегда возвращает `visible = true`.
- `scripts/hazards/hazard.gd` (`class_name Hazard`, RigidBody3D): группа `hazard`, contact monitor, CCD (падение с 12 м сквозь пол 0.2 м), Timer на `lifetime`. Касание игрока → виртуальный `_on_hit_player(health)`, первое другое касание → `_on_landed()`, `hit_by_weapon(damage = 1)` по умолчанию удаляет объект.
- `scripts/hazards/rock.gd`, `bomb_hazard.gd`, `potion.gd` + `scenes/hazards/{rock,bomb,potion}.tscn`: камень (урон 1), бомба (фитиль 2 с после приземления, взрыв по радиусу 2.5 м на 2 урона, вспышка, звук, защита от двойного взрыва, удар мечом взрывает сразу), зелье (`heal(1)` + звук).
- `scripts/sfx.gd` (`class_name Sfx`): разовый звук, который доигрывает после `queue_free` источника.
- `scripts/spawner.gd`: Timer с autostart, `RandomNumberGenerator` выбирает сцену и точку в прямоугольнике 18 × 18 м на высоте 12 м, инстанс приводится к `Hazard` (иначе ошибка и `free`), лимит `max_alive` по группе `hazard`.
- `scripts/weapons/sword.gd` + `scenes/weapons/sword.tscn`: модель `weapon-sword.glb` на `top_level`-узле у шара, смотрит по последнему направлению движения; атака по `attack` с кулдауном через `Time.get_ticks_msec()`, взмах Tween'ом, звук, хитбокс.
- `scripts/weapons/slash.gd` (`class_name Slash`) + `scenes/weapons/slash.tscn`: Area3D 1.2 м, живёт 0.15 с, вызывает `hit_by_weapon(damage)` у каждого тела один раз, включая уже стоявшие внутри.
- `scripts/pause_menu.gd` + `scenes/ui/pause_menu.tscn`: CanvasLayer с `PROCESS_MODE_ALWAYS`, затемнение, «Продолжить» / «Рестарт» / «В главное меню»; перед сменой сцены пауза снимается.
- `tools/gen_sfx.py`: swing / hurt / pickup / explosion (numpy + wave) в `assets/Audio/` (существующая папка: путь в нижнем регистре сломался бы вне Windows).
- `tools/gen_heart_icons.py` → `assets/ui_gen/heart_full.png`, `heart_empty.png`: в Rubik нет U+2665, поэтому вместо Label «♥» иконки.
- `tools/test_a6.gd`: headless-проверки Health, иерархии Hazard, лимита спавнера и Slash.

Изменены:
- `scripts/player.gd`: столкновение с `enemy` даёт `take_damage(1)` и импульс от врага вместо мгновенной смерти; звук урона по `Health.changed`; ввод отключается после смерти. `scenes/player.tscn`: дочерние `Health`, `Sword`, `HurtSfx`.
- `scripts/main.gd`: сердца по `Health.changed`; по `Health.died` — «Game over», через 1.5 с снятие паузы и перезагрузка (один раз); таймер выживания 60 с с меткой «Выжить: N», на нуле открывает группу `locked_gate` (в проекте ворота теперь в этой группе); звук подбора монет и ключа.
- `scripts/camera_rig.gd`: пивот следует за игроком (`1 - exp(-follow_speed * delta)`, мёртвая зона 1.5 м), на старте сразу на игроке; поворот на 4 ракурса прежний.
- `scenes/map.tscn`: `HeartsBox`, `SurvivalLabel`, `Spawner`, `PickupSfx`, `PauseMenu`; `GateHint` перенесён перед решёткой после её сдвига автором.
- `project.godot`: действия `attack` (J, ЛКМ) и `pause` (Escape, P).
- `tools/test_anim.gd`: восстановлен (автор удалил его в `c3fa8a5`).

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
