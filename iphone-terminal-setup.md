# iPhone Terminal Ultra Setup

> Полная конфигурация для работы с сервером через iPhone (Termius + tmux + Claude Code)
> Автор: Khan

---

## Быстрая установка

Скопируй и выполни на сервере **до входа в tmux**. Разбито на части для удобного копирования с iPhone.

### Шаг 1 — Бэкап

```bash
mkdir -p ~/.terminal-setup-backup && chmod 700 ~/.terminal-setup-backup
cp ~/.bashrc ~/.terminal-setup-backup/ 2>/dev/null
cp ~/.tmux.conf ~/.terminal-setup-backup/ 2>/dev/null
```

### Шаг 2 — Установка Claude Code (если нет)

```bash
command -v claude &>/dev/null || curl -fsSL https://claude.ai/install.sh | bash
claude --version
```

### Шаг 3 — .bashrc часть 1 (алиасы)

```bash
cat >> ~/.bashrc << 'EOF'

# === ULTRA TERMINAL CONFIG ===

# Tmux
alias tl='tmux ls'
alias tk='tmux kill-session -t'
alias td='tmux detach'

# Claude Code
alias c='claude'
alias cr='claude --resume'
alias cc='claude --continue'
alias q='claude -p'

# Навигация
alias ..='cd ..'
alias ...='cd ../..'
alias l='ls -la'
EOF
```

### Шаг 4 — .bashrc часть 2 (функции)

```bash
cat >> ~/.bashrc << 'EOF'

# Проекты (/opt)
p() {
    if [ -z "$1" ]; then
        echo "Доступные проекты:"
        ls -1 /opt
        return
    fi
    if [ ! -d "/opt/$1" ]; then
        echo "Проект не найден: $1"
        echo "Доступные: $(ls -1 /opt)"
        return 1
    fi
    cd "/opt/$1" && ls
}
np() { tmux new -s "$1" -c "/opt/$1"; }

# Автокомплит для p и np
_opt_complete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    COMPREPLY=($(compgen -W "$(ls -1 /opt 2>/dev/null)" -- "$cur"))
}
complete -F _opt_complete p np

# Короткий промпт
PS1='\W → '
EOF
```

### Шаг 5 — .bashrc часть 3 (меню при логине)

```bash
cat >> ~/.bashrc << 'EOF'

# Меню tmux при логине
if [ -z "$TMUX" ]; then
    echo ""
    echo "=== TMUX SESSIONS ==="
    echo ""
    if tmux ls 2>/dev/null; then
        echo ""
        echo "[a] attach to session (enter name)"
        echo "[n] new session (enter name)"
        echo "[r] rename session"
        echo "[s] shell without tmux"
        echo ""
        read -p "→ " choice
        case $choice in
            a) read -p "session: " sess; tmux a -t "$sess";;
            n) read -p "name: " sess; tmux new -s "$sess" -c "/opt/$sess" 2>/dev/null || tmux new -s "$sess";;
            r) read -p "старое имя: " old; read -p "новое имя: " new; tmux rename-session -t "$old" "$new";;
            s) ;;
            *) tmux a -t "$choice" 2>/dev/null || tmux new -s "$choice";;
        esac
    else
        echo "no active sessions"
        echo ""
        echo "[n] new session (enter name)"
        echo "[s] shell without tmux"
        echo ""
        read -p "→ " choice
        case $choice in
            n) read -p "name: " sess; tmux new -s "$sess" -c "/opt/$sess" 2>/dev/null || tmux new -s "$sess";;
            s) ;;
            *) tmux new -s "$choice";;
        esac
    fi
fi
EOF
```

### Шаг 6 — .tmux.conf часть 1 (базовое + внешний вид)

```bash
cat > ~/.tmux.conf << 'EOF'

# Префикс Ctrl+A
set -g prefix C-a
unbind C-b
bind C-a send-prefix

# Базовое
set -g mouse on
set -sg escape-time 10
set -g history-limit 100000

# Статус-бар минимальный наверху
set -g status-position top
set -g status-style 'bg=black fg=white'
set -g status-left ' #S '
set -g status-left-length 15
set -g status-right '#I/#{session_windows}'

# Подсветка активного окна
set -g window-status-current-style 'bg=white fg=black bold'
set -g window-status-format ' #I:#W '
set -g window-status-current-format ' #I:#W '

# Автоименование окон по папке
set -g automatic-rename on
set -g automatic-rename-format '#{b:pane_current_path}'
EOF
```

### Шаг 7 — .tmux.conf часть 2 (управление)

```bash
cat >> ~/.tmux.conf << 'EOF'

# Окна — prefix + вверх/вниз
bind Up previous-window
bind Down next-window

# Новое окно / закрыть с подтверждением
bind n new-window
bind x confirm-before -p "kill pane? (y/n)" kill-pane

# Popup для быстрой команды
bind g display-popup -w 80% -h 60%

# Сплиты
bind | split-window -h
bind - split-window -v

# Переключение панелей
bind -n M-Left select-pane -L
bind -n M-Right select-pane -R
bind -n M-Up select-pane -U
bind -n M-Down select-pane -D
EOF
```

