# 🪐 Omarchy Dock — Главная карта проекта (MOC)

> **Omarchy Dock** — нативный анимированный док-бар приложений для среды **Omarchy Quattro (Wayland / Hyprland / Quickshell)** с поддержкой динамического позиционирования, группировки в папки (macOS Stacks), отслеживания запущенных окон, Drag & Drop и глубокой интеграции с темами Omarchy.

---

## 🗺️ Граф компонентов и связей

```mermaid
graph TD
    subgraph Core ["Входные точки & Манифест"]
        M["[[01 - Архитектура и Структура файлов|manifest.json]]"]
        M --> DP["[[01 - Архитектура и Структура файлов|DockPanel.qml (Главная панель)]]"]
        M --> BW["[[01 - Архитектура и Структура файлов|BarWidget.qml (Виджет бара)]]"]
    end

    subgraph Windows ["Окна Wayland Layer-Shell"]
        DP --> DW["[[02 - Окна и Wayland Layer-Shell|dockWindow (Основной док)]]"]
        DP --> SW["[[02 - Окна и Wayland Layer-Shell|stackWindow (Папка Stacks)]]"]
        DP --> MW["[[02 - Окна и Wayland Layer-Shell|menuWindow (Выбор значков)]]"]
    end

    subgraph Logic ["Данные и Логика"]
        DP --> DM["[[03 - Модель данных и Персистентность|DockModel.js (Движок данных)]]"]
        DP --> DI["[[01 - Архитектура и Структура файлов|DockItem.qml (Слот иконки)]]"]
        DI --> OG["[[06 - Индикаторы запуска и Оптическое центрирование|OpticalGlyph.qml]]"]
        DI --> RD["[[06 - Индикаторы запуска и Оптическое центрирование|runningDot (Индикатор)]]"]
    end

    subgraph Features ["Ключевые подсистемы"]
        DP -.-> EM["[[04 - Режим редактирования и Анимации|Режим редактирования (Wiggle)]]"]
        DP -.-> ST["[[05 - Папки|Папки Stacks & Редактирование названий]]"]
        DP -.-> AH["[[07 - Автоскрытие и Взаимодействие с Hyprland|Автоскрытие & Окна Hyprland]]"]
        BW -.-> SET["[[03 - Модель данных и Персистентность|Настройки (~/.config/omarchy/)]]"]
    end

    classDef core fill:#2d3748,stroke:#4a5568,stroke-width:2px,color:#fff;
    classDef win fill:#1a365d,stroke:#2b6cb0,stroke-width:2px,color:#fff;
    classDef logic fill:#234e52,stroke:#319795,stroke-width:2px,color:#fff;
    classDef feat fill:#44337a,stroke:#805ad5,stroke-width:2px,color:#fff;

    class M,DP,BW core;
    class DW,SW,MW win;
    class DM,DI,OG,RD logic;
    class EM,ST,AH,SET feat;
```

---

## 📚 Разделы базы знаний

1. 📂 **[[01 - Архитектура и Структура файлов]]** — описание каждого файла в проекте, назначение и взаимосвязи.
2. 🪟 **[[02 - Окна и Wayland Layer-Shell]]** — архитектура 3 окон (`dockWindow`, `stackWindow`, `menuWindow`), слои, анкоры и центрирование.
3. 💾 **[[03 - Модель данных и Персистентность]]** — структура JSON-конфигов, функции `DockModel.js`, сохранение состояния.
4. 📳 **[[04 - Режим редактирования и Анимации]]** — покачивание (wiggle), бейджи `★` и `-`, Long Press, скрытие курсора при drag & drop.
5. 📁 **[[05 - Папки]]** — создание папок слиянием, динамическое растяжение заголовков (118–260px), меню значков и навигация стрелками.
6. 🎯 **[[06 - Индикаторы запуска и Оптическое центрирование]]** — полоски `runningDot`, синхронизация с `dragOffset`, идеальное центрирование `OpticalGlyph`.
7. ⚡ **[[07 - Автоскрытие и Взаимодействие с Hyprland]]** — автоскрытие (таймер 1.5s), фокус и переключение окон через `Quickshell.Hyprland`.

---

## ⚙️ Файлы конфигурации

- `~/.config/omarchy/dock-settings.json` — `dockEnabled`, `autohide`, `showFolderTitles`
- `~/.config/omarchy/dock-pinned.json` — сохранённый список закреплённых приложений и папок
- Проект: `/home/rosakodu/Projects/Dock`
- Плагин в системе: `~/.config/omarchy/plugins/rosakodu.dock`
