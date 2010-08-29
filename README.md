# has_scoped_slug
A simple slug generating gem for ActiveRecord supporting ActiveRecord association scopes

## Usage
In the model
    class Item < ActiveRecord::Base
      has_scoped_slug :scope => :super_item, :name_column => :name
    end

Where `name_column` defines the column to be sluggified (defaults to name) and scope defines the
scope for which the slug has to be unique.

## Recursive unique ID
`get_params` returns a Hash with the slug of the model and its parents when used with scoping.
`find_by_params` returns the model for the Hash returned by get_params.
