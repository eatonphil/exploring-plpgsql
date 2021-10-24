* Every statement must end with semi-colon
* := and = are the same thing and neither are declarations
* $$ is any token for string start/end marker
* Input variables default to $1-$N but can be named
* Debugging: raise an exception :  `RAISE EXCEPTION 'blah: %', arg;`
* Everything in postgres is 1-indexed: strings, arrays