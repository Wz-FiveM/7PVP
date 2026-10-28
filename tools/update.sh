#!/usr/bin/env bash
# Côté VPS, dans le dossier de la resource (clone git de github.com/Wz-FiveM/7PVP).
# Lancé par deploy.bat, ou à la main : bash tools/update.sh [--apercu | --restaurer]
#   (rien)        git pull, puis recompile l'interface si web/ a changé
#   --apercu      liste les commits et fichiers qui arriveraient, sans rien modifier
#   --restaurer   revient à la version d'avant la dernière mise à jour (relancer remonte encore)
set -euo pipefail

# Versions remplacées par les mises à jour, une par ligne (la dernière en bas)
HISTORY=.git/7pvp-versions

# Recompile web/build si web/ a changé entre deux versions (ou si le build manque)
build_ui() {
    local from=$1 to=$2
    if [[ -f web/build/index.html ]] && git diff --quiet "$from" "$to" -- web/; then
        return
    fi
    echo "Compilation de l'interface (web/)..."
    if [[ ! -d web/node_modules ]] || ! git diff --quiet "$from" "$to" -- web/package.json web/package-lock.json; then
        npm --prefix web ci --no-audit --no-fund --loglevel=error
    fi
    npm --prefix web run build --silent
}

summary() {
    local from=$1 to=$2
    git log --oneline --no-decorate "$from..$to" | sed 's/^/  /'
    git diff --stat=100 "$from" "$to" | tail -1
}

update() {
    if [[ -n $(git status --porcelain --untracked-files=no) ]]; then
        echo "Des fichiers ont été modifiés directement sur le VPS : fais-le dans le dépôt, ou annule avec « git checkout -- . »." >&2
        git status --short --untracked-files=no >&2
        exit 1
    fi

    git fetch --quiet
    local before after
    before=$(git rev-parse HEAD)
    after=$(git rev-parse '@{u}')

    if [[ $before == "$after" ]]; then
        echo "Déjà à jour ($(git log -1 --format='%h %s'))."
        if [[ ${1:-} != --apercu ]]; then build_ui "$before" "$after"; fi
        return
    fi
    if ! git merge-base --is-ancestor "$before" "$after"; then
        echo "La version du VPS n'est pas dans l'historique de GitHub (restauration ?) : elle est remplacée par celle de GitHub."
    fi

    if [[ ${1:-} == --apercu ]]; then
        echo "Aperçu, rien n'est modifié :"
        summary "$before" "$after"
        return
    fi

    summary "$before" "$after"
    git reset --quiet --hard "$after"
    echo "$before" >>"$HISTORY"
    build_ui "$before" "$after"
    echo "À jour : $(git log -1 --format='%h %s')"
}

restore() {
    if [[ ! -s $HISTORY ]]; then
        echo "Aucune version précédente enregistrée." >&2
        exit 1
    fi
    local current previous
    current=$(git rev-parse HEAD)
    previous=$(tail -1 "$HISTORY")
    sed -i '$d' "$HISTORY"

    git reset --quiet --hard "$previous"
    build_ui "$current" "$previous"
    echo "Restauré : $(git log -1 --format='%h %s'). La prochaine mise à jour reprendra la version de GitHub."
}

main() {
    cd "$(dirname "$0")/.."
    case ${1:-} in
        '' | --apercu) update "$@" ;;
        --restaurer) restore ;;
        *) echo "Usage : $0 [--apercu | --restaurer]" >&2; exit 1 ;;
    esac
}

# Tout est lu avant de s'exécuter : le pull peut remplacer ce fichier sans gêner la suite
main "$@"
exit
