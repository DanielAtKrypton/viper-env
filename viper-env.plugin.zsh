# Colors based on:
# https://www.lihaoyi.com/post/BuildyourownCommandLinewithANSIescapecodes.html#16-colors
export COLOR_BLACK=$'\033[0;30m'
export COLOR_BRIGHT_BLACK=$'\u001b[30;1m'
export COLOR_RED=$'\033[0;31m'
export COLOR_BRIGHT_RED=$'\u001b[31;1m'
export COLOR_GREEN=$'\033[0;32m'
export COLOR_BRIGHT_GREEN=$'\u001b[32;1m'
export COLOR_YELLOW=$'\033[0;33m'
export COLOR_BRIGHT_YELLOW=$'\u001b[33;1m'
export COLOR_BLUE=$'\033[0;34m'
export COLOR_BRIGHT_BLUE=$'\u001b[34;1m'
export COLOR_VIOLET=$'\033[0;35m'
export COLOR_BRIGHT_VIOLET=$'\u001b[35;1m'
export COLOR_CYAN=$'\033[0;36m'
export COLOR_BRIGHT_CYAN=$'\u001b[36;1m'
export COLOR_WHITE=$'\033[0;37m'
export COLOR_NC=$'\033[0m' # No Color

# Configuration file for persistent settings.
_VIPER_ENV_CONFIG_FILE="$HOME/.viper-env.conf"
_VIPER_ENV_VERSION="v1.1.0"

# This variable will hold the path of the environment managed by this script.
# This prevents us from deactivating environments managed by other tools (e.g., conda, poetry).
_VIPER_ENV_MANAGED_PATH=""

# This variable tracks if a user manually runs `deactivate` in a directory,
# to prevent immediate re-activation by the precmd hook.
# These variables prevent the same warning from being printed multiple times.
_VIPER_ENV_LAST_WARNING_KEY=""
_VIPER_ENV_LAST_PWD="$PWD"

