Mt. Gox Client Library
======================

Introduction
------------

This is library and utilities for clients of Mt. Gox (http://mtgox.com).
By "clients" I mean humans.

Status
------

Stable. The library is ready for use, and its current interface will remain
unchanged (new functionality will be added only).

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

"bin" directory contains source code for executables. Ruby scripts in "bin"
(with "*.rb" filename) may be executed directly, but don't forget to tell Ruby
where the library modules reside (using "-I" key; for example
`ruby -Ilib bin/some-script.rb`). All the scripts accept "-h" or "--help" key.

You may use Rake to perform various tasks implemented in "Rakefile" (for
example, installing executables into system directory with executables).
Use `rake --tasks` command to see what you can do with Rake here.

Development
-----------

There are no particular effective rules in this project yet. Anyone can take
this code and do with it what he wants. Just don't forget that the user
of the code should be able to sort it out (what is it for, how to use it, etc.)
and to sort it out quickly.
