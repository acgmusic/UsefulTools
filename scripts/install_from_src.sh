#!/bin/bash
g_script_path=$PWD

set -u

function abort() {
    printf "%s\n" "$@" >&2
    exit 1
}

# string formatters
if [[ -t 1 ]]
then
    function tty_escape() { printf "\033[%sm" "$1"; }
else
    function tty_escape() { :; }
fi
function tty_mkbold() { tty_escape "1;$1"; }

tty_underline="$(tty_escape "4;39")"
tty_blue="$(tty_mkbold 34)"
tty_yellow="$(tty_mkbold 33)"
tty_red="$(tty_mkbold 31)"
tty_bold="$(tty_mkbold 39)"
tty_reset="$(tty_escape 0)"

function shell_join() {
    local arg
    printf "%s" "$1"
    shift
    for arg in "$@"
    do
        printf " "
        printf "%s" "${arg// /\ }"
    done
}

function chomp() {
    printf "%s" "${1/"$'\n'"/}"
}

function ohai() {
    printf "${tty_blue}==>${tty_bold} %s${tty_reset}\n" "$(shell_join "$@")"
}

function warn() {
    printf "${tty_yellow}Warning${tty_reset}: %s\n" "$(chomp "$1")" >&2
}

function error() {
    printf "${tty_red}Warning${tty_reset}: %s\n" "$(chomp "$1")" >&2
}

function execute() {
    if ! "$@"
    then
        abort "$(printf "Failed during: %s" "$(shell_join "$@")")"
    fi
}

function usage() {
    cat <<EOS
Usage:
    -h, --help       Display this message.
EOS
    exit "${1:-0}"
}

function getc() {
    local save_state
    save_state="$(/bin/stty -g)"
    /bin/stty raw -echo
    IFS='' read -r -n 1 -d '' "$@"
    /bin/stty "${save_state}"
}

function wait_for_user() {
    local c
    echo
    echo "Press ${tty_bold}RETURN${tty_reset}/${tty_bold}ENTER${tty_reset} to continue or any other key to abort:"
    getc c
    # we test for \r and \n because some stuff does \r instead
    if ! [[ "${c}" == $'\r' || "${c}" == $'\n' ]]
    then
        exit 1
    fi
}

function version_gt() {
    ver_list1=($(tr "." " " <<< "$1"))
    ver_list2=($(tr "." " " <<< "$2"))
    if [ ${#ver_list1[@]} -ne ${#ver_list2[@]} ]
    then
        abort "cannot compare versions with different lenth: $1, $2"
    fi
    for ((i=0; i<${#ver_list1[@]}; i++))
    do
        if [ ${ver_list1[$i]} -gt ${ver_list2[$i]} ]
        then
            return 0
        elif [ ${ver_list1[$i]} -lt ${ver_list2[$i]} ]
        then
            return 1
        fi
    done
    return 1 
}

function demo_progress()
{
    spin=('\' '|' '/' '-')
    # 定义进度条的长度
    bar_length=80
    # 定义总的循环次数
    total_iterations=80
    # 循环打印进度条
    for ((i=0; i<=total_iterations; i++)); do
        # 计算进度百分比
        percentage=$((i * 100 / total_iterations))
        # 计算当前旋转线的形态
        spin_index=$((i % 4))
        spin_char=${spin[spin_index]}
        # 计算进度条的长度
        progress=$((i * bar_length / total_iterations))
        # 计算剩余空白长度
        remaining=$((bar_length - progress))
        # 打印进度条
        printf "\r[%-${progress}s%-${remaining}s] %d%% %s" "$(printf '#%.0s' $(seq 1 $progress))" "" "$percentage" "$spin_char"
        sleep 0.1
    done

    echo
}

function auto_install()
{
    if [[ -z "${LINUX_DL_PKG}" ]]; then
        while true;do
            yum --version &>/dev/null && LINUX_DL_PKG=yum && break
            apt-get --version &>/dev/null && LINUX_DL_PKG=apt-get && break
            abort "cannot find yum/apt-get on this system"
        done
    fi
    $LINUX_DL_PKG -y install "$@"
    return $?
}

function get_ver3()
{
    get_ver3_ret=$("$1" --version | grep "$1" | grep -oP "\d+\.\d+\.\d+")
    return $?
}

function install_gcc()
{
    if [ $# -eq 0 ];then
        warn "you must input a gcc version"
        ohai "show all version from http://ftp.gnu.org/gnu/gcc/ ..."
        execute curl -s http://ftp.gnu.org/gnu/gcc/ | grep -oP "(?<=gcc\-)[\d\.]+\d" | uniq | tr "\n" " "
        return 1
    fi

    gcc_ver="$1"
    if ! get_ver3 gcc
    then
        warn "cannot find gcc, do you want install it from yum?"
        wait_for_user
        auto_install gcc || return 1
        get_ver3 gcc || return 1
    fi

    if [ "$gcc_ver" == "${get_ver3_ret}" ];then
        echo "version is same, no need upgrade"
        return 0
    fi

    if version_gt "${get_ver3_ret}" "$gcc_ver"
    then
        warn "current version is ${get_ver3_ret}, no you want to degrade to ${gcc_ver}?"
        wait_for_user
    fi

    execute wget --content-disposition https://ftp.gnu.org/gnu/gcc/gcc-${gcc_ver}/gcc-${gcc_ver}.tar.xz


}

function main()
{
    target=${1:-help}
    shift 1
    case $target in
        gcc)
            install_gcc "$@"
            ;;
        test)
            # demo_progress
            version_gt 1.2.3 2.1.2.2
            echo $?
            ;;
        help|--help|-h)
            usage 0
            ;;
        *)
            ;;
    esac
}

main "$@"
exit $?
