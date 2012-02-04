Mt. Gox Client Library
======================

Introduction
------------

This is library and utilities for clients of Mt. Gox (http://mtgox.com).
By "clients" I mean humans.

Status
------

Alpha. The library is currently in development and not ready for wide use.

Requirements
------------

- Ruby interpreter (either 1.8 or 1.9).
- "Ruby Gems" system.
- All gems specified in "lib/requirements.rb" (lines starting with `gem`).
  To install a gem you give command `gem install <gem name>`.
- RDoc (for building documentation for the library).
- Rake (for performing tasks implemented in "Rakefile").

How to use
----------

"lib" directory contains the library modules. To build HTML documentation for
classes, functions and other elements implemented in the library you may use
RDoc (with `rdoc lib` command).

"bin" directory contains source code for executables. Ruby scripts (with "*.rb"
filename) may be executed directly, but don't forget to tell Ruby where the
library resides (using "-I" key; for example: `ruby -Ilib bin/some-script.rb`).

You may use Rake to perform various tasks: installing executables into home
directory, building HTML documentation. Use `rake --tasks` command to see
what you can do with Rake here (and what is implemented in "Rakefile").

Development
-----------

There are no particular effective rules in this project yet. Anyone can take
this code and do with it what he wants. Just don't forget that the user
of the code should be able to sort it out (what is it for, how to use it, etc.)
and to sort it out quickly.