# Discovers a virtual environment by searching upwards from the current directory.
# This function is the core of the discovery logic.
__viper-env_discover_venv() {
  # Use `emulate` to ensure a predictable environment and `dotglob` to find hidden venvs.
  emulate -L zsh
  setopt local_options dotglob
  local search_dir="$PWD"
  # Loop upwards from the current directory to the root.
  while :; do
    # Mode 1: Semi-automatic via `.viper-env` file
    # This allows using virtual environments located outside the project directory.
    if [[ -f "$search_dir/.viper-env" ]]; then
      local external_venv_path
      # Read the path from the file, handling potential trailing newlines.
      # Using 'read -r' is more robust for reading a single line from a file.
      read -r external_venv_path < "$search_dir/.viper-env"
      # Remove trailing carriage return if file has Windows line endings.
      external_venv_path=${external_venv_path%$'\r'}
      # Perform tilde expansion on the path to support paths like ~/.virtualenvs/...
      external_venv_path=${(~)external_venv_path}

      # The path in the file can be either the venv root or the full path to the activate script.
      # This logic handles both cases robustly.
      local venv_root_path=""
      if [[ "$external_venv_path" == */bin/activate && -f "$external_venv_path" ]]; then
        # Case 1: Path is the full path to the activate script.
        venv_root_path="$(dirname "$(dirname "$external_venv_path")")"
      elif [[ -f "$external_venv_path/bin/activate" ]]; then
        # Case 2: Path is the root of the virtual environment.
        venv_root_path="$external_venv_path"
      fi

      if [[ -n "$venv_root_path" ]]; then
        echo "$venv_root_path"
        return 0
      else
        # If the file exists but the path is invalid, print a warning to stderr
        # and continue searching. This prevents the script from failing silently.
        local warning_key="$search_dir:$external_venv_path"
        if [[ "$_VIPER_ENV_LAST_WARNING_KEY" != "$warning_key" ]]; then
          printf "${COLOR_YELLOW}viper-env: Warning: Found '%s' but the path inside ('%s') is not a valid virtual environment. Ignoring.${COLOR_NC}\n" "$search_dir/.viper-env" "$external_venv_path" >&2
          _VIPER_ENV_LAST_WARNING_KEY="$warning_key"
        fi
      fi
    fi

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

__viper-env_activate() {
  local venv_path="$1"
  if [[ -z "$venv_path" ]]; then return 1; fi

  if [[ -z "$VIPER_ENV_QUIET" ]]; then
    # Use OLDPWD for cd, but PWD for venv creation. Fallback to PWD if OLDPWD is not set.
    local relative_to_dir="${OLDPWD:-$PWD}"
    local activating_path
    activating_path=$(realpath --relative-to="$relative_to_dir" "$venv_path" 2>/dev/null || basename "$venv_path")
    echo "Activating virtual environment ${COLOR_BRIGHT_VIOLET}$activating_path${COLOR_NC}"
  fi
  source "$venv_path/bin/activate"
  _VIPER_ENV_MANAGED_PATH="$VIRTUAL_ENV"
}

__viper-env_deactivate() {
  local reason="$1"
  local deactivating_path
  deactivating_path=$(realpath --relative-to="$PWD" "$_VIPER_ENV_MANAGED_PATH" 2>/dev/null || basename "$_VIPER_ENV_MANAGED_PATH")

  if [[ -z "$VIPER_ENV_QUIET" ]]; then
    if [[ "$reason" == "defunct" ]]; then
      echo "Deactivating defunct virtual environment ${COLOR_BRIGHT_VIOLET}$deactivating_path${COLOR_NC}"
    else
      echo "Deactivating virtual environment ${COLOR_BRIGHT_VIOLET}$deactivating_path${COLOR_NC}"
    fi
  fi

  # Manually perform the core actions of a venv's 'deactivate' function.
  # This is more robust than relying on an external function that might be
  # missing or interfered with by other plugins, which causes the
  # 'command not found: deactivate' error.

  # 1. Restore the original PATH. The 'activate' script saves this for us.
  if [[ -n "$_OLD_VIRTUAL_PATH" ]]; then
    export PATH="$_OLD_VIRTUAL_PATH"
    unset _OLD_VIRTUAL_PATH
  fi

  # 2. Unset the VIRTUAL_ENV variable. This is the most critical step.
  unset VIRTUAL_ENV
  _VIPER_ENV_MANAGED_PATH=""
}

# This is the central logic function that synchronizes the shell state with the directory state.
# It's called by both chpwd and precmd hooks.
__viper-env_sync_state() {
  local local_venv_path
  local_venv_path=$(__viper-env_discover_venv)

  # --- Deactivation Logic ---
  # If a viper-env managed venv is active...
  if [[ -n "$_VIPER_ENV_MANAGED_PATH" ]]; then
    # ...and it has been deleted (is defunct)...
    if [[ ! -d "$_VIPER_ENV_MANAGED_PATH" ]]; then
      __viper-env_deactivate "defunct"
      return # State is now clean, nothing more to do.
    fi

    # ...and we are in a directory that has a different venv or no venv...
    if [[ "$_VIPER_ENV_MANAGED_PATH" != "$local_venv_path" ]]; then
      __viper-env_deactivate "leaving"
    fi
  fi

  # --- Activation Logic ---
  # If a local venv is discovered and it's not the currently active one...
  if [[ -n "$local_venv_path" && "$VIRTUAL_ENV" != "$local_venv_path" ]]; then
    __viper-env_activate "$local_venv_path"
  fi
}

# Hook for directory changes.
__viper-env_on_chpwd() {
  # Reset the warning suppression key if the directory has changed.
  if [[ "$_VIPER_ENV_LAST_PWD" != "$PWD" ]]; then
    _VIPER_ENV_LAST_WARNING_KEY=""
    _VIPER_ENV_LAST_PWD="$PWD"
  fi
}

# Hook that runs after every command.
__viper-env_on_precmd() {
  # This hook only runs if enabled. Its only job is to sync state.
  __viper-env_sync_state
}

# Reads the configured hook type from the config file. Defaults to 'chpwd'.
__viper-env_get_hook_type() {
  local hook_type="precmd" # Default
  if [[ -f "$_VIPER_ENV_CONFIG_FILE" ]]; then
    # A simple grep is safer than sourcing the file.
    if grep -q '^_VIPER_ENV_HOOK_TYPE="chpwd"$' "$_VIPER_ENV_CONFIG_FILE"; then
      hook_type="chpwd"
    fi
  fi
  echo "$hook_type"
}

# Registers the appropriate hook based on the configuration.
__viper-env_register_hook() {
  # Remove any existing hooks to prevent duplicates or conflicts.
  add-zsh-hook -d chpwd __viper-env_on_chpwd
  add-zsh-hook -d precmd __viper-env_on_precmd

  # The chpwd hook is always active to handle directory changes and reset state.
  add-zsh-hook chpwd __viper-env_on_chpwd

  # The precmd hook is optional, for immediate activation on venv creation.
  local hook_type
  hook_type=$(__viper-env_get_hook_type)
  if [[ "$hook_type" == "precmd" ]]; then
    add-zsh-hook precmd __viper-env_on_precmd
  fi
}

autoload -Uz add-zsh-hook
# Register the appropriate hook based on the user's configuration.
__viper-env_register_hook

__viper-env_handle_autoload() {
  case "$1" in
    --enable)
      echo "Enabling immediate activation on venv creation (using precmd hook)."
      echo '_VIPER_ENV_HOOK_TYPE="precmd"' > "$_VIPER_ENV_CONFIG_FILE"
      __viper-env_register_hook
      ;;
    --disable)
      echo "Disabling immediate activation (using chpwd hook)."
      echo '_VIPER_ENV_HOOK_TYPE="chpwd"' > "$_VIPER_ENV_CONFIG_FILE"
      __viper-env_register_hook
      ;;
    *)
      printf "${COLOR_RED}Error: Unknown argument '%s' for autoload command.${COLOR_NC}\n\n" "$1" >&2
      printf "Usage: viper-env autoload [--enable|--disable]\n"
      printf "  --enable:  Activate venvs immediately upon creation (uses 'precmd' hook, default).\n"
      printf "  --disable: Activate venvs only when changing directories (uses 'chpwd' hook for efficiency).\n"
      return 1
      ;;
  esac
}
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
  ${COLOR_GREEN}cd${COLOR_NC} new_project

