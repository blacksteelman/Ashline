# ASHLINE 0.4 — состояние для следующей сессии

Дата: 8 октября 2026. Продолжать существующий проект `/workspace/ashline`. Пользователь просит автономную разработку настоящего native PC FPS и доведение текущего TDM до высокого качества. Не начинать заново и не расширять количество карт/режимов до полировки текущих систем. Файлы действительно изменены; билд запускается. Целевой уровень коммерческой современной FPS пока не достигнут.


## Текущий этап 0.4 — прочитать первым

Новая цель пользователя: убедительность изображения COD4 (2007) на высоких настройках, оригинальные материалы. Пользователь отверг качество 0.3; 0.4 тоже НЕ объявлять достигшим этого ориентира. Продолжать арт, стрельбу и реальные игровые проверки; не расширять контент.

- `assets/sculpt_mesh.py`: оригинальные профили оружия, криволинейный магазин, cross-section meshes тела/рукавов/перчаток. Два deforming skeleton кистей, пальцы имеют цепочки костей; reload contact импортируется в AnimationPlayer. Это НЕ полноценный скелет/набор locomotion clips всего солдата: ноги всё ещё анимируются отдельными узлами LegL/KneeL.
- `assets/model.py`: подключает sculpt pass. Объединяет skinned mesh только при одинаковых материале, родителе и armature; сохраняет bone weights. Не присоединять меши разных skeleton. `assets/masonry_pass.py` после surface_pass: новая кладка и менее пятнистый асфальт. `assets/rebuild.py` воспроизводит всё локально.
- `viewmodel.gd`: forearm aim/stretch до позиции запястья, скелетный контакт руки при reload; AR в ADS расположен чуть дальше от камеры. `fighter.gd` немедленно убирает старый gun из дерева перед queue_free: иначе на кадрах смены наслаиваются модели.
- `arena.gd`/`district_detail.gd`: реальные окна 2.7×1.7м на боковых фасадах, разделение коллизии на низ/верх/простенки; новые рамы/откосы и полупрозрачные panes. `Art.box`/`Arena.block` имеют damaged flag. Большинство торцевых стен теперь целые, повреждения локализованы. `Ruins.fragment` заменяет идеально кубические обломки.
- `game.gd`: вращает process_physics_priority для последовательности бойцов (local player первым ради ввода). Это устраняет постоянную привилегию команды при same-tick shots, но НЕ полноценная двухфазная симуляция и НЕ доказательство баланса. FX получают минимум один кадр показа, затем обычное время жизни.
- `effects.py`: исправлена маска дыма: clamp(1-r) перед квадратом, иначе углы вне радиуса вновь становятся непрозрачными. Smoke/muzzle Sprite3D и CPUParticles не отбрасывают тени; фоновый шлейф затухает через Gradient.
- На native-combat обнаружены крупные тёмные фрагменты перед камерой. Диагностический проход с отключением FX показал: это кубические particles flesh hit рядом с защищённым showcase игроком. Теперь flesh выдаёт мягкий fabric dust только вне .45м от камеры; бетонные сколы имеют Ruins.fragment вместо BoxMesh. Показ короткой вспышки сохранён.
- Интерфейс только обновлён до ALPHA 0.4; глубокой новой художественной переработки меню/HUD в этом проходе не было.

Бот-прогоны: до вращения порядка seed404: 40:16, 40:28, 40:26. После: seed404: 40:19, 16:40, 34:40; seed405: 35:40, 40:35, 36:40. После изменения оба seed завершили все раунды с нулём recovery events, но ранние смерти ещё есть. Не называть карту сбалансированной по шести матчам. Проверить порядок при нескольких human clients и расширить карту heatmap анализом.

Проверки: functional (49), regression_v3 (14), regression_art_v4 (10), playthrough и stairs; результаты см. `tests/verification_v4.json`. Перед итоговыми архивами запускались экспортированные Linux Vulkan/OpenGL, network swarm и performance; точные факты/ограничения смотреть в отчёте.

Кадры: `build/before-v4/` — исходная версия 0.3, `build/screenshots-v4/` — новые реальные кадры. Контролируемые состояния останавливают бойцов и защищают игрока; native-combat получен из экспортированного бинарника. Сохранять изображения без ретуши. Вспышка/гильза/hit marker видны в firing.png. Не перепутать старые временные кадры с последними.

