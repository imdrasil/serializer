require "spec"
require "../src/serializer"

# ===============
# ==== Models
# ===============

class Model
  property name, title,
    children : Array(Child) = [] of Child

  def initialize(@name = "test", @title = "asd")
  end

  def friends
    [Child.new(60)]
  end

  def parents
    friends
  end
end

class Child
  property age

  def initialize(@age = 25)
  end

  def sub; end

  def address
    Address.new
  end

  def dipper
    Child.new(100)
  end
end

class Address
  property street

  def initialize(@street = "some street")
  end
end

# ===============
# === Serializers
# ===============

class AddressSerializer < Serializer::Base(Address)
  attributes :street
end

class ChildSerializer < Serializer::Base(Child)
  attribute :age

  has_one :sub, ChildSerializer
  has_one :address, AddressSerializer
  has_one :dipper, ChildSerializer
end

class ModelSerializer < Serializer::Base(Model)
  attribute :name
  attribute :title, :Title, if: :test_title
  attribute :own_field

  has_many :children, ChildSerializer
  has_many :parents, ChildSerializer, :Parents
  has_many :friends, ChildSerializer

  def test_title(object, options)
    options.nil? || !options[:test]?
  end

  def own_field
    12
  end
end

class InheritedSerializer < ModelSerializer
  attribute :inherited_field

  def inherited_field
    1.23
  end
end
