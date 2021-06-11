#!/bin/bash
[ "$BUILD_BOARD" = "" ] && echo "do 'source setup.env board_name' first" && exit
fbdir=flexbuild
export FBDIR=$(pwd)/$fbdir/
export PATH="$FBDIR:$FBDIR/tools:$PATH"
. ${BUILD_BOARD}/hkbuild.cfg
cando_before_source=""

HK_ARCH=arm64

if [ ! -f /etc/sudoers.d/$USER ];then
    echo "setup $USER sudo without password"
    echo "$USER ALL = (root) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$USER
fi
if [ ! -f /proc/sys/fs/binfmt_misc/qemu-aarch64 ];then
    echo "need mount arm64 qemu"
    #docker run --rm --privileged multiarch/qemu-user-static:register --reset
    sudo mount binfmt_misc -t binfmt_misc /proc/sys/fs/binfmt_misc
fi

cat /proc/sys/fs/binfmt_misc/qemu-aarch64 | grep -q enabled

if [ $? -ne 0 ];then
   echo "please do qemu-user-static reset on host by command"
   echo "docker run --rm --privileged multiarch/qemu-user-static:register --reset"
   exit 99
fi	

fb_com_argv="-m $HK_MACHINE -a $HK_ARCH -b $HK_BOOTTYPE"

declare -A HELP
debuglevel=${debuglevel:-2}
do_cmd()
{
    if [ "$debuglevel" = "1" ];then
	echo "cmd:$@"
	eval "$@ 1>/dev/null"
	if [ $? != 0 ];then
		echo "Error!!"
		exit 99
	fi
	echo "done..."

    elif [ "$debuglevel" = "2" ];then
	echo "cmd:$@"
	eval $@
	 if [ $? != 0 ];then
            echo "Error!!"
            exit 99
         fi
	echo "done..."
    else
        eval $@
	 if [ $? != 0 ];then
             echo "Error!!"
             exit 99
         fi
    fi
}
rename_fn()
{
  local a
  a="$(declare -f "$1")" &&
  eval "function $2 ${a#*"()"}" &&
  unset -f "$1";
}

help_add()
{
    HELP["$1"]="$2"
}

get_flexbuild()
{
  if [ -d $fbdir ];then
    do_cmd "git -C $fbdir pull"
  else
    do_cmd "git clone $HK_FLEXBUILD_GIT $fbdir"
  fi
  #do fb config link
  [ -f /etc/.lsdktoolinstalled ] &&  mkdir -p ${fbdir}/logs/ && touch ${fbdir}/logs/.deppkgdone
  do_cmd "ln -sf ${PWD}/${BUILD_BOARD}/flexbuild.cfg ${fbdir}/configs/build_custom.cfg"
  if [ -f ${PWD}/${BUILD_BOARD}/manifest ];then
       do_cmd "ln -sf ${PWD}/${BUILD_BOARD}/manifest ${fbdir}/configs/board/${HK_MACHINE}/manifest"
  fi

}


get_linux()
{
    if [ -f ${FBDIR}/build/linux/.linuxconfigdone ] ;then
        echo "Kernel config already done"
        return
    fi

    do_cmd "flex-builder -i repo-fetch -B linux"
    #do kernel config
    mkdir -p ${FBDIR}/build/linux
    do_cmd "ln -sf ${BUILD_TOP}/${BUILD_BOARD}/kernel.conf ${fbdir}/packages/linux/linux/arch/arm64/configs/kernel_defconfig"
    (
      cd ${BUILD_BOARD}/dts/;
      find -name *.dts | xargs -i ln -sf ${PWD}/{} ${BUILD_TOP}/${fbdir}/packages/linux/linux/arch/arm64/boot/dts/{};
    )
    touch ${FBDIR}/build/linux/.linuxconfigdone
    #echo -n "hk6100" > ${BUILD_TOP}/${fbdir}/packages/linux/linux/.scmversion
}

cb_source()
{
    get_flexbuild
    #get_linux
    do_cmd "mkdir -p ${fbdir}/build/images"
    do_cmd "rm -f images;ln -sf ${fbdir}/build/images images"
    do_cmd "touch .sourcedone"
}
cando_before_source+=" source"
cb_clean_source()
{
    #do_cmd "sudo cp images images.${BUILD_BOARD} -r -L"
    echo "remove all source, please wait!!"
    do_cmd "sudo rm -rf ${fbdir} .sourcedone"
}

help_add "source" "source - download source"

cb_kernel()
{
    echo "build kernel"
    echo "command : flex-builder -c linux -a $HK_ARCH -m $HK_MACHINE"
    get_linux
    do_cmd "flex-builder -c linux $fb_com_argv"
}
cb_clean_kernel()
{
    do_cmd "rm -rf ${FBDIR}/build/linux ${FBDIR}/build/images/{*.itb,linux_*,lib_modules_*}"
}
help_add "kernel" "kernel - build linux kernel"

cb_uefi()
{
    echo "build uefi"
    ( flex-builder -c uefi $fb_com_argv )
    mkdir -p images/uefi
    find $fbdir/packages/firmware/uefi/Build/ -name *.Cap | xargs -i cp {} images/uefi/ 
    find $fbdir/packages/firmware/uefi/Build/ -name CapsuleApp.efi | xargs -i cp {} images/uefi/
}