Пользователь разрешил доступные внешние модели/ассеты/звуки. Подключены CC0 ambientCG Bricks097, Asphalt023S, Concrete034, Plaster007, Metal055A (albedo/normalGL/roughness/AO), а также восемь одиночных записей Free Firearm Sound Library. Первичный источник и лицензии проверены; файлы получены через публичное GitHub-зеркало petroulacl/fps-asset-kit, commit указан в assets/thirdparty/SOURCES.json. В .runtime/fps-asset-kit находится скачанная коллекция; её код/проект НЕ использовались. Большинство других моделей коллекции стилизованы и не подходят цели. Загруженный старый CC0 soldier erik90mx не включён: нет готовых текстур, сложный старый риг. Лицензированные входы включены в assets/thirdparty, rebuild.py завершает генерацию apply_licensed.py без сети. prepare_firearm_audio.py — дополнительный рецепт обработки оригинальных WAV; нормальная пересборка не требует исходной многогигабайтной библиотеки. В SMG используются G_31P/G_20P одиночные выстрелы, НЕ очереди G_22P/G_33P. Звуковой выход Dummy: субъективное прослушивание не подтверждено.

Финальный software benchmark: Forward+ 1280×720, Balanced/MSAA2, llvmpipe LLVM19, 30 кадров; median 1220.856 ms, p95 1300.010 ms, draw calls 1343, nodes 1413. Это НЕ результат игрового GPU и НЕ обещание FPS.

Следующее: полноценный бипедный rig и authored анимации тела; более убедительная анатомия головы/экипировки и ткани; детальная модель оружия с UV/локальным износом; художественно разные интерьеры и архитектура; реальная проверка gunfeel со звуком и производительности на GPU. Нынешние руки заметно лучше связаны, но силуэты и материалы остаются слишком простыми для COD4.

GitHub: main + tag v0.4.0-alpha; архивы в отдельной builds/v0.4.0-alpha. Репозиторий приватный, скачивать ZIP через Download raw file. Прямой uploads.github.com вернул 401 в прошлом проходе, поэтому не обещать Release assets без успешной загрузки.

## Сохранённое состояние 0.3 (история)

Исходная 0.2 зафиксирована в локальном Git коммитом `75c4c35`. После проверки 0.3 изменения сохранены отдельным коммитом/тегом; актуальные идентификаторы смотреть `git log -2 --oneline`. Родительский `/workspace/.git` не использовать: самостоятельный репозиторий расположен внутри проекта. Build, `.godot` и `.runtime` исключены из Git.

Готовые архивы: `build/ASHLINE-0.3-Windows-x64.zip`, `build/ASHLINE-0.3-Linux-x64.zip`, `build/ASHLINE-0.3-Source.zip`, `build/ASHLINE-0.3-Screenshots.zip`. Бинарники с embedded PCK: `build/linux/ASHLINE.x86_64`, `build/windows/ASHLINE.exe`. Windows только экспортирован; в данной среде не запускался.

`tests/verification_v3.json` — итоговые результаты проверок. `build/screenshots-v3/` — реальные кадры Godot; `native-combat.png` снят из экспортированного Linux-билда. Другие кадры получены тестом визуальных состояний, который останавливает бойцов для воспроизводимости и защищает локального игрока от урона. Это не обработанные изображения и не концепт-арт.

## Что изменено

