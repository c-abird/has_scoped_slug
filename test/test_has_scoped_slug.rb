# coding: utf-8

require 'test/unit'
require 'rubygems'
require 'active_record'

# require the slug stuff
require "#{File.dirname(__FILE__)}/../lib/has_scoped_slug.rb"

# setup test database
ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database => ":memory:")

def setup_db
  ActiveRecord::Schema.define(:version => 1) do
    create_table :items do |t|
      t.column :name, :string
      t.column :foo, :string
    end

    create_table :sub_items do |t|
      t.column :name, :string
      t.column :slug, :string
      t.column :item_id, :integer
    end

    create_table :name_items do |t|
      t.column :name, :string
      t.column :slug, :string
      t.column :scope, :string
    end
  end
end

def teardown_db
  ActiveRecord::Base.connection.tables.each do |table|
    ActiveRecord::Base.connection.drop_table(table)
  end
end

setup_db
class Item < ActiveRecord::Base
  has_scoped_slug :column => :foo
end

class SubItem < ActiveRecord::Base
  belongs_to :item
  has_scoped_slug :scope => :item
end

class NameItem < ActiveRecord::Base
  has_scoped_slug :scope => :scope
end
teardown_db


class HasScopedSlugTest < Test::Unit::TestCase
  def setup
    setup_db
  end

  def teardown
    teardown_db
  end

  def test_the_slug_scope_class_method
    assert_equal :item_id, SubItem.slug_scope
    assert_equal :scope, NameItem.slug_scope
  end

  def test_simple_case
    item = Item.create :name => 'Simple Name'
    assert_equal 'simple-name', item.slug
  end

  def test_umlauts
    item = Item.create :name => 'bänösü'
    assert_equal 'baenoesue', item.slug
  end

  def test_special_characters
    item = Item.create :name => 'Foo,bar* "'
    assert_equal 'foobar-', item.slug
  end

  def test_collision
    item1 = Item.create :name => "Name"
    item2 = Item.create :name => "Name"
    item3 = Item.create :name => "name"

    assert item1.slug != item2.slug
    assert item2.slug != item3.slug
    assert item3.slug != item1.slug
  end

  def test_emtpy_name
    item = Item.create
  end

  def test_collision_with_scope
    item = Item.create
    subitem1 = SubItem.create :name => "Name", :item => item
    subitem2 = SubItem.create :name => "Name", :item => item

    assert subitem1.slug != subitem2.slug
  end

  def test_no_collision_due_to_scope
    item1 = Item.create
    item2 = Item.create

    subitem1 = SubItem.create :name => "Name", :item => item1
    subitem2 = SubItem.create :name => "Name", :item => item2

    assert_equal subitem1.slug, subitem2.slug
  end

  def test_find_by_params_with_association_scope
    item1 = Item.create :name => "Item1"
    item2 = Item.create :name => "Item2"

    subitem1 = SubItem.create :name => "Name", :item => item1
    subitem2 = SubItem.create :name => "Name", :item => item2

    subitem = SubItem.find_by_params :item => "item1", :sub_item => "name"
    assert_equal subitem1, subitem

    subitem = SubItem.find_by_params :item => "item2", :sub_item => "name"
    assert_equal subitem2, subitem
  end

  def test_find_by_params_with_non_association_scope
    item1 = NameItem.create :name => 'Item', :scope => 'Scope1'
    item2 = NameItem.create :name => 'Item', :scope => 'Scope2'
    
    item = NameItem.find_by_params :name_item => item1.slug, :scope => 'Scope1'
    assert_equal item1, item

    item = NameItem.find_by_params :name_item => item2.slug, :scope => 'Scope2'
    assert_equal item2, item
  end

  def test_find_by_params_without_scope
    #flunk
  end

  def test_find_by_params_with_missing_info
    item1 = Item.create :name => "Item1"
    item2 = Item.create :name => "Item2"

    subitem1 = SubItem.create :name => "Name", :item => item1
    subitem2 = SubItem.create :name => "Name", :item => item2

    subitem = SubItem.find_by_params :item => "item1"
    # should fetch any subitem belonging to item
    assert subitem1 == subitem || subitem2 == subitem
  end

  def test_non_association_scoping
    item1 = NameItem.create :name => "Name", :scope => "Scope1"
    item2 = NameItem.create :name => "Name", :scope => "Scope2"
    assert item1.slug = item2.slug

    item3 = NameItem.create :name => "Name", :scope => "Scope1"
    assert item1.slug != item3.slug
  end

  def test_get_params_with_non_association_scope
    item = NameItem.create :name => "Name", :scope => "Scope1"
    assert_equal 2, item.get_params.keys.size
    assert_equal item.slug, item.get_params[:name_item]
    assert_equal item.scope, item.get_params[:scope]
  end

  def test_get_params_with_association_scope
    item = Item.create :name => "Item1"
    subitem = SubItem.create :name => "Subitem1", :item => item
    assert_equal 2, subitem.get_params.size
    assert_equal subitem.slug, subitem.get_params[:sub_item]
    assert_equal item.slug, subitem.get_params[:item]
  end

  def test_get_params_without_scope
    item = Item.create :name => "Item1"
    assert_equal 1, item.get_params.size
    assert_equal item.slug, item.get_params[:item]
  end

end
