{ pkgs }:
let

    lib = pkgs.lib;

    # Default message to be added to the top of each script
    script-msg = ''
        # This script was generated by Nix.
        # To make changes edit nix configuration.

    '';

    # Name of the help task
    help-task-name = "thelp";

    _taskScriptString = task: level: ''
        echo "${ lib.strings.replicate level "--" }->> Running '${task.name}'"
        # Dependencies for ${task.name}
        ${builtins.concatStringsSep "\n" (map (j: _taskScriptString j (level+1)) task.depends)}
        # Run ${task.name} task
        ${task.script}
    '';

    _tabIndent = s: (if s == "" then "" else "\t") + (builtins.concatStringsSep "\n\t" (
        builtins.filter (e: builtins.typeOf e != "list") (builtins.split "\n" s)
    ));

    _writeScript = name: script: pkgs.stdenv.mkDerivation {
        name = name;
        phases = [ "installPhase" ];
        installPhase = ''
            touch $out
            echo -e "#!/bin/sh\n" > $out
            cat ${pkgs.writeText "${name}-script" script} >> $out
            chmod +x "$out"
        '';
    };

    _writeScriptBin = name: script: pkgs.stdenv.mkDerivation {
        name = name;
        phases = [ "installPhase" ];
        installPhase = ''
            mkdir -p "$out/bin"
            echo -e "#!/bin/sh\n" > "$out/bin/${name}"
            cat ${pkgs.writeText "script" script} >> "$out/bin/${name}"
            chmod +x "$out/bin/${name}"
        '';
    };

    _mkScript = write_script: task: write_script task.name (script-msg + (_taskScriptString task 0));

    # TODO: Check that tasks are available in shell
    _mkHelpScript = write_script: tasks:
    let
        task_names = if builtins.typeOf tasks == "list" then tasks else builtins.attrValues tasks;
    in
    write_script "${help-task-name}" ''
        echo "Available Tasks:"
        ${ builtins.concatStringsSep "\n" (map (j:  "echo -e '\t${j.name}'") task_names) }

        # Only print if `${help-task-name}` is in current PATH
        echo -e "\nUse '${help-task-name}' command to show this list."
    '';

in
rec {

    #: Create a task
    #:-  name: string - The name of the task
    #:-  details: { script?: string, depends?: list[task] } - A set maybe containing a script and dependencies
    #:>  task
    mkTask = name: { script ? "", depends ? [], }: {
        name = name;
        script = script;
        depends = depends;
    };

    #: Create a sequence of tasks
    #:-  name: string - The name of the sequence task
    #:-  seq: list[task] - A list of tasks to be executed in sequence
    #:>  task
    mkSeq = name: seq: mkTask name { depends = seq; };

    #: Generate a script that executes a task
    #:-  task: task - The task to be executed
    #:>  path - Path to the generated script in nix store
    mkScript = _mkScript _writeScript;

    #: Generate a script (package) that executes a task
    #:-  task: task - The task to be executed
    #:>  package - Path to the package in nix store
    mkScriptBin = _mkScript _writeScriptBin;

    #: Generate a help script that lists all tasks
    #:-  tasks: list[task]
    #:>  path - Path to help script in nix store
    mkHelpScript = _mkHelpScript _writeScript;

    #: Generate a help script (package) that lists all tasks
    #:-  tasks: list[task]
    #:>  package - Path to help script package in nix store
    mkHelpScriptBin = _mkHelpScript _writeScriptBin;

    #: Generate a list of scripts for each task
    #:-  tasks: list[task]
    #:>  list[package] - List of packages in nix store. These can be appended to shell inputs.
    mkScripts = tasks: (lib.attrsets.mapAttrsToList (_: j: mkScriptBin j) tasks) ++ [(mkHelpScriptBin tasks)];

    #: Generate a Makefile for tasks
    #:-  tasks: list[task]
    #:>  path - Path to generate Makefile in nix store
    mkMakefile = tasks: let
        task_list = if builtins.typeOf tasks == "list" then tasks else builtins.attrValues tasks;
    in
    pkgs.writeText "Makefile" (''
        # This Makefile was generated by Nix.
        # To make changes edit nix configuration.

        main: ${help-task-name}

        ${help-task-name}:
        ${ _tabIndent /*bash*/ ''
            @echo "usage: make <task>"
            @echo ""
            @echo "Available Tasks:"
            ${ (builtins.concatStringsSep "\n" (map (j:  "@echo -e '\t${j.name}'") task_list)) }
            @echo -e "\nUse 'make ${help-task-name}' command to show this list."
        ''}

    '' +
        (builtins.concatStringsSep "\n\n" (map (task: ''
            ${task.name}: ${ builtins.concatStringsSep " " (map (j: "${j.name}") task.depends) }
            ${
                if task.script == "" then "" else "\t"
            }${
                builtins.concatStringsSep "\n\t" (
                    builtins.filter (e: builtins.typeOf e != "list") (builtins.split "\n" task.script)
                )}
        '') task_list))
    );

    #: Generate a shell hook for tasks
    #:-  tasks: list[task]
    #:>  string - Shell hook string
    mkShellHook = tasks: /*bash*/ ''
        ${mkHelpScript tasks}
    '';

    #: Create a flake app that generates scripts, based on a task, in specified paths
    #:-  task-files: set<string, script> - A set of paths and scripts to be generated
    #:>  app - A flake app that generates scripts scripts in specified paths
    mkGenScriptsApp = task-files: {
        type = "app";
        program = let
            parts = lib.attrsets.mapAttrsToList (path: script: /*bash*/ ''
                echo "Generating ${path}..."

                # Create directory if it doesn't exist
                mkdir -p $(dirname ${path})

                # Copy script to destination
                cp -f ${script} ${path} || {
                    echo "Failed to generate ${path}."
                    exit 1
                }

            '') task-files;
            script = builtins.concatStringsSep "\n" parts;
        in
        toString (pkgs.writeShellScript "gen-scripts" /*bash*/ ''
            ${if builtins.length parts == 0 then "echo 'No scripts to generate.'; exit 0" else script}
            echo 'Done.'
        '');
    };

    #: Set of function used to generate commonly used tasks.
    #: See [Task Generators](#task-generators).
    gen = import ./builtin-tasks.nix { inherit mkTask; };

    #: Set of snippets to be used in tasks.
    snips = import ./snippets.nix;

}
