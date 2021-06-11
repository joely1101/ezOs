#!/bin/bash
MYNAME=`whoami`
git_repo=/home/jlee/git/ezOs.git/
scriptname=ezOs

install_to_system()
{
    if [ "$MYNAME" = "root" ];then
        echo "Please run as non root user"
        exit 0
    fi
    reponame=`basename $git_repo`
    #remove .git
    name=${reponame%.git}
    echo "==================================================="
    echo "This program $scriptname will install to ~/.local/$name"
    echo "==================================================="
    read -p "Do you wish to install this program[yes/no]?" yn
    if [ "$yn" != "yes" ];then
      echo "abort install"
      exit 0
    fi
    if [ -L ~/.local/bin/$scriptname ];then
        echo "==================================================="
        echo "Error!!This program seem already install"
        echo "==================================================="
        read -p "Force to install[yes/no]?" yn
        if [ "$yn" != "yes" ];then
          echo "abort install"
          exit 0
        fi
        rm -rf ~/.local/bin/$scriptname ~/.local/$name
    fi
    
    mkdir -p ~/.local/bin
    git -C ~/.local/ clone $git_repo $name
    ln -sf ~/.local/$name/$scriptname ~/.local/bin/
    find ~/.local/$name/ -name *.bash_complete | xargs -i sudo ln -sf {} /etc/bash_completion.d/;
    echo "Install success!!"
}
install_to_system
