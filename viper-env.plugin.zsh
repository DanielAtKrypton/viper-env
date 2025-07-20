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

# This variable will hold the path of the environment managed by this script.
# This prevents us from deactivating environments managed by other tools (e.g., conda, poetry).
_VIPER_ENV_MANAGED_PATH=""

# Discovers a virtual environment by searching upwards from the current directory.
# This function is the core of the discovery logic.
__viper-env_discover_venv() {
  # Use `emulate` to ensure a predictable environment and `dotglob` to find hidden venvs.
  emulate -L zsh
  setopt local_options dotglob
  local search_dir="$PWD"
  # Loop upwards from the current directory to the root.
  while :; do
    # Pattern 1: Check if the search_dir itself is a venv root.
    if [[ -f "$search_dir/bin/activate" ]]; then
      echo "$search_dir"
      return 0
    fi

    # Pattern 2: Check for a venv in an immediate subdirectory.
    # The `(N[1])` glob qualifier finds the first match and prevents errors if none exist.
    local activate_script=($search_dir/*/bin/activate(N[1]))
    if [[ -n "$activate_script" ]]; then
      echo "$(dirname $(dirname "$activate_script"))"
      return 0
    fi

    # Exit if we've reached the root directory, otherwise, go up one level.
    [[ "$search_dir" == "/" ]] && break
    search_dir=$(dirname "$search_dir")
  done
  return 1
}

function automatically_activate_python_env() {
  local local_venv_path
  local_venv_path=$(__viper-env_discover_venv)

  # 1. Handle activation if a local environment was found.
  if [[ -n "$local_venv_path" ]]; then
    # If we are in a directory with a venv and no venv is active, or the wrong one is active...
    if [[ -z "$VIRTUAL_ENV" || "$VIRTUAL_ENV" != "$local_venv_path" ]]; then
      # If any virtual environment is active (managed or not), deactivate it first to make way for the local one.
      if [[ -n "$VIRTUAL_ENV" ]]; then
        if [[ -z "$VIPER_ENV_QUIET" ]]; then
          local deactivating_path
          deactivating_path=$(realpath --relative-to="$PWD" "$VIRTUAL_ENV" 2>/dev/null || basename "$VIRTUAL_ENV")
          echo "Deactivating existing environment ${COLOR_BRIGHT_VIOLET}$deactivating_path${COLOR_NC}"
        fi
        deactivate
        # Unset our managed path tracker since we just deactivated something.
        _VIPER_ENV_MANAGED_PATH=""
      fi

      # Activate the local venv.
      if [[ -z "$VIPER_ENV_QUIET" ]]; then
        echo "Activating virtual environment ${COLOR_BRIGHT_VIOLET}$(basename "$local_venv_path")${COLOR_NC}"
      fi
      source "$local_venv_path/bin/activate"
      # Mark this venv as managed by us.
      _VIPER_ENV_MANAGED_PATH="$VIRTUAL_ENV"
    fi
  # 2. Handle deactivation if no local environment was found.
  else
    # If we are in a directory with NO venv, but a viper-env managed venv is active...
    if [[ -n "$VIRTUAL_ENV" && "$VIRTUAL_ENV" == "$_VIPER_ENV_MANAGED_PATH" ]]; then
      # ...deactivate it.
      if [[ -z "$VIPER_ENV_QUIET" ]]; then
        # Use GNU realpath for a nicer relative path if available, otherwise fallback to basename.
        # The `2>/dev/null` handles cases where `realpath` exists but doesn't support `--relative-to` (e.g., on macOS).
        local deactivating_path
        deactivating_path=$(realpath --relative-to="$PWD" "$_VIPER_ENV_MANAGED_PATH" 2>/dev/null || basename "$_VIPER_ENV_MANAGED_PATH")
        echo "Deactivating virtual environment ${COLOR_BRIGHT_VIOLET}$deactivating_path${COLOR_NC}"
      fi
      deactivate
      _VIPER_ENV_MANAGED_PATH=""
    fi
  fi
}
autoload -Uz add-zsh-hook
# The 'chpwd' hook runs whenever the current directory is changed, which is
# the correct and most efficient trigger for this functionality.
add-zsh-hook chpwd automatically_activate_python_env

# Provides the help text for the plugin.
# Using a HEREDOC for a cleaner, multi-line string.
__viper-env_help() {
  cat <<EOF
Description:
  ${COLOR_BRIGHT_BLACK}Automatically activates and deactivates python virtualenv upon cd in and out.${COLOR_NC}

Dependencies:
  ${COLOR_BRIGHT_BLACK}- zsh
  - python${COLOR_NC}

Example usage:
  ${COLOR_BRIGHT_BLACK}# Create new project folder${COLOR_NC}
  ${COLOR_BRIGHT_GREEN}mkdir${COLOR_NC} new_project
  ${COLOR_BRIGHT_BLACK}# Create virtual environment${COLOR_NC}
  ${COLOR_BRIGHT_GREEN}python${COLOR_NC} -m venv .venv
  ${COLOR_BRIGHT_BLACK}# Exit current directory${COLOR_NC}
  ${COLOR_BRIGHT_GREEN}cd${COLOR_NC} ..
  ${COLOR_BRIGHT_BLACK}# Reenter it${COLOR_NC}
  ${COLOR_BRIGHT_GREEN}cd${COLOR_NC} new_project
EOF
}

# We unalias first to prevent "defining function based on alias" errors
# if the script is sourced multiple times in the same session.
unalias viper-env 2>/dev/null
viper-env() {
  case "$1" in
    "" | "h" | "help")
      __viper-env_help
      ;;
    "list")
      if [[ -n "$VIRTUAL_ENV" ]]; then
        printf "Active virtual environment: ${COLOR_BRIGHT_GREEN}%s${COLOR_NC}\n" "$VIRTUAL_ENV"
      else
        printf "No virtual environment is currently active.\n"
      fi
      ;;
    "status")
      printf "Viper-Env Status:\n"
      printf -- "-----------------\n"
      printf "PWD: %s\n" "$PWD"
      if [[ -n "$VIRTUAL_ENV" ]]; then
        printf "VIRTUAL_ENV: ${COLOR_BRIGHT_GREEN}%s${COLOR_NC}\n" "$VIRTUAL_ENV"
      else
        printf "VIRTUAL_ENV: ${COLOR_RED}Not set${COLOR_NC}\n"
      fi
      if [[ -n "$_VIPER_ENV_MANAGED_PATH" ]]; then
        printf "_VIPER_ENV_MANAGED_PATH: ${COLOR_BRIGHT_GREEN}%s${COLOR_NC}\n" "$_VIPER_ENV_MANAGED_PATH"
      else
        printf "_VIPER_ENV_MANAGED_PATH: ${COLOR_RED}Not set${COLOR_NC}\n"
      fi

      local discovered_path
      discovered_path=$(__viper-env_discover_venv)
      [[ -n "$discovered_path" ]] && printf "Discovered venv: ${COLOR_BRIGHT_CYAN}%s${COLOR_NC}\n" "$discovered_path" || printf "Discovered venv: None\n"
      ;;
    *)
      printf "${COLOR_RED}Error: Unknown command '%s'${COLOR_NC}\n\n" "$1" >&2
      __viper-env_help
      return 1
      ;;
  esac
}