- `fighter.gd`, `viewmodel.gd`: представление на render rate; физика 60 Hz; screen_relative mouse; частичный возврат camera recoil с учётом ручной компенсации; независимая от FPS пружина; fractional fire cadence; стрельба прерывает sprint; улучшены ADS/просвет мушки, reload и длина рукавов. MR-62 использует поле оптики с тонкой сеткой, оружие скрывается при завершённом входе в прицел.
- `model.py`: материал оружия темнее и менее зеркальный, дополнительные фаски/крепежи/selector/slide, отдельные пропорции P-12; rigid-меши объединены по материалу и родителю с сохранением Leg/Knee/MagazineRig/LeftHand/LeftSleeve/Bolt. Всё воспроизводится локально без внешних моделей.
- `surface_pass.py`: оригинальные 1024px albedo/normal/roughness с износом. `district_detail.gd`: фасадные детали, рамы, грязь у стен, контейнерные двери/крепления, кабели, стоки. `arena.gd`/`art.gd`: уменьшенные, освещаемые промышленные указатели и табличка на турбине.
- Forward+ по умолчанию; Balanced — SSAO, MSAA; Quality — SSIL/SSR; Performance отключает эти эффекты. OpenGL fallback через launcher/CLI. Нет baked GI или SDFGI. Нет аппаратного GPU в среде: всё визуально осмотрено через llvmpipe.
- `static_batch.gd`: объединение непрозрачной статической геометрии по материалу/16м участку. Не объединять прозрачные поверхности и анимационные детали. Исправлена потеря unindexed-стен при смешивании с indexed BoxMesh: индексировать исходную поверхность перед append. `Ruins.wall` генерирует tangents. У concave-collision повреждённых стен включён `backface_collision=true`: без него боты застревали у дверей. Радиус достижения waypoint увеличен до .48.
- `frontend.gd`: главное меню, три карточки класса с реальными 3D-preview, LAN экран. UI масштабируется от 1600×900. HUD компактнее, scoreboard работает после смерти, draw отображается при ничьей. Settings сохраняют graphics/VSync вместе с прежними параметрами.
- `audio_mix.gd`: отдельные buses, Master hard limiter, краткая indoor reverb; dryfire и body impact. Реальный аудиовыход не прослушан: запускался Dummy audio.
- `game.gd`/`fighter.gd`: sequence/ack сетевых выстрелов, корректный ammo при старых snapshots, ограниченная очередь, reload после последнего pending shot, aim перед recoil передаётся в запросе. Сетевые wall impacts предсказываются у стрелка и реплицируются другим клиентам; head marker подтверждается сервером. Remote pose сглаживается; jump срабатывает по фронту. Обработчики сети подключаются один раз. Dedicated даёт все 12 мест, host — 11 плюс local. Remote human collision_mask=1|2, bot mask=1. Смена стороны spawn доступна после первых 6 секунд при давлении врага; spawn facing зависит от фактической стороны. Headless/dedicated не создаёт лишние визуальные эффекты.

## Среда и команды

Godot 4.6.3: `/usr/local/bin/godot`. Blender 4.3.2, Python с Pillow/NumPy. Все команды ниже из `/workspace/ashline`.

```sh
export XDG_DATA_HOME=/workspace/ashline/.runtime/data
export XDG_CONFIG_HOME=/workspace/ashline/.runtime/config
export XDG_CACHE_HOME=/workspace/ashline/.runtime/cache
godot --headless --path . --editor --import --quit
godot --path . --editor
python3 assets/rebuild.py
godot --headless --path . --export-release 'Linux PC'
godot --headless --path . --export-release 'Windows PC'
```

Release export templates находятся в `.runtime/data/godot/export_templates/4.6.3.stable`. Они исключены из source archive; при работе на новой машине установить шаблоны этой версии отдельно. Blender запускать с `--python-exit-code 1`: без этого ошибка Python может завершиться с кодом 0.

Рендер в этой среде: Xorg dummy, конфиг `tests/xorg.conf`. В текущей сессии использован `:101`; процессы между сессиями могут исчезнуть. Проверить `pgrep -a Xorg`; при необходимости запустить свободный номер дисплея:

```sh
Xorg :102 -noreset -nolisten tcp -config /workspace/ashline/tests/xorg.conf -logfile /workspace/ashline/tests/xorg_next.log
DISPLAY=:102 VK_DRIVER_FILES=/workspace/ashline/.runtime/vulkan/lvp.json godot --audio-driver Dummy --path .
```

Mesa lavapipe локально извлечён в `.runtime/vulkan/root`, JSON `.runtime/vulkan/lvp.json` указывает абсолютный путь к `libvulkan_lvp.so`. Это служебный драйвер среды; не включать его в пользовательские билды. Для OpenGL достаточно DISPLAY и `--rendering-method gl_compatibility`. Не запускать два графических клиента с захватом мыши одновременно на одном DISPLAY: возникает `NO GRAB`.

Готовый Linux: `./build/linux/ASHLINE.x86_64`; dedicated: `./build/linux/ASHLINE.x86_64 --headless -- --server`. Release может буферизовать stdout: пустой лог сервера не доказывает отказ старта. `tests/network_swarm.py` проверяет привязку UDP-порта вместо ожидания строки в логе. При изменении RPC перезапускать ВСЕ серверы/клиенты, иначе несовпадение таблицы RPC выглядит как случайные ошибки методов.

