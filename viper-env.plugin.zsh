# Colors based on:
# https://www.lihaoyi.com/post/BuildyourownCommandLinewithANSIescapecodes.html#16-colors
export COLOR_BLACK='\033[0;30m'
export COLOR_BRIGHT_BLACK='\u001b[30;1m'
export COLOR_RED='\033[0;31m'
export COLOR_BRIGHT_RED='\u001b[31;1m'
export COLOR_GREEN='\033[0;32m'
export COLOR_BRIGHT_GREEN='\u001b[32;1m'
export COLOR_YELLOW='\033[0;33m'
export COLOR_BRIGHT_YELLOW='\u001b[33;1m'
export COLOR_BLUE='\033[0;34m'
export COLOR_BRIGHT_BLUE='\u001b[34;1m'
export COLOR_VIOLET='\033[0;35m'
export COLOR_BRIGHT_VIOLET='\u001b[35;1m'
export COLOR_CYAN='\033[0;36m'
export COLOR_BRIGHT_CYAN='\u001b[36;1m'
export COLOR_WHITE='\033[0;37m'
export COLOR_NC='\033[0m' # No Color

function activate_venv() {  
  local virtualenv_directory=$1
  local d=$2
  local relative_venv_path=$3
  until false 
  do 
    local full_virtualenv_directory=$d/$virtualenv_directory
    if [[ -f $full_virtualenv_directory/bin/activate ]] ; then
      if [[ -f $full_virtualenv_directory/bin/python ]] ; then
        echo Activating virtual environment ${COLOR_BRIGHT_VIOLET}$relative_venv_path${COLOR_NC}
        source $full_virtualenv_directory/bin/activate
        break
      fi
    fi
    d=${d%/*}
    # d="$(dirname "$d")"
    [[ $d = *\/* ]] || break
  done
}

function get_venv_path(){
  echo "$(basename "$1")/$2"
}

function automatically_activate_python_env() {
  local current_dir="$PWD" 
  local virtualenv_directory=.venv
  local venv_var="$VIRTUAL_ENV"
  if [[ -z $venv_var ]] ; then
    local relative_activating_venv_path="$(get_venv_path $current_dir $virtualenv_directory)"
    activate_venv $virtualenv_directory $current_dir $relative_activating_venv_path
  else
    parentdir="$(dirname $venv_var)"
    if [[ $current_dir/ != $parentdir/* ]] ; then
      local deactivating_relative_venv_path="$(realpath --relative-to=$current_dir $venv_var)"
      echo Deactivating virtual environment ${COLOR_BRIGHT_VIOLET}$deactivating_relative_venv_path${COLOR_NC}
      deactivate
      local relative_activating_venv_path="$(get_venv_path $current_dir $virtualenv_directory)"
      activate_venv $virtualenv_directory $current_dir $relative_activating_venv_path
    fi
  fi
}
autoload -Uz add-zsh-hook
add-zsh-hook precmd automatically_activate_python_env

__viper-env_help () {
  printf "Description:
  ${COLOR_BRIGHT_BLACK}Automatically activates and deactivates python virtualenv upon cd in and out.${COLOR_NC}

"
  printf "Dependencies:
  ${COLOR_BRIGHT_BLACK}- zsh
  - python${COLOR_NC}

"
  printf "Example usage:
  ${COLOR_BRIGHT_BLACK}# Create virtual environment${COLOR_NC}
  ${COLOR_GREEN}python${COLOR_NC} -m venv .venv
  ${COLOR_BRIGHT_BLACK}# Save current dir${COLOR_NC}
  current_dir=${COLOR_VIOLET}\$(${COLOR_GREEN}basename ${COLOR_YELLOW}"${COLOR_NC}\$PWD${COLOR_YELLOW}"${COLOR_VIOLET})${COLOR_NC}
  ${COLOR_BRIGHT_BLACK}# Exit current directory${COLOR_NC}
  ${COLOR_GREEN}cd${COLOR_NC} ..
  ${COLOR_BRIGHT_BLACK}# Reenter it${COLOR_NC}
  ${COLOR_GREEN}cd${COLOR_NC} \$current_dir
"
}

viper-env_runner() {
  if [[ $@ == "help" || $@ == "h" ]]; then 
    __viper-env_help
  #elif [[ $@ == "something" || $@ == "alias" ]]; then 
  fi
}

alias viper-env='viper-env_runner'
