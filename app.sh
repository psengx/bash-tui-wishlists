#!/usr/bin/env bash

# Wishlist Manager — простой TUI-менеджер вишлистов на Bash.

BASE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$BASE_DIR/data/wishlists"

init_storage() {
    mkdir -p "$DATA_DIR"
}

show_header() {
    clear 2>/dev/null || true
    printf '%s\n' "========================================"
    printf '%s\n' "             WISHLIST MANAGER"
    printf '%s\n' "========================================"
    printf '\n'
}

pause() {
    printf '\nНажмите Enter, чтобы вернуться в меню...'
    read -r _
}

show_menu() {
    printf '%s\n' \
        "1. Создать вишлист" \
        "2. Посмотреть все вишлисты" \
        "3. Открыть вишлист" \
        "4. Редактировать вишлист" \
        "5. Удалить вишлист" \
        "6. Найти подарок" \
        "0. Выход"
    printf '\n'
}

get_wishlist_files() {
    # Результат — список файлов, отсортированный по имени.
    find "$DATA_DIR" -maxdepth 1 -type f -name '*.txt' -print | sort
}

list_wishlists() {
    local files=()
    while IFS= read -r file; do
        [[ -n "$file" ]] && files+=("$file")
    done < <(get_wishlist_files)

    if (( ${#files[@]} == 0 )); then
        echo "Вишлистов пока нет."
        return 1
    fi

    local i=1 title count
    for file in "${files[@]}"; do
        title="$(head -n 1 "$file")"
        count="$(tail -n +2 "$file" | grep -c . || true)"
        printf '%d. %s — подарков: %s\n' "$i" "$title" "$count"
        ((i++))
    done
    return 0
}

select_wishlist() {
    local files=()
    while IFS= read -r file; do
        [[ -n "$file" ]] && files+=("$file")
    done < <(get_wishlist_files)

    if (( ${#files[@]} == 0 )); then
        echo "Нет доступных вишлистов."
        return 1
    fi

    list_wishlists
    printf '\nВведите номер вишлиста: '
    read -r selection

    if [[ ! "$selection" =~ ^[0-9]+$ ]] ||
       (( selection < 1 || selection > ${#files[@]} )); then
        echo "Некорректный номер."
        return 1
    fi

    SELECTED_FILE="${files[$((selection - 1))]}"
    return 0
}

create_wishlist() {
    show_header
    printf 'Название нового вишлиста: '
    read -r title

    if [[ -z "${title//[[:space:]]/}" ]]; then
        echo "Название не может быть пустым."
        pause
        return
    fi

    local id file
    id="wishlist_$(date +%Y%m%d_%H%M%S)_$$"
    file="$DATA_DIR/$id.txt"

    # Первая строка файла — название, остальные строки — подарки.
    printf '%s\n' "$title" > "$file"
    echo "Вишлист «$title» создан."
    pause
}

view_wishlist() {
    show_header
    if ! select_wishlist; then
        pause
        return
    fi

    local title
    title="$(head -n 1 "$SELECTED_FILE")"
    printf '\n=== %s ===\n' "$title"

    if [[ "$(wc -l < "$SELECTED_FILE")" -le 1 ]]; then
        echo "Пока список пуст."
    else
        tail -n +2 "$SELECTED_FILE" | nl -ba
    fi
    pause
}

edit_wishlist() {
    show_header
    if ! select_wishlist; then
        pause
        return
    fi

    local file="$SELECTED_FILE"
    local title action item number total temp
    title="$(head -n 1 "$file")"

    printf '\nРедактирование: %s\n' "$title"
    echo "1. Изменить название"
    echo "2. Добавить подарок"
    echo "3. Удалить подарок"
    echo "0. Назад"
    printf '\nВыбор: '
    read -r action

    case "$action" in
        1)
            printf 'Новое название: '
            read -r title
            if [[ -z "${title//[[:space:]]/}" ]]; then
                echo "Название не может быть пустым."
            else
                temp="$(mktemp)"
                {
                    printf '%s\n' "$title"
                    tail -n +2 "$file"
                } > "$temp"
                mv -- "$temp" "$file"
                echo "Название обновлено."
            fi
            ;;
        2)
            printf 'Название подарка: '
            read -r item
            if [[ -z "${item//[[:space:]]/}" ]]; then
                echo "Пустую запись добавить нельзя."
            else
                printf '%s\n' "$item" >> "$file"
                echo "Подарок добавлен."
            fi
            ;;
        3)
            total="$(tail -n +2 "$file" | grep -c . || true)"
            if (( total == 0 )); then
                echo "В этом вишлисте пока нет подарков."
            else
                echo "Подарки:"
                tail -n +2 "$file" | nl -ba
                printf 'Номер подарка для удаления: '
                read -r number
                if [[ "$number" =~ ^[0-9]+$ ]] &&
                   (( number >= 1 && number <= total )); then
                    temp="$(mktemp)"
                    {
                        head -n 1 "$file"
                        tail -n +2 "$file" | awk -v n="$number" 'NR != n'
                    } > "$temp"
                    mv -- "$temp" "$file"
                    echo "Подарок удалён."
                else
                    echo "Некорректный номер."
                fi
            fi
            ;;
        0) ;;
        *) echo "Нет такого пункта." ;;
    esac
    pause
}

delete_wishlist() {
    show_header
    if ! select_wishlist; then
        pause
        return
    fi

    local title confirmation
    title="$(head -n 1 "$SELECTED_FILE")"
    printf 'Удалить вишлист «%s» без возможности восстановления? (д/н): ' "$title"
    read -r confirmation

    case "$confirmation" in
        д|Д|да|Да|ДА|y|Y|yes|YES)
            rm -- "$SELECTED_FILE"
            echo "Вишлист удалён."
            ;;
        *) echo "Удаление отменено." ;;
    esac
    pause
}

search_gifts() {
    show_header
    printf 'Что найти: '
    read -r query

    if [[ -z "${query//[[:space:]]/}" ]]; then
        echo "Поисковый запрос не может быть пустым."
    else
        # grep ищет совпадения без учёта регистра; -H показывает имя файла.
        if ! grep -i -n -H -F -- "$query" "$DATA_DIR"/*.txt 2>/dev/null; then
            echo "Совпадений не найдено."
        fi
    fi
    pause
}

init_storage

while true; do
    show_header
    show_menu
    printf 'Выбор: '
    read -r choice || break

    case "$choice" in
        1) create_wishlist ;;
        2)
            show_header
            echo "=== Все вишлисты ==="
            list_wishlists
            pause
            ;;
        3) view_wishlist ;;
        4) edit_wishlist ;;
        5) delete_wishlist ;;
        6) search_gifts ;;
        0)
            echo "До встречи!"
            break
            ;;
        *) echo "Нет такого пункта меню."; pause ;;
    esac
done
