# Расписание ФА

Flutter-приложение для просмотра расписания Финансового университета через API `ruz.fa.ru`.

## Возможности

- поиск учебных групп и преподавателей через `/api/search`;
- открытие расписания выбранной группы или преподавателя через `/api/schedule`;
- просмотр расписания на неделю;
- переключение недель вперед и назад;
- выбор недели через календарь;
- режимы отображения `Список` и `Таблица`;
- группировка занятий по дням;
- обработка пустого расписания и сетевых ошибок.

## Технологии

- Flutter / Dart;
- `dio` для HTTP-запросов;
- `go_router` для навигации;
- `intl` и `flutter_localizations` для русской локализации дат;
- локальный пакет `packages/time_scheduler_table` для табличного вида расписания.

## Требования

- Flutter SDK 3.x;
- Dart SDK 3.x;
- Android Studio, VS Code или другая IDE с поддержкой Flutter;
- доступ к интернету для запросов к `https://ruz.fa.ru/api`.

Проверенная среда разработки:

```text
Flutter 3.38.6
Dart 3.10.7
Windows
```

## Запуск

Склонировать репозиторий:

```bash
git clone https://github.com/feuerstrahll/UniSchedule.git
cd UniSchedule
```

Установить зависимости:

```bash
flutter pub get
```

Запустить приложение:

```bash
flutter run
```

Для Windows:

```bash
flutter run -d windows
```

Для Android:

```bash
flutter run -d android
```

## Сборка

Windows:

```bash
flutter build windows
```

Android APK:

```bash
flutter build apk
```

## Проверка проекта

```bash
dart format lib test
flutter analyze
flutter test
```

## Примечание по API

API `ruz.fa.ru` может вернуть пустой список, если у выбранной группы или преподавателя нет занятий на выбранной неделе. В этом случае приложение показывает пустое состояние и предлагает выбрать другую дату или найти ближайшую неделю с занятиями.

Если запускать приложение в браузере и возникнут CORS-проблемы, можно использовать локальный proxy и запускать Flutter с флагом:

```bash
flutter run -d chrome --dart-define=USE_PROXY=true
```

Основной целевой сценарий проекта — запуск как desktop/mobile Flutter-приложения.