## Проверки текущей версии

- `tests/functional.gd`: 49 проверок обычных игровых систем.
- `tests/regression_v3.gd`: 14 проверок, в том числе сохранность треугольников, spring 30/144 FPS, 22 AR shots/2sec, sprint→fire, низкий потолок, delayed/partial/full shot ACK и head marker.
- `tests/playthrough.gd`: Play→class→kill→death→respawn→3/5/7→end→next→settings→resume. GUI получает события мыши через `root.push_input(event,true)`; `position` и `global_position` задаются вместе. Полный обычный бой проверяется отдельно ботами, здесь расположение целей контролируемое.
- `tests/stairs.gd`: персонаж реально поднимается на deck (y≈2.2502).
- `--bot-test --seed=303/304/305 --matches=3`: полные TDM. До исправления wall backface seed305 содержал 23 recovery events, после — 4 за три матча; в последнем раунде все актёры имели 0 recoveries. По последнему прогону ещё есть ранние смерти и перекос побед Aegis — это открытая проблема.
- `tests/network_swarm.py`: экспортированный сервер и 12 отдельных экспортированных headless-клиентов, уникальные slots0..11, по 120 snapshots, выстрелы/ACK, без pending predictions в конце. Это локальный автоматический прогон, не испытание публичного сервера с настоящими пользователями/интернетом.
- `tests/visual_capture.gd`: меню, classes, hip/ADS/reload/scope/pistol, scoreboard alive/dead, opponent, overview. Самостоятельно смотреть изображения, не только успешный exit code.
- `tests/performance.gd`: сравнение draw calls при OpenGL (7959→1527) и nodes (4132→1177) в контрольной сцене. Материалы/свет тоже изменились; software frame time не улучшился и это НЕ GPU benchmark. Не заявлять подтверждённый рост FPS.

## Следующие приоритеты

1. Первый проход — запустить свежий билд и посмотреть `native-combat.png`, reload, opponent и overview. Оружие/руки/окружение всё ещё грубые; убрать впечатление процедурных кубов и примитивных рукавов. Нужен настоящий first-person rig с корректными суставами/контактами рук, затем authored reload/fire/equip/landing clips. Не усиливать camera shake и head bob.
2. Доработать текущее окружение: фасады с настоящими проёмами/разрушениями, материалы/модульная геометрия, нормальные интерьеры, контактное и непрямое освещение. Не добавлять ещё карты.
3. Разобраться с Aegis bias: собрать результаты по нескольким seed, каждой стороне/классу/первой встрече; проверить порядок обработки бойцов, маршруты, линию прострела spawn. Не объявлять карту сбалансированной на основании завершения матчей. Улучшать выбор безопасного spawn и исключать повторные ранние смерти.
4. Проверить gunfeel руками на GPU и реальном аудиовыходе; данные cadence/recoil проходят, но субъективное ощущение нельзя подтвердить текущим CPU-render/Dummy audio. Windows нужно реально запустить. Оценить FPS/frame pacing на игровом GPU; только затем назначать hardware requirements.
5. Дальше сетевые delayed/loss tests, переключение/reload/class/death/round transitions с несколькими клиентами и точная interpolation/prediction. Сейчас нет lag compensation или production security. Существующие 12-slot tests не заменяют это.
6. Бounded pool для smoke/impacts/shell/audio и дальнейшее уменьшение draw calls после художественной детализации. Не ломать прозрачность/анимацию при объединении мешей.

Не заявлять готовый vertical slice или графику уровня MW2019. Пользователь просит результат, поэтому продолжать изменения файлов, build→run→test→inspect→fix, а не только писать планы. Обновления по-русски примерно раз в минуту при длительной работе. В конце сохранять новый проверенный билд, коммит и этот файл.

## Передача через GitHub — 2026-10-08

Origin: https://github.com/blacksteelman/Ashline.git (приватный). Исходники загружены в main, версия игры отмечена v0.3.0-alpha. Проверенные бинарные архивы переданы отдельной веткой builds/v0.3.0-alpha, SHA-256 рядом с ними. Открыть ZIP на GitHub → Download raw file; нужен авторизованный аккаунт с доступом.

Прямая загрузка Release assets через uploads.github.com вернула HTTP 401 при работающих Git push и API. Не повторять локальные sandbox-ссылки как готовую доставку: пользователь не смог их скачать. Не менять приватность репозитория.
