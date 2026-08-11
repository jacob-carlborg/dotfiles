function worktree --description "Manage git worktrees"
    if test "$argv[1]" != switch
        command worktree $argv
        return $status
    end

    set -l path (command worktree $argv)
    or return 1

    builtin cd $path
end
