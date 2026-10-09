# ASHLINE 0.7 — состояние для следующей сессии

Дата: 9 октября 2026. Продолжать существующий проект; цель пользователя — быстрый, качественный native PC military FPS. Визуальный ориентир COD4 пока не достигнут. Не расширять количество режимов, карт и оружия вместо улучшения исполнения. Пользователь разрешил использовать внешние ассеты; выбирать ресурсы с подтверждённой лицензией и сохранять источник/авторство.

## Выполненный проход

- `assets/weapon_art_pass.py`: AR-41 заменён адаптированной CC0-моделью M4A1 от nisu/3DModelsCC0, с исходными 2K PBR-картами. Магазин и bolt carrier остаются отдельными узлами для существующей перезарядки/механического цикла. Это лицензированная модель, не утверждать, что вся её геометрия создана с нуля.
- Кисти и пальцы — CC0 FPS Arms para/MakeHuman; источник не содержит используемой в игре новой перезарядки. Старые constraints/actions удаляются. Собственные skinned рукава, заново поставленные руки, пальцы и SupportHand_reload_contact (61 кадр, 2с). `glove_pass.py` выводит тёмную фактуру перчаток из исходной UV-карты.
- Исправлен важный дефект: после сброса pose matrix_basis нужно обновлять depsgraph **до** IK. Иначе левое предплечье получало ошибочную трансляцию около двух метров на первом кадре. Конвертер проверяет wrist/forearm contact во всех 61 позах и после записи action. Кривые записываются отдельно после вычисления поз; quaternion hemisphere сохраняется.
- Исходные предплечья удалены по пространственной плоскости запястья, а не только по весам: некоторые исходные вершины не имели весов и оставались неподвижными треугольниками. Кисти остаются деформируемыми; собственные рукава используют тот же скелет.
- `Art.weapon`: новые muzzle/ejector/ADS metadata; first-person extra_cull_margin=.8 предотвращает исчезновение рук при стрельбе от бедра. World weapon скрывает все ViewmodelArms/OperatorForearm/OperatorUpperArm части. Гильза использует transform окна выброса.
- `district_art_pass.py`: шесть выбранных моделей из CC0 Industrial Asset Pack rubberduck/a52 экспортируются общей библиотекой `district_props.glb`, с общими PBR-ресурсами. `workshop_art.gd` размещает их в западном сервисном цеху и добавляет потолок, trusses, светильники, кабинеты и мелкие детали. Главная планировка не копировалась и не заменялась чужой картой.
- Размеры физических укрытий соответствуют размещённому оборудованию и внесены в obstacle projection. Центральный маршрут цеха остаётся открыт. Дымовые башни расположены за игровой зоной.
- Новые color/normal текстуры импортируются с high-quality VRAM compression; packed masks — стандартное block compression. Фоновые кирпич/бетон/проволока/доски/оранжевый металл ограничены 512px (проволока/доски/оранжевые колпаки — 256px); близкое оборудование сохраняет 1024px, винтовка — 2K. Ненужные текстуры прежнего weapon_0 удалены. Проверять настоящий Vulkan/OpenGL вывод после изменений импорта; компиляция не подтверждает внешний вид.
- `tests/art_v7.gd` проверяет реальные skin matrices/weights/позиции вершин, сохранившиеся PBR normal maps, authored reload, world-arm hiding, culling margin, физическое укрытие и маршрут цеха. Старый regression_art_v4 теперь проверяет прежний независимый механизм рук на SMG, а functional проверяет реальную кисть нового скелета AR.

## Проверки и границы результата

Читать `tests/verification_v7.json`: это отчёт этой версии, не переносить результаты прошлой версии как новые. `tests/art_v7_report.json`, `tests/native_network_v7_report.json`, `tests/bot_report_707.json`, `tests/bot_report_708.json` и `tests/performance_v7_report.json` содержат данные отдельных прогонов. Логи и реальные PNG включаются в Screenshots ZIP.

Полный игровой цикл и существующие механики остаются в functional/regression/playthrough/stairs тестах. Bot-vs-bot — настоящая физика и боевая логика, три матча на seed707 и ещё три на seed708. Swarm — экспортированный dedicated server плюс 12 отдельных экспортированных клиентов; проверяются уникальные slots0..11, 120 snapshots, выстрелы и ACK без pending.

В этой среде графика запускается на software llvmpipe/lavapipe. Реальные кадры можно смотреть; отзывчивость на игровом GPU, стабильные 60–144 FPS и субъективный gunfeel здесь не подтверждены. Аудиовыход Dummy: записи подключены, но настоящее прослушивание не проверено. Windows экспортируется, но запуск Windows здесь не проверен. Карта, остальные виды оружия и тела бойцов ещё ниже цели пользователя. Не называть это завершённой коммерческой игрой или достигнутым качеством COD4.

