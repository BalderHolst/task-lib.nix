{ task-gen }:
let
    cow-say = msg: /*bash*/ ''
        cowsay "${msg}"
    '';
    rainbow-say = msg: /*bash*/ ''
        echo "${msg}" | lolcat
    '';
in
with task-gen;
rec { 
    cow-hello     = mkTask "cow-say-hello"     { script = cow-say "Hello, there!"; };
    rainbow-hello = mkTask "rainbow-say-hello" { script = rainbow-say "Hello, there!"; };

    cow-morning     = mkTask "cow-say-morning"     { script = cow-say "Good morning!"; };
    rainbow-morning = mkTask "rainbow-say-morning" { script = rainbow-say "Good morning!"; };

    all = mkSeq "all" [ cow-hello rainbow-hello cow-morning rainbow-morning ];
}
