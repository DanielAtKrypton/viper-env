__viper-env_help () {
    printf 'Example usage:                     
  viper-env help, h           - show help 
'
}

viper-env_runner() {
  if [[ $@ == "help" || $@ == "h" ]]; then 
    __viper-env_help
  #elif [[ $@ == "something" || $@ == "alias" ]]; then 
  fi
}

alias viper_env='viper-env_runner'
