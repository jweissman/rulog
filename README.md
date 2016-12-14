# rulog

* [Homepage](https://rubygems.org/gems/rulog)
* [Documentation](http://rubydoc.info/gems/rulog/frames)
* [Email](mailto:jweissman1986 at gmail.com)

[![Code Climate GPA](https://codeclimate.com/github//rulog/badges/gpa.svg)](https://codeclimate.com/github//rulog)

## Description

Logic programming in Ruby.

## Features

   - Declare facts, relations and rules
   - Query the database for simple solutions to expressions with variables

## Examples

    require 'rulog'

    include Rulog
    extend DSL

    # tell the database facts with '!'
    sunny! # => true

    # query with '?'
    sunny? # => true

    # create relations
    likes!(laura, bobby)
    likes!(laura, james)
    likes!(james, laura)
    likes!(james, donna)
    likes!(donna, mike)
    likes!(audrey, bobby)
    likes!(bobby, shelly)

    likes?(laura, bobby)
    # => true

    # query with underscore placeholders
    likes(laura, _who).solve!
    # => [{:_who=>bobby}, {:_who=>james}]

    likes(_who, bobby).solve!
    # => [{:_who=>laura}, {:_who=>audrey}]

    # construct rules with blocks returning arrays of clauses
    friends! { |x,y| [ likes?(x,y), likes?(y,x) ] }

    friends(_who, laura).solve!
    # [{:_who=>james}]

## Requirements

## Install

    $ gem install rulog

## Synopsis

    $ rulog

## Copyright

Copyright (c) 2016 Joseph Weissman

See {file:LICENSE.txt} for details.
