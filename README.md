# bash-tools
Tools to help with static &amp; dynamic analysis of bash scripts/programs.

## Use Cases
### Static analysis
- Pull list of functions from code.
- Pull list of functions with leading comments (as documentation) from code.
- Extract some or all functions from code to inspect, or to put in another file.

### Dynamic analysis
- Include a few lines in the target code to change runtime behavior.
  - Log function entry and exit.
  - Log changes to the environment at entry and exit.
  - Introduce a pause at the function exit to allow for additional inspection.
- Create a stand-alone program that pull in select functions from the main code.
  - This allows for testing of functions in isolation with control over the environment.
  - Functions can be pulled in without change.
  - Or they can be pulled in with behavior changes (logging/pausing).

## Function Format Expectations
This code uses regular expressions, rather than a complete parser to extract 
bash functions. These two forms are recognized:
```
# a comment about the function
# another comment
function_name123 () { # another comment
...body...
}
```
or
```
# a comment about the function
# another comment
function_name123 ()
{
...body...
}
```
If you need something else, either modify the source to be consistent, 
or hack the regex's to match your needs :-)

## Background
Conceived because of a need (well, interest) in troubleshooting abcde.
That bash script is over 6000 lines, with 64 functions and passes 
control & state with both global variables and files.

Realized this code could be used to analyze other bash scripts/programs and
also wanted to license it in a more liberal fashion (MIT) so that it could be
easily used outside of the abcde environment.

## License

Copyright (c) 2026 Paul C. Casto

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
