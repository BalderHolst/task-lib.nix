{ task-lib }:
with task-lib;
{
    gen-readme = mkTask "gen-readme" { script = "txtx ./README.mdx > README.md"; };
    gen-scripts = gen.gen-scripts "gen-scripts";
}
