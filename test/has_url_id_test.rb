require 'test/unit'
require 'rubygems'
require 'active_record'

# require the url_id stuff
require "#{File.dirname(__FILE__)}/../init"

# setup test database
ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database => ":memory:")

def setup_db
  ActiveRecord::Schema.define(:version => 1) do
    create_table :items do |t|
      t.column :name, :string
      t.column :url_id, :string
    end

    create_table :sub_items do |t|
      t.column :name, :string
      t.column :url_id, :string
      t.column :item_id, :integer
    end

    create_table :name_items do |t|
      t.column :name, :string
      t.column :url_id, :string
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
  has_url_id
end

class SubItem < ActiveRecord::Base
  belongs_to :item
  has_url_id :scope => :item
end

class NameItem < ActiveRecord::Base
  has_url_id :scope
end
teardown_db


class HadUrlIdTest < Test::Unit::TestCase
  def setup
    setup_db
  end

  def teardown
    teardown_db
  end

  # Replace this with your real tests.
  def test_simple_case
    item = Item.create :name => 'Simple Name'
    assert_equal 'simple-name', item.url_id
  end

  def test_umlauts
    item = Item.create :name => 'bänösü'
    assert_equal 'baenoesue', item.url_id
  end

  def test_special_characters
    item = Item.create :name => 'Foo,bar* "'
    assert_equal 'foobar-', item.url_id
  end

  def test_collision
    item1 = Item.create :name => "Name"
    item2 = Item.create :name => "Name"
    item3 = Item.create :name => "name"

    assert item1.url_id != item2.url_id
    assert item2.url_id != item3.url_id
    assert item3.url_id != item1.url_id
  end

  def test_emtpy_name
    item = Item.create
  end

  def test_collision_with_scope
    item = Item.create
    subitem1 = SubItem.create :name => "Name", :item => item
    subitem2 = SubItem.create :name => "Name", :item => item

    assert subitem1.url_id != subitem2.url_id
  end

  def test_no_collision_due_to_scope
    item1 = Item.create
    item2 = Item.create

    subitem1 = SubItem.create :name => "Name", :item => item1
    subitem2 = SubItem.create :name => "Name", :item => item2

    assert_equal subitem1.url_id, subitem2.url_id
  end

  def test_find_by_params
    item1 = Item.create :name => "Item1"
    item2 = Item.create :name => "Item2"

    subitem1 = SubItem.create :name => "Name", :item => item1
    subitem2 = SubItem.create :name => "Name", :item => item2

    subitem = SubItem.find_by_params :item => "item1", :sub_item => "name"
    assert_equal subitem1, subitem

    subitem = SubItem.find_by_params :item => "item2", :sub_item => "name"
    assert_equal subitem2, subitem
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
    assert item1.url_id = item2.url_id

    item3 = NameItem.create :name => "Name", :scope => "Scope1"
    assert item1.url_id != item3.url_id
  end

end
