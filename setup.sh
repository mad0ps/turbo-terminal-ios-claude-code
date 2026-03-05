#!/bin/bash

# ============================================
# iPhone Terminal Ultra Setup
# Interactive installer for tmux + aliases
# ============================================

set -euo pipefail

trap 'error "Скрипт прерван (строка $LINENO)"' ERR

# Цвета
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }
header() { echo -e "\n${CYAN}${BOLD}=== $1 ===${NC}\n"; }

# ============================================
# АНАЛИЗ СИСТЕМЫ
# ============================================
header "АНАЛИЗ СИСТЕМЫ"

# OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    info "OS: $PRETTY_NAME"
else
    info "OS: $(uname -s) $(uname -r)"
fi

# Package manager
PKG=""
if command -v apt-get &>/dev/null; then
    PKG="apt"
    info "Package manager: apt"
elif command -v dnf &>/dev/null; then
    PKG="dnf"
    info "Package manager: dnf"
elif command -v yum &>/dev/null; then
    PKG="yum"
    info "Package manager: yum"
elif command -v apk &>/dev/null; then
    PKG="apk"
    info "Package manager: apk"
elif command -v brew &>/dev/null; then
    PKG="brew"
    info "Package manager: brew"
else
    warn "Package manager: не определён"
fi

# Shell
CURRENT_SHELL=$(basename "$SHELL")
info "Shell: $CURRENT_SHELL ($SHELL)"

case "$CURRENT_SHELL" in
    bash)
        if [ -f "$HOME/.bash_profile" ] && ! grep -q 'bashrc' "$HOME/.bash_profile" 2>/dev/null; then
            SHELL_RC="$HOME/.bash_profile"
        else
            SHELL_RC="$HOME/.bashrc"
        fi
        ;;
    zsh)
        SHELL_RC="$HOME/.zshrc"
        ;;
    fish)
        SHELL_RC="$HOME/.config/fish/config.fish"
        warn "Fish shell: алиасы и меню будут в bash-синтаксе — может потребоваться ручная адаптация"
        ;;
    *)
        warn "Неизвестный shell: $CURRENT_SHELL, используем ~/.profile"
        SHELL_RC="$HOME/.profile"
        ;;
esac
info "Конфиг shell: $SHELL_RC"

# Tmux
if command -v tmux &>/dev/null; then
    TMUX_VERSION=$(tmux -V | awk '{print $NF}')
    info "tmux: v$TMUX_VERSION (установлен)"
    TMUX_INSTALLED=true
else
    warn "tmux: не установлен"
    TMUX_INSTALLED=false
fi

# Git
if command -v git &>/dev/null; then
    info "git: $(git --version | awk '{print $NF}')"
    GIT_INSTALLED=true
else
    warn "git: не установлен"
    GIT_INSTALLED=false
fi

# Локальная или удалённая машина
if [ -n "${SSH_CONNECTION:-}" ]; then
    IS_REMOTE=true
    info "Тип подключения: удалённый сервер (SSH)"
else
    IS_REMOTE=false
    info "Тип подключения: локальная машина"
fi

# Claude Code
if command -v claude &>/dev/null; then
    info "Claude Code: $(claude --version 2>/dev/null || echo 'установлен')"
    HAS_CLAUDE=true
else
    warn "Claude Code: не найден"
    HAS_CLAUDE=false
fi

# ============================================
# НАСТРОЙКИ
# ============================================
header "НАСТРОЙКИ"

# Путь к проектам
if [ "$IS_REMOTE" = true ]; then
    DEFAULT_PROJECTS="/opt"
else
    DEFAULT_PROJECTS="$HOME/Projects"
fi
read -p "Путь к проектам [$DEFAULT_PROJECTS]: " PROJECTS_DIR
PROJECTS_DIR=${PROJECTS_DIR:-$DEFAULT_PROJECTS}

# Раскрытие ~ в путях
PROJECTS_DIR="${PROJECTS_DIR/#\~/$HOME}"

if [ -d "$PROJECTS_DIR" ]; then
    PROJECTS_DIR=$(cd "$PROJECTS_DIR" && pwd)
    info "Директория проектов: $PROJECTS_DIR"
