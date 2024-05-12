#!/bin/bash


function main()
{
    cmd=$1
    case "$1" in
        pushf)
            git add . && git commit --amend --no-edit && git push -f
            ;;
    esac

    return 0
}

main "$@"
exit $?