## Запуск и пересоздание

Godot 4.6.3, Python/Pillow/NumPy, Blender 4.3.2. Из корня проекта:

```sh
godot --headless --editor --path . --import
godot --path .
python3 assets/rebuild.py
```

Для обычного запуска достаточно включённых GLB. Для полного rebuild нужны `assets/thirdparty/viewmodel` и `assets/thirdparty/industrial/industrial_selected.blend`: они находятся в GitHub main. В ZIP-доставке они вынесены в `ASHLINE-0.7-Asset-Sources.zip`; распаковать его вместе с Source ZIP в одну директорию ASHLINE. Источники, лицензии, первичные ссылки и хэши — `assets/thirdparty/SOURCES.json`, credits — `LICENSES.md`. Не удалять `assets/thirdparty/.gdignore`: Godot не должен автоматически импортировать входные FBX/Blender/архивы.

Порядок rebuild: генераторы текстур/аудио → model.py → environment.py → weapon_art_pass.py → district_art_pass.py. Последний оружейный проход перезаписывает только weapon_0. Затем обязательно Godot import. Импорт VRAM-текстур может занять несколько минут. Не запускать визуальный тест до его завершения, иначе можно посмотреть старый cached scene.

```sh
godot --headless --path . --script tests/functional.gd
godot --headless --path . --script tests/regression_v3.gd
godot --headless --path . --script tests/regression_art_v4.gd
godot --headless --path . --script tests/character_v5.gd
godot --headless --path . --script tests/regression_v6.gd
godot --headless --path . --script tests/art_v7.gd
godot --headless --path . --script tests/playthrough.gd
godot --headless --path . --script tests/stairs.gd
godot --headless --path . -- --bot-test --seed=707 --matches=3
```

Визуальные состояния: `tests/visual_capture_v7.gd`, performance: `tests/performance_v7.gd`. Снимки не подрисовываются. Контролируемый capture замораживает бойцов и защищает игрока; его нельзя описывать как случайный полный матч.

```sh
godot --headless --path . --export-release 'Linux PC'
godot --headless --path . --export-release 'Windows PC'
python3 tests/network_swarm_v7.py
python3 tools/package_release.py
python3 tools/publish_builds.py
python3 tools/verify_downloads.py
```

Экспорт требует Godot templates. В текущем облаке они лежат в `.runtime/data/godot/export_templates/4.6.3.stable`; для их использования задать XDG_DATA_HOME=/workspace/ashline/.runtime/data. Xorg :104 и Vulkan ICD в `.runtime/vulkan/lvp.json` — временное окружение; в новой сессии проверить их существование, не предполагать, что display остался жив.

## Сохранение и доставка

Source сохраняется на main и теге v0.7.0-alpha; точный commit указан в RELEASE.json каждого архива. Готовые файлы доставляются через ветку `builds/v0.7.0-alpha`, а не ссылку на недоступный разговорный артефакт. ZIP-файлы должны быть меньше 100MiB каждый. Source ZIP содержит runtime GLB, Asset-Sources ZIP — дополнительные исходные vendor-ресурсы. `tools/verify_downloads.py` реально скачивает каждый ZIP из GitHub, сверяет размер/SHA-256/целостность и добавляет доказательство в build branch. Никогда не печатать короткоживущие приватные download URLs из gh API.

Для приватного репозитория пользователю требуется вход в GitHub. Открыть ZIP → Download raw file. Не утверждать, что reverse download проверен, пока скрипт не завершился для всех пяти архивов.

## Следующая работа

1. В первую очередь — убедительная модель бойца с материалами и одеждой; нынешний оригинальный biped всё ещё грубый. Найти и проверить подходящий лицензированный источник, адаптировать к существующим hit zones и locomotion, проверить реальные кадры в движении.
2. Продолжить художественный проход этого же цеха: разрушения, стыки конструкций, разнообразие поверхностей и читаемость. Не переносить добавленные props автоматически на всю карту без проверки проходов/коллизий.
3. Довести рукава/перчатки и другие оружейные модели до сопоставимого уровня. Сохранять правильное соединение запястий, скелетную деформацию, прицелы и существующую отзывчивую боевую логику. Проверять ADS/reload/sprint/landing в настоящей игре.
4. По возможности испытать на аппаратном GPU и реальном аудиовыходе. До этого не обещать gunfeel/производительность, подтверждённые живой игрой.

Не добавлять новые режимы/карты до улучшения текущего TDM. После существенных изменений: build → run → test → inspect → fix → retest. Сохранять понятные commit и handoff. Не останавливаться на успешной компиляции.