cb_clean_uefi()
{
   echo "uefi clean:rm -rf ${FBDIR}/packages/firmware/uefi/Build/" 
   do_cmd "rm -rf ${FBDIR}/packages/firmware/uefi/Build/"
   do_cmd "rm -rf ${FBDIR}flexbuild/build/firmware/uefi"
   echo "done"
}
help_add "uefi" "uefi - build uefi only for develop"

cb_uboot()
{
    echo "build uboot"
    do_cmd "flex-builder -c uboot $fb_com_argv"
    mkdir images/uboot
}

help_add "uboot - build uboot only for develop"


cb_atf()
{
    [ ! -z "$1" ] && boot=$1 || boot=$HK_LOADER
    [ "$boot" = "uefi" ] && cb_uefi
    do_cmd "flex-builder -c atf -B $boot $fb_com_argv"
    mkdir -p images/atf/
    do_cmd "cp $fbdir/build/firmware/atf/$HK_MACHINE/* images/atf/ -a"
}
cb_clean_atf()
{
    cb_clean_uefi
    do_cmd "make -C ${FBDIR}/packages/firmware/atf clean"
    do_cmd "sudo rm -rf ${FBDIR}/build/firmware/atf"

}
help_add "atf" "atf [uefi|uboot] - build atf with uboot or uefi,default $HK_LOADER"

cb_firmware()
{
    [ ! -z "$1" ] && boot=$1 || boot=$HK_LOADER
    get_linux
    do_cmd "flex-builder -i mkfw $fb_com_argv -B $boot"

    #cp $fbdir/build/images/firmware_${HK_MACHINE}_${HK_LOADER}_${HK_BOOTTYPE}boot.img images/firmware_${BUILD_BOARD}_${HK_LOADER}_${HK_BOOTTYPE}boot.img
#    flexbuild_<version>/build/images/firmware_<machine>_uboot_<boottype>boot.img
}
cb_clean_firmware()
{
    do_cmd "rm -rf ${FBDIR}/build/firmware"
}
help_add "fw" "firmware [uefi|uboot] - build firmware include atf,dtb,qe,uboot/uefi, default $HK_LOADER"

cb_ubuntu()
{
     distro=${HK_UBUNTU_DISTRO:-main}
     [ "$1" != "" ] && vv="ubuntu:$1" || vv="ubuntu:${distro}"
     #follow config lite/mate/main
     #vv=ubuntu
     cb_kernel
     do_cmd "flex-builder -i mkrfs -r $vv -a ${HK_ARCH}"
     do_cmd "flex-builder -i merge-component -r $vv -a ${HK_ARCH}"
     do_cmd "flex-builder -i packrfs -r $vv -a ${HK_ARCH}"
     do_cmd "flex-builder -i mkbootpartition -a ${HK_ARCH}"

}
cb_clean_ubuntu()
{
    do_cmd "rm -rf ${FBDIR}/build/rfs/*ubuntu*"
}
help_add "ubuntu" "ubuntu - build ubuntu distro"
cb_centos()
{
    cb_kernel
    do_cmd "flex-builder -i mkrfs -r centos $fb_com_argv"
    do_cmd "flex-builder -i merge-component -r centos $fb_com_argv"
    do_cmd "flex-builder -i packrfs -r centos $fb_com_argv"
    do_cmd "flex-builder -i mkbootpartition -a ${HK_ARCH}"
}
cb_clean_centos()
{
    do_cmd "rm -rf ${FBDIR}/build/rfs/*cnetos*"
}
help_add "centos" "centos - build centos distro"
cando_before_source+=" clean"
cb_mkbootpartition()
{
    do_cmd "flex-builder -i mkbootpartition -a ${HK_ARCH}"
    ls ${FBDIR}/build/images/*.itb
}
help_add "mkbootpartition" "mkbootpartition - make partition that include linux kernel and dtbs."

cb_help()
{
    echo "Valid agument:"
    for key in ${!HELP[@]}
    do
        if [ "${HELP[$key]}" != "" ];then
	    echo " ${HELP[$key]}"
	fi
    done    
    echo "done"
}
cando_before_source+=" help"
cb_show()
{
    echo "BUILD_BOARD=$BUILD_BOARD"
    echo "BUILD_DIR=$BUILD_TOP"
    echo "UBUNTU_DISTRO=$HK_UBUNTU_DISTRO"
    echo "MACHIME=$HK_MACHINE"
    echo "BOOTLOADER=$HK_LOADER"
    echo "BOOTTYPE=$HK_BOOTTYPE"
}
help_add "show" "show - show config"
cando_before_source+=" show"
cb_cmd()
{
    echo "flex-builder $@ $fb_com_argv"
    flex-builder $@ $fb_com_argv
}
help_add "cmd" "cmd - pass argument to flex-build. ex: -i mkfw -a arm64 "

if [ -f $BUILD_BOARD/cmd.overwrite.sh ];then
	. $BUILD_BOARD/cmd.overwrite.sh
fi

cb_all()
{
    cb_kernel
    cb_firmware uefi
    cb_firmware uboot
    cb_ubuntu
}
help_add "all" "all - build all packages!!"
cb_full()
{
    cb_source
    cb_all
}
cando_before_source+=" full"
help_add "full" "full - do every in one command!!"

if [ ! -f .sourcedone ] && [[ $cando_before_source != *" $1"* ]] ;then
	echo "please do 'hkbuild source' or '$0 source' first."
	exit 0
fi

set -e

argc=$#
all_argv="$@"
__callback="cb_${all_argv// /_}"
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
    cb_help
else
    echo "Command not found !! Try hkbuild help"
fi
#cb_help