else
    warn "Директория $PROJECTS_DIR не существует"
    read -p "Создать? [Y/n]: " create_dir
    create_dir=${create_dir:-y}
    if [ "$create_dir" = "y" ]; then
        mkdir -p "$PROJECTS_DIR"
        info "Создана: $PROJECTS_DIR"
    fi
fi

# ============================================
# ВЫБОР КОМПОНЕНТОВ
# ============================================
header "ЧТО СТАВИМ?"

INSTALL_TMUX=false
INSTALL_TMUX_CONF=false
INSTALL_MENU=false
INSTALL_PLUGINS=false
INSTALL_GIT=false

if [ "$IS_REMOTE" = true ]; then
    if [ "$TMUX_INSTALLED" = false ]; then
        read -p "Установить tmux? [Y/n]: " choice
        choice=${choice:-y}
        [ "$choice" = "y" ] && INSTALL_TMUX=true
    fi
else
    info "Локальная машина — tmux, меню и плагины пропущены"
fi

INSTALL_CLAUDE=false
if [ "$HAS_CLAUDE" = false ]; then
    read -p "Установить Claude Code? [Y/n]: " choice
    choice=${choice:-y}
    [ "$choice" = "y" ] && INSTALL_CLAUDE=true
fi

read -p "Алиасы и функции (навигация, Claude Code)? [Y/n]: " choice
choice=${choice:-y}
INSTALL_ALIASES=false
[ "$choice" = "y" ] && INSTALL_ALIASES=true

read -p "Короткий промпт (заменить на 'папка → ')? [y/N]: " choice
choice=${choice:-n}
INSTALL_PROMPT=false
[ "$choice" = "y" ] && INSTALL_PROMPT=true

if [ "$IS_REMOTE" = true ]; then
    read -p "Конфиг tmux (prefix, сплиты, статус-бар)? [Y/n]: " choice
    choice=${choice:-y}
    [ "$choice" = "y" ] && INSTALL_TMUX_CONF=true

    read -p "Меню сессий при логине? [Y/n]: " choice
    choice=${choice:-y}
    [ "$choice" = "y" ] && INSTALL_MENU=true

    read -p "Автосохранение сессий (resurrect + continuum)? [Y/n]: " choice
    choice=${choice:-y}
    [ "$choice" = "y" ] && INSTALL_PLUGINS=true
fi

INSTALL_AGENT_PERMS=false
if command -v claude &>/dev/null || [ "$INSTALL_CLAUDE" = true ]; then
    echo ""
    warn "Следующая опция разрешает Claude Code выполнять ВСЕ действия без подтверждений"
    warn "Рекомендуется только для доверенных серверов"
    read -p "Расширенные разрешения для агентов? [y/N]: " choice
    choice=${choice:-n}
    [ "$choice" = "y" ] && INSTALL_AGENT_PERMS=true
fi

# Проверка git для плагинов
if [ "$INSTALL_PLUGINS" = true ] && [ "$GIT_INSTALLED" = false ]; then
    warn "Для плагинов нужен git"
    read -p "Установить git? [Y/n]: " choice
    choice=${choice:-y}
    if [ "$choice" = "y" ]; then
        INSTALL_GIT=true
    else
        INSTALL_PLUGINS=false
        warn "Плагины отключены"
    fi
fi

# Подтверждение
header "ПЛАН УСТАНОВКИ"

[ "$INSTALL_TMUX" = true ] && echo "  → Установить tmux"
[ "$INSTALL_CLAUDE" = true ] && echo "  → Установить Claude Code"
[ "$INSTALL_GIT" = true ] && echo "  → Установить git"
[ "$INSTALL_ALIASES" = true ] && echo "  → Алиасы в $SHELL_RC"
[ "$INSTALL_PROMPT" = true ] && echo "  → Короткий промпт"
[ "$INSTALL_TMUX_CONF" = true ] && echo "  → Конфиг ~/.tmux.conf"
[ "$INSTALL_MENU" = true ] && echo "  → Меню сессий при логине"
[ "$INSTALL_PLUGINS" = true ] && echo "  → Плагины resurrect + continuum"
[ "$INSTALL_AGENT_PERMS" = true ] && echo "  → Расширенные разрешения Claude Code (без подтверждений)"
echo ""

