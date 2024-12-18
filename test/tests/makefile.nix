{
    pkgs ? import <nixpkgs> {},
    task-lib ? import ../../lib.nix { inherit pkgs; },
    test-lib ? import ../test-lib.nix { inherit pkgs; }
}:
let

    # Define the tasks
    tasks = with task-lib; {
        task1 = mkTask "hello-task" { script = "hello!"; };
        task2 = mkTask "other-task" { script = "Some other script"; };
    };

    makefile = task-lib.mkMakefile tasks;


    # TODO: I cannot make this compare correctly
    contents = builtins.readFile makefile;
    expected = ''
        # This Makefile was generated by Nix.
        # To make changes edit nix configuration.

        main: thelp

        thelp:
        	@echo "usage: make <task>"
        	@echo ""
        	@echo "Available Tasks:"
        	@echo -e '	hello-task'
        	@echo -e '	other-task'
        	@echo -e "\nUse 'make thelp' command to show this list."


        hello-task: 
        	hello!


        other-task: 
        	Some other script
    '';
    # a = test-lib.assertText contents expected;

    a = test-lib.assertFileExists makefile;
in
assert a;
a
