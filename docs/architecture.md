# AI Development System

Автономная мульти-агентная система разработки с памятью в Beads.

## Ключевые особенности

- **Менеджер с памятью** — состояние хранится в Beads, не теряется между вызовами
- **Автономная работа** — orchestrator пинает менеджера в цикле до завершения
- **Параллельные агенты** — помощники и кодеры работают одновременно
- **Атомарный захват задач** — кодеры не дублируют работу

## Быстрый старт

```bash
# 1. Установи зависимости
npm install -g @anthropic-ai/claude-code
brew install jq
# + beads

# 2. Скопируй в проект
cp -r ai-dev-system/{.claude,scripts,CLAUDE.md} my-project/
cd my-project
bd init --quiet
chmod +x scripts/*.sh

# 3. Опиши ТЗ
vim SPEC.md

# 4. Инициализируй и запусти
./scripts/init-manager.sh
./scripts/orchestrator.sh
```

## Как это работает

```
┌─────────────────────────────────────────┐
│         orchestrator.sh                  │
│                                          │
│   while true:                            │
│       claude manager "Продолжи работу"   │
│       if PROJECT_COMPLETE: exit          │
│       sleep 10                           │
│                                          │
└─────────────────┬────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│         Manager (Claude)                 │
│                                          │
│   1. bd show MANAGER → читает состояние  │
│   2. Анализирует задачи                  │
│   3. Принимает решение                   │
│   4. Выполняет действие                  │
│   5. bd update MANAGER → сохраняет       │
│                                          │
└─────────────────┬────────────────────────┘
                  │
      ┌───────────┼───────────┐
      ▼           ▼           ▼
  Architect    Helpers     Coders
   (Opus)    (Sonnet×4)   (dynamic)
```

## Состояние менеджера в Beads

```json
{
  "phase": "IMPLEMENTATION",
  "cycle": 15,
  "helper_cycles": 2,
  "last_action": "run-coders",
  "last_decision": "8 задач open, запустил 2 кодеров",
  "blockers_seen": ["bd-f3a1"],
  "decisions": [
    {"cycle": 1, "action": "run-architect", "reason": "INIT"},
    {"cycle": 5, "action": "run-helpers", "reason": "План создан"},
    {"cycle": 10, "action": "run-coders", "reason": "План готов"},
    ...
  ]
}
```

## Интеграция с существующим проектом

```bash
# Если задачи уже в Beads:

# 1. Добавь модели
./scripts/add-models.sh sonnet

# 2. Пропусти планирование
./scripts/set-milestones.sh planning-done helpers-done plan-reviewed

# 3. Инициализируй менеджера в нужной фазе
./scripts/init-manager.sh --phase IMPLEMENTATION --helper-cycles 2

# 4. Запусти
./scripts/orchestrator.sh
```

## Скрипты

| Скрипт | Описание |
|--------|----------|
| `orchestrator.sh` | Главный цикл — пинает менеджера |
| `init-manager.sh` | Инициализация состояния менеджера |
| `run-helpers.sh` | Параллельный запуск помощников |
| `run-coders.sh` | Параллельный запуск кодеров |
| `claim-task.sh` | Атомарный захват задачи |
| `detect-phase.sh` | Определение фазы (legacy) |
| `add-models.sh` | Добавить model: labels |
| `set-milestones.sh` | Проставить milestones |
| `notify.sh` | macOS уведомления |

## Переменные окружения

```bash
MAX_CYCLES=100      # Лимит итераций orchestrator
PAUSE_SECONDS=10    # Пауза между вызовами менеджера
```

## Отладка

```bash
# Логи orchestrator
tail -f logs/orchestrator.log

# Логи конкретного цикла менеджера
cat logs/manager-15.log

# Состояние менеджера
bd list --json | jq '.[] | select(.labels | index("role:manager")) | .description | fromjson'

# Сбросить и начать заново
./scripts/init-manager.sh --reset
```

---

## Исследование: Multi-Agent Patterns (январь 2026)

### Anthropic Research System

**Источник:** [How we built our multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system)

**Архитектура:**
- Orchestrator-worker pattern
- Lead agent (Opus) координирует subagents (Sonnet)
- Subagents работают **синхронно** — lead ждёт их завершения
- 90.2% улучшение vs single-agent (но 15x больше токенов)

**State persistence:**
- Сохраняют план во "внешнюю память" перед лимитами контекста
- Resume "from where the agent was when the errors occurred"
- Retry logic + checkpoints для восстановления

**Ключевое:** каждый subagent получает objective, output format, guidance on tools, clear task boundaries.

### Claude Code Subagents

