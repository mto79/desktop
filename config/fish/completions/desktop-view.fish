# desktop-view: the views in ~/.config/desktop/views, and what can be done with one.
function __desktop_view_names
    set -l dir (set -q XDG_CONFIG_HOME; and echo $XDG_CONFIG_HOME; or echo ~/.config)/desktop/views
    for file in $dir/*.toml
        basename $file .toml
    end
end
complete -c desktop-view -f
complete -c desktop-view -n __fish_use_subcommand -a 'open save edit show list rm' -d command
complete -c desktop-view -n '__fish_seen_subcommand_from open edit show rm' -a '(__desktop_view_names)' -d view
complete -c desktop-view -n '__fish_seen_subcommand_from open' -l detached -d 'build it, and stay where you are'
complete -c desktop-view -n '__fish_seen_subcommand_from save' -l force -d 'write over a view that is there'