if [ "$INSTALL_TMUX" = true ] || [ "$INSTALL_GIT" = true ]; then
    echo -e "${YELLOW}[!]${NC} Может потребоваться пароль sudo для установки пакетов"
    echo ""
fi

read -p "Поехали? [Y/n]: " confirm
confirm=${confirm:-y}
if [ "$confirm" != "y" ]; then
    echo "Отменено."
    exit 0
fi

# ============================================
# БЭКАП
# ============================================
header "БЭКАП"

BACKUP_DIR="$HOME/.terminal-setup-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

if [ -f "$SHELL_RC" ]; then
    cp "$SHELL_RC" "$BACKUP_DIR/"
    info "Бэкап $SHELL_RC"
fi

if [ -f "$HOME/.tmux.conf" ]; then
    cp "$HOME/.tmux.conf" "$BACKUP_DIR/"
    info "Бэкап ~/.tmux.conf"
fi

info "Бэкапы в: $BACKUP_DIR"

# ============================================
# УСТАНОВКА ПАКЕТОВ
# ============================================

install_pkg() {
    local pkg="$1"
    case "$PKG" in
        apt) sudo apt-get update -qq && sudo apt-get install -y -qq "$pkg";;
        yum) sudo yum install -y -q "$pkg";;
        dnf) sudo dnf install -y -q "$pkg";;
        apk) sudo apk add --quiet "$pkg";;
        brew) brew install "$pkg";;
        *) error "Не могу установить $pkg — неизвестный package manager"; return 1;;
    esac
}

if [ "$INSTALL_TMUX" = true ]; then
    header "УСТАНОВКА TMUX"
    if install_pkg tmux; then
        info "tmux установлен: $(tmux -V)"
    else
        error "Не удалось установить tmux"
        INSTALL_TMUX_CONF=false
        INSTALL_PLUGINS=false
        INSTALL_MENU=false
        warn "Конфиг tmux, плагины и меню отключены"
    fi
fi

if [ "$INSTALL_GIT" = true ]; then
    header "УСТАНОВКА GIT"
    if install_pkg git; then
        info "git установлен"
    else
        error "Не удалось установить git"
        INSTALL_PLUGINS=false
        warn "Плагины отключены (нет git)"
    fi
fi

if [ "$INSTALL_CLAUDE" = true ]; then
    header "УСТАНОВКА CLAUDE CODE"
    if curl -fsSL https://claude.ai/install.sh | bash; then
        info "Claude Code: $(claude --version 2>/dev/null)"
    else
        error "Не удалось установить Claude Code"
        INSTALL_AGENT_PERMS=false
    fi
fi

if [ "$INSTALL_AGENT_PERMS" = true ]; then
    header "РАЗРЕШЕНИЯ CLAUDE CODE"
    mkdir -p "$HOME/.claude"
    if [ -f "$HOME/.claude/settings.json" ]; then
        cp "$HOME/.claude/settings.json" "$BACKUP_DIR/settings.json"
        warn "Существующий settings.json сохранён в бэкап"
    fi
    cat > "$HOME/.claude/settings.json" << 'CLAUDE_SETTINGS'
{
  "permissions": {
    "allow": [
      "Bash",
      "Read",
      "Edit",
      "Write",
      "Glob",
      "Grep",
      "WebFetch",
      "WebSearch",
      "NotebookEdit",
      "Task",
      "Skill"
    ]
  }
}
CLAUDE_SETTINGS
    info "Расширенные разрешения установлены в ~/.claude/settings.json"
fi

# ============================================
# АЛИАСЫ + МЕНЮ ЛОГИНА
# ============================================

