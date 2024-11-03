{ mkTask }:
{

    # TODO: This assumes execution from the root of the project
    #: Generate a task to run the app which generates scripts in specified paths
    gen-scripts = name: mkTask "gen-scripts" { script = "nix run .#${name}"; };

    #: Check that the repository has no uncommitted changes
    check-no-uncommited = msg: mkTask "check-no-uncommited" { script = ''
        git update-index --refresh > /dev/null
            git diff-index --quiet HEAD -- || {
                echo "${msg}"
                    exit 1
            }
        '';
    };
}