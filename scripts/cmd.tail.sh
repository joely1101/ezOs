argc=$#
all_argv="$@"
__callback="cmd_${all_argv// /_}"
for ((i=0;i<$argc;i++));do
    shfinum=$((argc-i))
    if [[ `declare -Ff $__callback` ]];then
        shift $shfinum
#        echo "call $__callback '$@'"
        $__callback "$@"
        exit 0
    else
        __callback=${__callback%_*}
#        echo "not foun try ===>$__callback"
    fi
done
if [ $# -eq 0 ];then
    help_show
else
    echo "Command not found !! Try $0 help"
fi