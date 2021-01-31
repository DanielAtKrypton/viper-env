__viper_env_help () {
    printf 'Example usage:                     
  viper_env help, h           - show help 
'
}

viper_env_runner() {
  if [[ $@ == "help" || $@ == "h" ]]; then 
    __viper_env_help
  #elif [[ $@ == "something" || $@ == "alias" ]]; then 
  fi
}

alias viper_env='viper_env_runner'