if [ "$INSTALL_ALIASES" = true ] || [ "$INSTALL_MENU" = true ]; then
    header "АЛИАСЫ И МЕНЮ"

    # Создаём RC-файл если не существует
    touch "$SHELL_RC"

    # Удаляем старый блок если есть (для идемпотентности)
    if grep -q '# === ULTRA TERMINAL CONFIG ===' "$SHELL_RC" 2>/dev/null; then
        if [[ "$(uname)" == "Darwin" ]]; then
            sed -i '' '/# === ULTRA TERMINAL CONFIG ===/,/# === END ULTRA TERMINAL CONFIG ===/d' "$SHELL_RC"
        else
            sed -i '/# === ULTRA TERMINAL CONFIG ===/,/# === END ULTRA TERMINAL CONFIG ===/d' "$SHELL_RC"
        fi
        info "Старый конфиг удалён из $SHELL_RC"
    fi

    # Открываем блок
    cat >> "$SHELL_RC" << BLOCK_START

# === ULTRA TERMINAL CONFIG ===
# Installed: $(date +%Y-%m-%d)
BLOCK_START

    # Алиасы
    if [ "$INSTALL_ALIASES" = true ]; then
        # Tmux-алиасы только для удалённых машин
        if [ "$IS_REMOTE" = true ]; then
            cat >> "$SHELL_RC" << TMUX_ALIASES

# Tmux
alias tl='tmux ls'
alias tk='tmux kill-session -t'
alias td='tmux detach'
TMUX_ALIASES
        fi

        cat >> "$SHELL_RC" << ALIASES

# Claude Code
alias c='claude'
alias cr='claude --resume'
alias cc='claude --continue'
alias q='claude -p'

# Навигация
alias ..='cd ..'
alias ...='cd ../..'
alias l='ls -la'

# Проекты ($PROJECTS_DIR)
p() {
    if [ -z "\$1" ]; then
        echo "Доступные проекты:"
        ls -1 "$PROJECTS_DIR"
        return
    fi
    if [ ! -d "$PROJECTS_DIR/\$1" ]; then
        echo "Проект не найден: \$1"
        echo "Доступные: \$(ls -1 "$PROJECTS_DIR")"
        return 1
    fi
    cd "$PROJECTS_DIR/\$1" && ls
}
ALIASES

        # np: на удалённой — mkdir + tmux окно, на локальной — mkdir + cd
        if [ "$IS_REMOTE" = true ]; then
            cat >> "$SHELL_RC" << NP_REMOTE
np() {
    if [ -z "\$1" ]; then
        echo "Использование: np <имя_проекта>"
        return 1
    fi
    mkdir -p "$PROJECTS_DIR/\$1"
    if [ -n "\$TMUX" ]; then
        tmux new-window -n "\$1" -c "$PROJECTS_DIR/\$1"
    else
        tmux new -s "\$1" -n "\$1" -c "$PROJECTS_DIR/\$1"
    fi
}
NP_REMOTE
        else
            cat >> "$SHELL_RC" << NP_LOCAL
np() {
    if [ -z "\$1" ]; then
        echo "Использование: np <имя_проекта>"
        return 1
    fi
    mkdir -p "$PROJECTS_DIR/\$1"
    cd "$PROJECTS_DIR/\$1"
}
NP_LOCAL
        fi

        cat >> "$SHELL_RC" << ALIASES_END

# Автокомплит для p и np
if [ -n "\$ZSH_VERSION" ]; then
    compctl -W "$PROJECTS_DIR" -/ p np
elif [ -n "\$BASH_VERSION" ]; then
    _opt_complete() {
        local cur="\${COMP_WORDS[COMP_CWORD]}"
        COMPREPLY=(\$(compgen -W "\$(ls -1 "$PROJECTS_DIR" 2>/dev/null)" -- "\$cur"))
    }
    complete -F _opt_complete p np
fi
ALIASES_END

        # Короткий промпт (опционально)
        if [ "$INSTALL_PROMPT" = true ]; then
            if [ "$CURRENT_SHELL" = "zsh" ]; then
                echo "PS1='%1~ → '" >> "$SHELL_RC"
            else
                echo "PS1='\W → '" >> "$SHELL_RC"
            fi
            info "Промпт изменён"
        fi

        info "Алиасы добавлены в $SHELL_RC"
    fi

    # Меню логина
    if [ "$INSTALL_MENU" = true ]; then
        cat >> "$SHELL_RC" << MENU