Commands:
  ${COLOR_BRIGHT_GREEN}help, h${COLOR_NC}      Show this help message.
  ${COLOR_BRIGHT_GREEN}list${COLOR_NC}         Show the currently active virtual environment.
  ${COLOR_BRIGHT_GREEN}status${COLOR_NC}       Show detailed status for debugging.
  ${COLOR_BRIGHT_GREEN}autoload${COLOR_NC}     Configure the activation hook (--enable|--disable).
  ${COLOR_BRIGHT_GREEN}version, --version${COLOR_NC} Show the plugin version.
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
    "version" | "--version")
      printf "viper-env version %s\n" "$_VIPER_ENV_VERSION"
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

      printf "Hook type: ${COLOR_BRIGHT_CYAN}%s${COLOR_NC}\n" "$(__viper-env_get_hook_type)"

      local discovered_path
      discovered_path=$(__viper-env_discover_venv)
      [[ -n "$discovered_path" ]] && printf "Discovered venv: ${COLOR_BRIGHT_CYAN}%s${COLOR_NC}\n" "$discovered_path" || printf "Discovered venv: None\n"
      ;;
    "autoload")
      __viper-env_handle_autoload "$2"
      ;;
    *)
      printf "${COLOR_RED}Error: Unknown command '%s'${COLOR_NC}\n\n" "$1" >&2
      __viper-env_help
      return 1
      ;;
  esac
}
