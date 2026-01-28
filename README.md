# Claudev

> v0.8.0 — ready for production

Виртуальный отдел разработки на базе AI. Опишите что хотите — получите готовый продукт.

## Как это работает

1. Вы описываете идею словами
2. AI-команда задаёт уточняющие вопросы
3. Архитектор создаёт план
4. Разработчики пишут код
5. Ревьюер проверяет качество
6. Вы получаете готовый проект

Весь процесс автоматический. Вам нужно только отвечать на вопросы.

## Установка

Один раз на машину:

```bash
curl -fsSL https://raw.githubusercontent.com/Puremag1c/claudev/main/install.sh | bash
```

Установщик:
- Установит claudev в `~/.claudev/`
- Добавит команду `claudev` в PATH
- Установит зависимости (beads, gh, jq, Claude Code)

## Использование

В любом проекте:

```bash
cd your-project
claudev init
```

Команда `claudev init`:
1. Инициализирует git и beads
2. Создаёт конфигурацию `.claudev/config.sh`
3. Настраивает симлинки для агентов
4. Запускает orchestrator

## Команды

```bash
claudev init      # Инициализация проекта + запуск
claudev start     # Запуск orchestrator
claudev status    # Статус проекта
claudev update    # Обновление claudev
claudev delete    # Удалить claudev из проекта (сохраняет код и .beads)
```

## Требования

- macOS, Linux или Windows (через WSL)
- Всё остальное установится автоматически

### Windows

На Windows нужен WSL. Откройте PowerShell как администратор:

```powershell
wsl --install
```

После перезагрузки откройте Ubuntu из меню Пуск и запустите команду установки.

## Полезные команды beads

```bash
bd ready          # Посмотреть готовые задачи
bd list           # Все задачи проекта
bd stats          # Статистика
```

## Вопросы?

Создайте issue в этом репозитории.