# Меню tmux при логине
if [ -z "\$TMUX" ]; then
    _C='\\033[0;36m'
    _W='\\033[1;37m'
    _G='\\033[0;32m'
    _Y='\\033[1;33m'
    _D='\\033[0;90m'
    _N='\\033[0m'

    echo ""
    echo -e "\${_C}   ┌┬┐┬ ┬┬─┐┌┐ ┌─┐  ┌┬┐┌─┐┬─┐┌┬┐\${_N}"
    echo -e "\${_C}    │ │ │├┬┘├┴┐│ │   │ ├┤ ├┬┘│││\${_N}"
    echo -e "\${_C}    ┴ └─┘┴└─└─┘└─┘   ┴ └─┘┴└─┴ ┴\${_N}"
    echo -e "\${_D}   ─────────────────────────────────\${_N}"
    echo -e "\${_D}   iPhone · tmux · Claude Code\${_N}"
    echo ""

    if SESSIONS=\$(tmux ls -F '#{session_name}|#{session_windows}|#{W:#{window_name} }' 2>/dev/null | sed 's/\\\\033\\[[0-9;]*[a-zA-Z]//g') && [ -n "\$SESSIONS" ]; then
        echo -e "  \${_G}● АКТИВНЫЕ СЕССИИ\${_N}"
        echo -e "  \${_D}───────────────────────────────\${_N}"
        echo "\$SESSIONS" | while IFS='|' read -r sess_name win_count win_names; do
            win_names=\$(echo "\$win_names" | sed 's/ *\$//')
            echo -e "    \${_W}▸ \${sess_name}\${_N} \${_D}(\${win_count} окон)\${_N} \${_C}[\${win_names}]\${_N}"
        done
        echo -e "  \${_D}───────────────────────────────\${_N}"
        echo ""
        echo -e "  \${_Y}[a]\${_N} attach  \${_Y}[n]\${_N} new  \${_Y}[r]\${_N} rename  \${_Y}[s]\${_N} shell"
        echo -e "  \${_D}или введи имя сессии\${_N}"
        echo ""
        read -p "  → " choice
        case \$choice in
            a) read -p "  session: " sess; tmux a -t "\$sess";;
            n) read -p "  name: " sess; tmux new -s "\$sess" -c "$PROJECTS_DIR/\$sess" 2>/dev/null || tmux new -s "\$sess";;
            r) read -p "  старое имя: " old; read -p "  новое имя: " new; tmux rename-session -t "\$old" "\$new" && echo -e "  \${_G}✓\${_N} \$old → \$new";;
            s) ;;
            "") ;;
            *) tmux a -t "\$choice" 2>/dev/null || tmux new -s "\$choice";;
        esac
    else
        echo -e "  \${_D}○ нет активных сессий\${_N}"
        echo ""
        echo -e "  \${_Y}[n]\${_N} new session   \${_Y}[s]\${_N} shell"
        echo -e "  \${_D}или введи имя для новой сессии\${_N}"
        echo ""
        read -p "  → " choice
        case \$choice in
            n) read -p "  name: " sess; tmux new -s "\$sess" -c "$PROJECTS_DIR/\$sess" 2>/dev/null || tmux new -s "\$sess";;
            s|"") ;;
            *) tmux new -s "\$choice";;
        esac
    fi
fi
MENU

        info "Меню логина добавлено"
    fi

    # Закрываем блок
    echo '# === END ULTRA TERMINAL CONFIG ===' >> "$SHELL_RC"
fi

# ============================================
# TMUX КОНФИГ
# ============================================

if [ "$INSTALL_TMUX_CONF" = true ]; then
    header "TMUX КОНФИГ"

    cat > "$HOME/.tmux.conf" << 'TMUXCONF'

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
TMUXCONF

    info "tmux конфиг создан"
fi

# ============================================
# ПЛАГИНЫ
# ============================================

