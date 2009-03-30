= RubyMacros
* http://rubymacros.rubyforge.org
* http://rubyforge.org/projects/rubymacros

== DESCRIPTION:
RubyMacros is a lisp-like macro pre-processor for Ruby. More than just a 
purely textual substitution scheme, RubyMacros can manipulate and morph 
Ruby parse trees (in the form of RedParse Nodes) at parse time in just about 
any way you see fit. 

Macros are programmed in ruby itself. And since parse trees are represented 
in RedParse format, they're easier to use (programatically) and more object-
oriented than other available ruby parsetree formats. (RedParse Node format 
is actually designed to be straightforward to use and to represent the 
structure of ruby source code very closely.)

== Benefits:
 * Powerful and easy metaprogramming
 * Create better DSLs
 * Manipulate syntax trees to suit yourself
 * Access local variables and other caller context unavailable to methods
 * Macros as inline methods: should be slightly faster than equivalent methods

== Drawbacks:
Although in theory already as powerful as lisp macros, the current 
implementation has a number of problems which added together make it merely 
a proof of concept or toy at this point:
 * pre-processing is very, very slow (because of RedParse)
 * macro calls must be inside some sort of method;
 * straight out macro calls at the top level won't work
 * macros can't have blocks or receivers
 * some ruby syntax is unsupported in files using macros
 * files using macros must be loaded via Macro.require;
 * Kernel#require will not recognize macros
 * RedParse Node tree format will be changing slightly
 * macros cannot be scoped
 * no variable (or other) hygiene

== Requirements:
  RubyMacros requires RedParse.

== Install:
  gem install rubymacros

== Examples:
  macro simple(a,b) 
    :(^a+^b) 
  end
  def simple_user
    p simple(1,2)  #prints 3
  end

  #loop as a macro, should be a bit faster than the #loop method
  macro loop(body)
    :(while true
        ^body
      end
    )
  end

  #for more examples, see the examples/ directory

== New Syntax:
I have invented 3 new syntactical constructions in order to allow reasonably
easy to use macros. Macros themselves look just like methods except that 
'macro' instead of 'def' is used to start the macro definition off. A form 
literal is an expression surrounded by ':(' and ')'. The form escape operator 
is '^'. '^' is a unary operator of fairly high precedence.

== Forms and Form Escapes:
Forms are an essential adjunct to macros. Forms represent quoted source 
code, which has been parsed but not evaled yet. When a form literal is 
executed, it returns a RedParse::Node representing the parse tree for the 
enclosed source code. Within a form literal, a ^, used as a unary operator, 
will escape the expression it controls, so that instead of being part of the
form's data, it is executed at the same time as the form literal, and the 
result of an escaped expression (which should be a Node) is interpolated
into the form at that point. The whole effect is much like that of string
interpolations (#{}) inside string literals.

== How Macros Work
Typically, macros return a single form literal, which contains form escape 
expressions within it which make use of the macro's parameters. However, 
macro bodies may contain anything at all; more complicated macros will 
likely not contain any forms. (Likewise, form literals may be used outside 
macros, but the utility of doing so may be minimal.)

At parse time (well, really at method definition time, but in effect it's 
much the same thing) method bodies are scanned for callsites which have the 
names of known macros. When such a call is found, it is expanded as follows. 
The parsetrees for the arguments to the callsite are passed as arguments to 
the macro. The macro is expected to return a parsetree, which replaces the 
macro callsite in the parsetree which contained it. 



== Known Problems
 * need to insert extra parens around form params and macro texts
 * a variety of parsetrees are kept around forever for no good reason
 * a few warnings and disabled tests in unit tests
 * however, huge rediculous piles of RedParse warnings when running 'rake test'

== License:
Copyright (C) 2008  Caleb Clausen

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Lesser General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.


