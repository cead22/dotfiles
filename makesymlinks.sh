#!/bin/bash
############################
# .make.sh
# This script creates symlinks from the home directory to any desired dotfiles in ~/dotfiles
############################

# dotfiles directory
dir=~/dotfiles

# list of files to symlink in homedir
files="bashrc vimrc gitconfig bash_profile aliases git-completion.bash"

# change to the dotfiles directory
echo -n "Changing to the $dir directory ..."
cd $dir
echo "done"

# move any existing dotfiles in homedir to dotfiles_old directory, then create symlinks from the homedir to any files in the ~/dotfiles directory specified in $files
printf '\e[1;34m%-6s\e[m' "Removing existing dotfiles"
printf "\n"
for file in $files
do
    rm ~/.$file
done

printf '\e[1;34m%-6s\e[m' "Creating symlink to files in home directory"
printf "\n"
for file in $files
do
    printf "ln -s $dir/$file  ~/.$file\n"
    ln -s $dir/$file ~/.$file
done

# nvim config: symlink ~/dotfiles/nvim -> ~/.config/nvim
printf '\e[1;34m%-6s\e[m' "Setting up nvim config"
printf "\n"
mkdir -p ~/.config
if [ -e ~/.config/nvim ]; then
    rm -rf ~/.config/nvim
fi
printf "ln -s $dir/nvim ~/.config/nvim\n"
ln -s $dir/nvim ~/.config/nvim
