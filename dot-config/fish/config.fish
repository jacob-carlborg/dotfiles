set -x CLICOLOR
set -x EDITOR 'mate -w'
set -x MANPAGER "sh -c 'col -bx | bat -l man -p'"
set -x DISABLE_SPRING true
set -x USE_GKE_GCLOUD_AUTH_PLUGIN True
set -x VITE_DEVTOOLS_EDITOR zed

set fish_prompt_pwd_dir_length 0

alias kc="kubectl"
alias kcx="kubectx"
alias bhelp=bathelp

function fish_prompt -d "Write out the prompt"
  printf '%s%s%s' (set_color $fish_color_cwd) (prompt_pwd) ' $ ' \
    (set_color normal)
end

function ll
  command ls -lAh $argv
end

function logs
  argparse 'p/process=' -- $argv
  or return

  if set -q _flag_process; and test -n _flag_process
    set process $_flag_process
  else
    set process 'web'
  end

  set app "$argv[1]"
  set env_context "$argv[2]"
  set context ''
  set environment ''

  switch "$env_context"
    case 'sb1'
      set environment 1
      set context 'sandbox'
    case 'sb2'
      set environment 2
      set context 'sandbox'
    case 'prod' 'production'
      set context 'production'
    case 'örebro' 'orebro'
      set context 'orebro'
    case 'tooling'
      set context 'tooling'
    case 'pv'
      set context 'pv'
    case 'pv-sandbox'
      set environment 'apoex-pv'
      set context 'sandbox'
    case 'aposuite-sb1'
      set environment 'aposuite-1'
      set context 'sandbox'
    case 'kronoberg'
      set context 'kronoberg'
    case '*'
      echo "Unrecognized environment: $env_context"
      return 1
  end

  set lables "app=$app,process=$process"

  if [ "$context" = "sandbox" ]
    set lables "$lables,environment=$environment"
  end

  kubectl logs --namespace "$app" -l "$lables" -f --context "$context" $argv[3..]
end

function bathelp
  $argv --help &| bat --plain --language=help
end

source ~/.iterm2_shell_integration.fish
source "/opt/homebrew/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.fish.inc"
rvm default
# temporarily disable until DVM works again
# dvm --version > /dev/null

set PATH /opt/homebrew/bin /usr/local/bin $PATH /sbin /usr/sbin

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init.fish 2>/dev/null || :

if test -f ~/.config/fish/extra.fish
  source ~/.config/fish/extra.fish
end
