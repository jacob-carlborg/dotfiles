function dvm --description='D Version Manager'
  # run DVM and capture the resulting environment
  set --local env_file (mktemp -t dvm.fish.XXXXXXXXXX)
  # This finds where DVM's root directory is and sources scripts/dvm from within it.  Then loads DVM in a clean environment and dumps the environment variables it generates out for us to use.
  bash -c 'DVMA=$(which dvm);DVMB=$(whereis dvm | sed "s/dvm://");source $(if test $DVMA;then echo $DVMA | sed "s/\/bin\//\/scripts\//";elif test $DVMB; then echo $DVMB | sed "s/dvm/dvm\/scripts\/dvm/"; else echo ~/.dvm/scripts/dvm; fi); dvm "$@"; status=$?; env > "$0"; exit $status' $env_file $argv

  # apply dvm_* and *PATH variables from the captured environment
  and eval (grep -E '^dvm|^PATH' $env_file | grep -v '_clr=' | sed '/^[^=]*PATH/s/:/" "/g; s/^/set -xg /; s/=/ "/; s/$/" ;/; s/(//; s/)//')

  # clean up
  rm -f $env_file
end
