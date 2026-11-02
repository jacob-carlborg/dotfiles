function worktree --description "Manage git worktrees"
    switch "$argv[1]"
        case switch
            set -l path (command worktree $argv)
            or return 1

            builtin cd $path
        case done
            # Resolve the worktree while still inside it, then leave it so the
            # shell isn't stranded in a deleted directory.
            set -l args $argv[2..-1]

            if test (count $args) -eq 0
                set args (command worktree current 2>/dev/null)
            end

            set -l main (command worktree main)
            or return 1

            builtin cd $main
            command worktree done $args
        case '*'
            command worktree $argv
    end
end
