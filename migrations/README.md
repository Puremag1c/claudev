# Migrations

Migration scripts run automatically during `hype upgrade`.

## Naming Convention

`{from_version}-to-{to_version}.sh`

Example: `0.8.0-to-0.9.0.sh`

## How It Works

1. User runs `hype upgrade`
2. Script reads `.hype/version` (e.g., `0.8.2`)
3. Compares with current VERSION (e.g., `0.9.0`)
4. Finds migrations where `from <= project_version < to`
5. Runs matching migrations in order

## Writing Migrations

```bash
#!/bin/bash
# Migration: 0.8.0 → 0.9.0
# Description: What this migration does

# Migration code here
# - Can use info(), success(), warn(), error() functions
# - Has access to $CLAUDEV_HOME
# - Runs in project directory context

info "Running 0.8.0 → 0.9.0 migration"

# Example: Add new entry to config
if [[ -f ".hype/config.sh" ]]; then
    if ! grep -q "NEW_SETTING" .hype/config.sh; then
        echo 'NEW_SETTING="value"' >> .hype/config.sh
        success "Added NEW_SETTING to config"
    fi
fi
```

## Testing

```bash
# Simulate upgrade from specific version
echo "0.8.0" > .hype/version
hype upgrade
```