**Источник:** [Create custom subagents](https://code.claude.com/docs/en/sub-agents)

**Как работают:**
- Каждый subagent = **изолированный контекст** (не наследует историю родителя)
- Можно resume по agent ID — transcripts хранятся в файлах
- Background subagents возможны (не блокируют main conversation)
- **Ограничение:** subagents не могут создавать subagents (нет вложенности)

**Создание:**
```yaml
---
name: tech-writer
description: Собирает требования от заказчика
tools: Read, Write, Bash
model: opus
permissionMode: default
---

Ты Tech Writer. Твоя задача — собрать требования...
```

**Storage locations (по приоритету):**
1. `--agents` CLI flag (session only)
2. `.claude/agents/` (project)
3. `~/.claude/agents/` (user-level)

### Выбранная архитектура для Claudev (v2)

**Принцип:** Manager только координирует, каждый агент сам пишет в beads.

```
orchestrator.sh (watchdog, перезапускает Manager)
    │
    └─→ Manager (определяет что делать)
            │
            ├─→ bd list → анализирует состояние
            │
            ├─→ Логика выбора действия:
            │     • пусто → Tech Writer
            │     • spec_ready, нет плана → Architect
            │     • есть clarification → Tech Writer (с вопросом)
            │     • план готов, нет review → Analysts
            │     • review done → Executors
            │     • всё closed, CI green → DONE
            │
            └─→ Запускает subagent
                    │
                    └─→ Subagent сам пишет в beads (не ждёт Manager)
```

**Ключевые принципы:**

1. **Каждый агент сам пишет состояние**
   - Tech Writer: создаёт issue "spec-draft", обновляет после каждого ответа user'а
   - Architect: создаёт задачи сразу в beads
   - Executor: ставит in_progress при старте, закрывает при завершении

2. **Таймауты на user input**
   - 30 минут на ответ от user'а
   - При таймауте → сохраняет draft, завершается
   - Manager при следующем запуске → resume

3. **Обратная связь через clarification issues**
   - Architect создаёт issue типа "clarification"
   - Manager видит → запускает Tech Writer с контекстом
   - Tech Writer уточняет, обновляет SPEC.md, закрывает issue

4. **Критерий завершения**
   - Все issues closed
   - Нет issues типа "bug" или "clarification"
   - CI/CD прошёл (опционально)

**Почему так:**
1. **Subagents** — быстрая коммуникация внутри сессии
2. **Beads** — персистентность, recovery после падений
3. **Агенты пишут сами** — нет bottleneck на Manager
4. **Не message queue** — overkill для наших целей

### Модели агентов

| Роль | Модель | Почему |
|------|--------|--------|
| Manager | Sonnet | Простая логика if/else, не требует Opus |
| Tech Writer | Opus | Качество ТЗ критично |
| Architect | Opus | Принимает архитектурные решения |
| Остальные | TBD | Обсудим позже |

### Итерации и SPEC.md

Tech Writer работает в двух режимах:

**Новый проект:** создаёт SPEC.md с нуля

**Итерация:** дополняет существующий SPEC.md
```markdown
# SPEC.md

## Iteration 1 (MVP)
- Авторизация email/password
- Список задач

## Iteration 2
- Добавить Google OAuth
- Синхронизация между устройствами
```

Manager определяет режим: SPEC.md существует + есть closed задачи → итерация.

### Типы issue для взаимодействия с user

| Тип | Кто создаёт | Зачем | Обработка |
|-----|-------------|-------|-----------|
| `clarification` | Architect | Уточнить требования | Tech Writer → вопрос → SPEC.md |
| `decision` | Architect | User выбирает из вариантов | User → выбор → Architect применяет |

### Лимит эскалаций

```
Задача создана
    ↓
Executor stuck → эскалация #1 → Architect переформулирует
    ↓
Executor stuck → эскалация #2 → Architect меняет подход
    ↓
Executor stuck → эскалация #3 → decision issue к user
```

В beads: `escalation_count`, `max_escalations: 2`

### UX: Четыре статуса

**1. В работе** — система работает
```
$ ./status
▶ В РАБОТЕ

Фаза: Реализация
Задач: 5 из 15 выполнено
Активно: "Реализация авторизации"

→ Подождите или прервите: Ctrl+C
```

**2. Ожидает ответа** — система ждёт user
```
$ ./status
⏸ ОЖИДАЕТ ОТВЕТА

Вопрос: "Какой провайдер авторизации: Google, Apple, email?"
→ Ответьте: ./answer "email"
```

**3. Требуется решение** — система предлагает варианты
```
$ ./status
⏸ ТРЕБУЕТСЯ РЕШЕНИЕ

Проблема: "Синхронизация в реальном времени"

Варианты:
1. Упростить до периодической (каждые 5 мин)
2. Использовать Firebase/Supabase
3. Отложить на следующую итерацию
4. Другое

→ Выберите: ./choose 1
```

**4. Работа завершена** — success
```
$ ./status
✓ ЗАВЕРШЕНО

Iteration 1: 15 задач выполнено, CI: passed
→ Следующая итерация: опишите что доработать
```

**Принцип:** user выбирает из готовых вариантов, не придумывает сам.

### Отказоустойчивость

**Retry логика:**
```
Executor берёт задачу
    ↓
Таймаут 10 минут
    ↓
Не завершил? → Manager убивает, retry
    ↓
3 попытки неудачны? → статус "stuck"
    ↓
Manager запускает Architect для эскалации
```

**Эскалация к Architect (не к user):**
```
Executor stuck (3 попытки)
    ↓
Architect анализирует причину
    ↓
Architect решает:
    ├─→ Переформулирует задачу
    ├─→ Разбивает на меньшие
    ├─→ Меняет подход
    └─→ Или: проблема в требованиях → decision issue к user
    ↓
Если решил → новые задачи, Executor продолжает
Если не решил → decision issue с вариантами
```

**Принцип:** User не видит технических деталей. К нему приходят только бизнес-вопросы с готовыми вариантами ответа.

**Beads статусы для отказоустойчивости:**
```yaml
# Задача застряла
status: stuck
retry_count: 3
last_error: "timeout after 10 min"

# Ждём решения user
status: decision_required
options:
  - "Упростить до периодической синхронизации"
  - "Использовать Firebase"
  - "Отложить"
```

### Другие фреймворки (для справки)

- [Claude-Flow](https://github.com/ruvnet/claude-flow) — multi-agent swarms, MCP protocol
- [ccswarm](https://github.com/nwiizo/ccswarm) — Rust, git worktree isolation
- [Multi-agent patterns in ADK](https://developers.googleblog.com/developers-guide-to-multi-agent-patterns-in-adk/) — Google's patterns