### Шаг 8 — Tmux Resurrect + Continuum (автосохранение сессий)

```bash
mkdir -p ~/.tmux/plugins
git clone https://github.com/tmux-plugins/tmux-resurrect ~/.tmux/plugins/tmux-resurrect
git clone https://github.com/tmux-plugins/tmux-continuum ~/.tmux/plugins/tmux-continuum
```

```bash
cat >> ~/.tmux.conf << 'EOF'

# Resurrect + Continuum — автосохранение
run-shell ~/.tmux/plugins/tmux-resurrect/resurrect.tmux
run-shell ~/.tmux/plugins/tmux-continuum/continuum.tmux
set -g @continuum-save-interval '10'
set -g @continuum-restore 'on'
set -g @resurrect-save-shell-history 'off'
EOF
```

Очистка старых сохранений (крон, добавляется только если ещё нет):

```bash
crontab -l 2>/dev/null | grep -q 'tmux/resurrect' || \
  (crontab -l 2>/dev/null; echo "0 */6 * * * find ~/.tmux/resurrect -name '*.txt' ! -name 'last' -mmin +60 -delete") | crontab -
```

### Шаг 9 — Применить

```bash
tmux source ~/.tmux.conf 2>/dev/null
source ~/.bashrc
```

---

## Шпаргалка по горячим клавишам

Все команды tmux начинаются с **prefix = Ctrl+A**

### Сессии

| Действие | Команда |
|----------|---------|
| Список сессий | `Ctrl+A s` |
| Следующая сессия | `Ctrl+A )` |
| Предыдущая сессия | `Ctrl+A (` |
| Отключиться (detach) | `Ctrl+A d` |
| Новая сессия проекта | `np имя` |

### Окна

| Действие | Команда |
|----------|---------|
| Новое окно | `Ctrl+A n` |
| Следующее окно | `Ctrl+A ↓` |
| Предыдущее окно | `Ctrl+A ↑` |
| Переименовать окно | `Ctrl+A ,` |
| Закрыть панель | `Ctrl+A x` (с подтверждением) |

### Панели (сплиты)

| Действие | Команда |
|----------|---------|
| Вертикальный сплит | `Ctrl+A \|` |
| Горизонтальный сплит | `Ctrl+A -` |
| Переключение панелей | мышь/тап или `Alt+стрелки` |
| Popup окно | `Ctrl+A g` |

### Claude Code

| Действие | Команда |
|----------|---------|
| Запустить Claude | `c` |
| Продолжить сессию | `cr` |
| Continue с контекстом | `cc` |
| Одноразовый запрос | `q "текст вопроса"` |
| Выйти из Claude | `/exit` |

### Навигация

| Действие | Команда |
|----------|---------|
| Список проектов | `p` |
| Зайти в проект | `p имя` (Tab работает) |
| Новая сессия проекта | `np имя` (Tab работает) |
| Список tmux сессий | `tl` |
| Убить сессию | `tk имя` |

### Меню логина

| Действие | Команда |
|----------|---------|
| Подключиться к сессии | `a` → имя |
| Новая сессия | `n` → имя |
| Переименовать сессию | `r` → старое → новое |
| Shell без tmux | `s` |
| Быстрый вход | просто введи имя сессии |

---

## Типичный рабочий процесс

```
1. Подключился по SSH → увидел меню сессий
2. Выбрал существующую или создал новую
3. cr — продолжил работу в Claude Code
4. /exit — вышел из Claude, сессия сохранена
5. np другой_проект — переключился на другой проект
6. Ctrl+A s — переключение между сессиями
7. Ctrl+A d — отключился, всё работает в фоне
8. Автосохранение каждые 10 минут
```

---

## Советы для iPhone

- **Раскладка** — переключи на английский перед Ctrl+A, tmux не понимает русскую
- **Свайпы в Termius** — по экрану работают как стрелки (встроенная фича)
- **Landscape режим** — переверни телефон горизонтально когда нужно больше ширины
- **Шрифт** — уменьши в настройках Termius для большего контента на экране
- **iOS Text Replacement** — Настройки → Основные → Клавиатура → Замена текста. Можно добавить сокращения для частых команд
- **Сниппеты Termius** — сохрани длинные команды, запуск в одно нажатие

---

## Восстановление на новом сервере

Одной командой:

```bash
git clone https://github.com/mad0ps/turbo-terminal-ios-claude-code.git /tmp/turbo-setup && bash /tmp/turbo-setup/setup.sh
```

Или вручную — выполни шаги 1-9 по порядку.

---

## Откат к исходным настройкам

```bash
cp ~/.terminal-setup-backup/* ~/ 2>/dev/null
source ~/.bashrc
tmux source ~/.tmux.conf 2>/dev/null
```
