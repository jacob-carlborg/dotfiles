function rvm --description='Ruby enVironment Manager'
  # run RVM and capture the resulting environment
  set --local env_file (mktemp -t rvm.fish.XXXXXXXXXX)
  # This finds where RVM's root directory is and sources scripts/rvm from within it.  Then loads RVM in a clean environment and dumps the environment variables it generates out for us to use.
  bash -c 'PATH=$GEM_HOME/bin:$PATH;RVMA=$(which rvm);RVMB=$(whereis rvm | sed "s/rvm://");source $(if test $RVMA;then echo $RVMA | sed "s/\/bin\//\/scripts\//";elif test $RVMB; then echo $RVMB | sed "s/rvm/rvm\/scripts\/rvm/"; else echo ~/.rvm/scripts/rvm; fi); rvm "$@"; status=$?; env > "$0"; exit $status' $env_file $argv

  # apply rvm_* and *PATH variables from the captured environment
  and eval (grep -E '^rvm|^PATH|^GEM_PATH|^GEM_HOME' $env_file | grep -v '_clr=' | sed '/^[^=]*PATH/s/:/" "/g; s/^/set -xg /; s/=/ "/; s/$/" ;/; s/(//; s/)//')
  # needed under fish >= 2.2.0
  and set -xg GEM_PATH (echo $GEM_PATH | sed 's/ /:/g')

  # clean up
  rm -f $env_file
end

# RVM's own `--on-variable PWD` hook used to live here. It ran `rvm reload` plus
# `rvm rvmrc load` -- two bash subshells, ~550 ms -- on every cd into a project,
# and tested `.ruby-version` against $PWD rather than the directory it was
# walking up to, so it never fired below a project's root. __ruby_env_autoswitch
# in conf.d/ruby.fish replaces it.
