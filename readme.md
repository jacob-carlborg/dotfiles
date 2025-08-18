# Dotfiles

Dotfiles and other configurations.

Uses [GNU Stow](https://www.gnu.org/software/stow/) to symlink the files to
their correct locations.

Uses the `--dotfiles` feature of Stow which adds special handling of dotfiles.
Any files with the `dot-` prefix will get the prefix replaced with `.` in the
target filenames when the files are linked. This avoids having a whole
repository with hidden files.

## Usage

### Initial Setup

1. Clone the repository:

    ```
    git clone git@github.com:jacob-carlborg/dotfiles.git
    ```

1. Install GNU Stow:

    ```
    brew install stow
    ```

1. Run the link script to create the links:

    ```
    ./link.sh
    ```

### Adding New Files

1. Add the files to this project. If the target filename should have the `.`
    prefix, replace that prefix with `dot-` in source filenames, i.e. in this
    project.

1. Commit the new files

1. Link the new files to their locations:

    ```
    ./link.sh
    ```

1. Verify the files have correctly been linked
1. Push the commits
