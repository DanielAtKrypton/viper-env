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
  local d n
  d=$PWD
  local virtualenv_directory=$1
  local full_virtualenv_directory=$d/$virtualenv_directory
  until false 
  do 
  if [[ -f $full_virtualenv_directory/bin/activate ]] ; then 
    echo Activating virtual environment ${COLOR_BRIGHT_VIOLET}$full_virtualenv_directory${COLOR_NC}
    source $full_virtualenv_directory/bin/activate
    break
  fi
    d=${d%/*}
    # d="$(dirname "$d")"
    [[ $d = *\/* ]] || break
  done
}

function automatically_activate_python_env() {
  local virtualenv_directory=.venv
  if [[ -z $VIRTUAL_ENV ]] ; then
    activate_venv $virtualenv_directory
  else
    parentdir="$(dirname ${VIRTUAL_ENV})"
    if [[ "$PWD"/ != "$parentdir"/* ]] ; then
      echo Deactivating virtual environment ${COLOR_BRIGHT_VIOLET}${VIRTUAL_ENV}${COLOR_NC}
      deactivate
      activate_venv $virtualenv_directory
    fi
  fi
}
autoload -Uz add-zsh-hook
add-zsh-hook precmd automatically_activate_python_env

eval "$(direnv hook zsh)"

__viper-env_help () {
  printf "Description:
  ${COLOR_BRIGHT_BLACK}Automatically activates and deactivates python virtualenv upon cd in and out.${COLOR_NC}

"
  printf "Dependencies:
  ${COLOR_BRIGHT_BLACK}- zsh
  - direnv
  - python${COLOR_NC}

"
  printf "Example usage:
  ${COLOR_BRIGHT_BLACK}# Create virtual environment${COLOR_NC}
  ${COLOR_GREEN}python${COLOR_NC} -m venv .venv
  ${COLOR_BRIGHT_BLACK}# Activate it${COLOR_NC}
  ${COLOR_GREEN}.${COLOR_NC} .venv/bin/activate
  ${COLOR_BRIGHT_BLACK}# Create direnv file${COLOR_NC}
  ${COLOR_YELLOW}export${COLOR_NC} VIRTUAL_ENV=venv ${COLOR_YELLOW}>${COLOR_NC} .envrc
  ${COLOR_BRIGHT_BLACK}# Allow it${COLOR_NC}
  ${COLOR_GREEN}direnv${COLOR_NC} allow .
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
