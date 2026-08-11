# Select a project's Ruby without paying for RVM's shell library.
#
# RVM already precomputes every ruby and ruby@gemset environment into
# ~/.rvm/environments/<name>. `rvm default` and the rvmrc hook shipped with
# RVM's fish integration do nothing but re-derive those files, by sourcing the
# whole of RVM inside a bash subshell -- ~550 ms per shell and per `cd` into a
# project. Reading the file directly costs ~3 ms.
#
# Real RVM still does what it is actually needed for: installing rubies and
# creating gemsets. See __ruby_env_activate.

function ruby_env -a name --description "activate the RVM environment <name>, e.g. default or ruby-3.3.1@app"
    __ruby_env_activate $name
    or return 1

    set -g __ruby_env_current $name

    # a non-matching `string match` in __ruby_env_apply leaves $status set, and
    # a trailing `set` does not clear it
    return 0
end

function __ruby_env_activate -a name --description "apply <name>, asking RVM to create it when it does not exist yet"
    set -l file $HOME/.rvm/environments/$name

    if test $name = system
        __ruby_env_strip
        return 0
    else if test -f $file
        __ruby_env_apply $file
        return 0
    end

    if not test -d $HOME/.rvm/rubies/(string split -f 1 @ -- $name)
        echo "ruby_env: no ruby installed for '$name'" >&2
        return 1
    end

    # First use of this gemset. Let RVM create it and set up the environment,
    # which also writes the file the fast path above reads from then on.
    rvm use $name --create
end

function __ruby_env_apply -a file --description "translate an RVM environment file into fish"
    __ruby_env_strip

    for line in (cat $file)
        set -l assignment (string match -r "^export ([A-Z_]+)=['\"](.*)['\"]\$" -- $line)
        set -l removal (string match -r '^unset ([A-Z_]+)$' -- $line)

        if test (count $assignment) -eq 3
            __ruby_env_set $assignment[2] $assignment[3]
        else if test (count $removal) -eq 2
            set -e $removal[2]
        end
    end
end

function __ruby_env_strip --description "drop RVM's ruby and gem bin dirs from PATH"
    set -gx PATH (string match -rv -- "^$HOME/\.rvm/(gems|rubies)/" $PATH)
end

function __ruby_env_set -a name value
    if test $name = PATH
        set -gx PATH (string split ':' -- (string replace ':$PATH' '' -- $value)) $PATH
    else
        set -gx $name $value
    end
end

function __ruby_env_project --description "the RVM environment named by the nearest .ruby-version"
    set -l dir $PWD

    while test $dir != / -a $dir != $HOME
        if test -f $dir/.ruby-version
            __ruby_env_name $dir
            return 0
        end

        set dir (path dirname $dir)
    end

    echo default
end

function __ruby_env_name -a dir --description "the environment named by <dir>'s .ruby-version and .ruby-gemset"
    set -l ruby (string trim <$dir/.ruby-version)
    set -l gemset ""

    if string match -qr '^[0-9]' -- $ruby
        set ruby "ruby-$ruby"
    end

    if test -f $dir/.ruby-gemset
        set gemset "@"(string trim <$dir/.ruby-gemset)
    end

    echo "$ruby$gemset"
end

function __ruby_env_autoswitch --on-variable PWD --description "follow the project's .ruby-version"
    set -l name (__ruby_env_project)

    test "$name" = "$__ruby_env_current"
    and return 0

    ruby_env $name
    or ruby_env default
end