if [ "$INSTALL_PLUGINS" = true ]; then
    header "ПЛАГИНЫ TMUX"

    mkdir -p "$HOME/.tmux/plugins"

    if [ ! -d "$HOME/.tmux/plugins/tmux-resurrect/.git" ]; then
        rm -rf "$HOME/.tmux/plugins/tmux-resurrect"
        git clone -q https://github.com/tmux-plugins/tmux-resurrect "$HOME/.tmux/plugins/tmux-resurrect" && \
            info "tmux-resurrect установлен" || error "Ошибка при клонировании tmux-resurrect"
    else
        info "tmux-resurrect уже есть"
    fi

    if [ ! -d "$HOME/.tmux/plugins/tmux-continuum/.git" ]; then
        rm -rf "$HOME/.tmux/plugins/tmux-continuum"
        git clone -q https://github.com/tmux-plugins/tmux-continuum "$HOME/.tmux/plugins/tmux-continuum" && \
            info "tmux-continuum установлен" || error "Ошибка при клонировании tmux-continuum"
    else
        info "tmux-continuum уже есть"
    fi

    cat >> "$HOME/.tmux.conf" << 'PLUGINS'

# Resurrect + Continuum — автосохранение
run-shell ~/.tmux/plugins/tmux-resurrect/resurrect.tmux
run-shell ~/.tmux/plugins/tmux-continuum/continuum.tmux
set -g @continuum-save-interval '10'
set -g @continuum-restore 'on'
set -g @resurrect-save-shell-history 'off'
PLUGINS

    # Крон для очистки старых сохранений (добавляем только если ещё нет)
    if ! crontab -l 2>/dev/null | grep -q 'tmux/resurrect'; then
        (crontab -l 2>/dev/null; echo "0 */6 * * * find ~/.tmux/resurrect -name '*.txt' ! -name 'last' -mmin +60 -delete") | crontab - && \
            info "Крон очистки настроен" || warn "Ошибка установки крона"
    else
        info "Крон очистки уже настроен"
    fi

    info "Автосохранение каждые 10 минут"
fi

# ============================================
# ПРИМЕНЯЕМ
# ============================================
header "ПРИМЕНЯЕМ"

if [ "$INSTALL_TMUX_CONF" = true ] || [ "$INSTALL_PLUGINS" = true ]; then
    tmux source "$HOME/.tmux.conf" 2>/dev/null && info "tmux конфиг применён" || warn "tmux конфиг применится при следующем запуске"
fi

if [ "$INSTALL_ALIASES" = true ] || [ "$INSTALL_MENU" = true ]; then
    info "Алиасы применятся при следующем логине или: source $SHELL_RC"
fi

# ============================================
# ГОТОВО
# ============================================
header "ГОТОВО!"

if [ "$IS_REMOTE" = true ]; then
    echo -e "
${BOLD}Что дальше:${NC}

  source $SHELL_RC    — применить алиасы сейчас
  переподключись      — увидишь меню сессий

${BOLD}Бэкапы:${NC} $BACKUP_DIR
${BOLD}Откат:${NC}  cp $BACKUP_DIR/* ~/

${BOLD}Шпаргалка:${NC}
  Ctrl+A ↑↓    переключение окон
  Ctrl+A s     список сессий
  Ctrl+A |     вертикальный сплит
  Ctrl+A -     горизонтальный сплит
  Ctrl+A n     новое окно
  Ctrl+A d     detach
  Ctrl+A g     popup окно
  np имя       новый проект (mkdir + окно)
  p имя        перейти в проект
  cr           продолжить Claude Code
"
else
    echo -e "
${BOLD}Что дальше:${NC}

  source $SHELL_RC    — применить алиасы сейчас

${BOLD}Бэкапы:${NC} $BACKUP_DIR
${BOLD}Откат:${NC}  cp $BACKUP_DIR/* ~/

${BOLD}Шпаргалка:${NC}
  np имя       новый проект (mkdir + cd)
  p имя        перейти в проект
  c            запустить Claude Code
  cr           продолжить Claude Code
  q вопрос     быстрый вопрос Claude
"
fi
