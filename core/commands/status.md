---
name: status
description: Статус проекта
---
```bash
./scripts/detect-phase.sh
bd list --json | jq 'group_by(.status) | map({status: .[0].status, count: length})'
```
