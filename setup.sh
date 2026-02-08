#!/bin/bash

# ============================================
# iPhone Terminal Ultra Setup
# Interactive installer for tmux + aliases
# ============================================

set -e

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
elif command -v yum &>/dev/null; then
    PKG="yum"
    info "Package manager: yum"
elif command -v dnf &>/dev/null; then
    PKG="dnf"
    info "Package manager: dnf"
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
        SHELL_RC="$HOME/.bashrc"
        ;;
    zsh)
        SHELL_RC="$HOME/.zshrc"
        ;;
    *)
        warn "Неизвестный shell: $CURRENT_SHELL, используем ~/.profile"
        SHELL_RC="$HOME/.profile"
        ;;
esac
info "Конфиг shell: $SHELL_RC"

# Tmux
if command -v tmux &>/dev/null; then
    TMUX_VERSION=$(tmux -V | awk '{print $2}')
    info "tmux: v$TMUX_VERSION (установлен)"
    TMUX_INSTALLED=true
else
    warn "tmux: не установлен"
    TMUX_INSTALLED=false
fi

# Git
if command -v git &>/dev/null; then
    info "git: $(git --version | awk '{print $3}')"
    GIT_INSTALLED=true
else
    warn "git: не установлен"
    GIT_INSTALLED=false
fi

# Claude Code
if command -v claude &>/dev/null; then
    info "Claude Code: установлен"
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
read -p "Путь к проектам [/opt]: " PROJECTS_DIR
PROJECTS_DIR=${PROJECTS_DIR:-/opt}

if [ -d "$PROJECTS_DIR" ]; then
    info "Директория проектов: $PROJECTS_DIR"
else
    warn "Директория $PROJECTS_DIR не существует"
    read -p "Создать? [y/n]: " create_dir
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
if [ "$TMUX_INSTALLED" = false ]; then
    read -p "Установить tmux? [y/n]: " choice
    [ "$choice" = "y" ] && INSTALL_TMUX=true
fi

read -p "Алиасы и функции (навигация, Claude Code)? [y/n]: " choice
INSTALL_ALIASES=false
[ "$choice" = "y" ] && INSTALL_ALIASES=true

read -p "Конфиг tmux (prefix, сплиты, статус-бар)? [y/n]: " choice
INSTALL_TMUX_CONF=false
[ "$choice" = "y" ] && INSTALL_TMUX_CONF=true

read -p "Меню сессий при логине? [y/n]: " choice
INSTALL_MENU=false
[ "$choice" = "y" ] && INSTALL_MENU=true

read -p "Автосохранение сессий (resurrect + continuum)? [y/n]: " choice
INSTALL_PLUGINS=false
[ "$choice" = "y" ] && INSTALL_PLUGINS=true

# Проверка git для плагинов
if [ "$INSTALL_PLUGINS" = true ] && [ "$GIT_INSTALLED" = false ]; then
    warn "Для плагинов нужен git"
    read -p "Установить git? [y/n]: " choice
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
[ "$INSTALL_ALIASES" = true ] && echo "  → Алиасы в $SHELL_RC"
[ "$INSTALL_TMUX_CONF" = true ] && echo "  → Конфиг ~/.tmux.conf"
[ "$INSTALL_MENU" = true ] && echo "  → Меню сессий при логине"
[ "$INSTALL_PLUGINS" = true ] && echo "  → Плагины resurrect + continuum"
echo ""

read -p "Поехали? [y/n]: " confirm
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
    local pkg=$1
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
    install_pkg tmux && info "tmux установлен: $(tmux -V)" || error "Не удалось установить tmux"
fi

if [ "${INSTALL_GIT:-false}" = true ]; then
    header "УСТАНОВКА GIT"
    install_pkg git && info "git установлен" || error "Не удалось установить git"
fi

# ============================================
# АЛИАСЫ
# ============================================

if [ "$INSTALL_ALIASES" = true ]; then
    header "АЛИАСЫ"

    cat >> "$SHELL_RC" << ALIASES

# === ULTRA TERMINAL CONFIG ===
# Installed: $(date +%Y-%m-%d)

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

# Проекты ($PROJECTS_DIR)
p() { cd $PROJECTS_DIR/\$1 && ls; }
np() { tmux new -s \$1 -c $PROJECTS_DIR/\$1; }

# Автокомплит для p и np
_opt_complete() {
    local cur=\${COMP_WORDS[COMP_CWORD]}
    COMPREPLY=(\$(ls $PROJECTS_DIR/ | grep "^\$cur"))
}
complete -F _opt_complete p np

# Короткий промпт
PS1='\W → '
ALIASES

    info "Алиасы добавлены в $SHELL_RC"
fi

# ============================================
# МЕНЮ ЛОГИНА
# ============================================

if [ "$INSTALL_MENU" = true ]; then
    header "МЕНЮ ЛОГИНА"

    cat >> "$SHELL_RC" << 'MENU'

# Меню tmux при логине
if [ -z "$TMUX" ]; then
    echo ""
    echo "=== TMUX SESSIONS ==="
    echo ""
    if tmux ls 2>/dev/null; then
        echo ""
        echo "[a] attach to session (enter name)"
        echo "[n] new session (enter name)"
        echo "[s] shell without tmux"
        echo ""
        read -p "→ " choice
        case $choice in
            a) read -p "session: " sess; tmux a -t $sess;;
            n) read -p "name: " sess; tmux new -s $sess -c /opt/$sess 2>/dev/null || tmux new -s $sess;;
            s) ;;
            *) tmux a -t $choice 2>/dev/null || tmux new -s $choice;;
        esac
    else
        echo "no active sessions"
        echo ""
        echo "[n] new session (enter name)"
        echo "[s] shell without tmux"
        echo ""
        read -p "→ " choice
        case $choice in
            n) read -p "name: " sess; tmux new -s $sess -c /opt/$sess 2>/dev/null || tmux new -s $sess;;
            s) ;;
            *) tmux new -s $choice;;
        esac
    fi
fi
MENU

    info "Меню логина добавлено"
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

    if [ ! -d "$HOME/.tmux/plugins/tmux-resurrect" ]; then
        git clone -q https://github.com/tmux-plugins/tmux-resurrect "$HOME/.tmux/plugins/tmux-resurrect"
        info "tmux-resurrect установлен"
    else
        info "tmux-resurrect уже есть"
    fi

    if [ ! -d "$HOME/.tmux/plugins/tmux-continuum" ]; then
        git clone -q https://github.com/tmux-plugins/tmux-continuum "$HOME/.tmux/plugins/tmux-continuum"
        info "tmux-continuum установлен"
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

    # Крон для очистки старых сохранений
    (crontab -l 2>/dev/null | grep -v 'tmux/resurrect'; echo "0 */6 * * * find ~/.tmux/resurrect -name '*.txt' ! -name 'last' -mmin +60 -delete") | crontab -

    info "Автосохранение каждые 10 минут"
    info "Крон очистки настроен"
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
  np имя       новая сессия проекта
  p имя        перейти в проект
  cr           продолжить Claude Code
"
