# crystal examples/benchmark.cr --release

require "benchmark"
require "../src/serializer"

class Model
  property name, title,
    children : Array(Child),
    friends : Array(Child),
    parents : Array(Child)

  def initialize(@name = "test", @title = "asd", @children = [] of Child, @friends = [] of Child, @parents = friends)
  end
end

class Child
  property age : Int32, dipper : Child?, address : Address?

  def initialize(@age, @dipper = nil, @address = nil)
  end

  def sub; end
end

class Address
  property street

  def initialize(@street = "some street")
  end
end

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

class CoreAddressSerializer
  include JSON::Serializable

  getter street : String

  def initialize(address)
    @street = address.street
  end
end

class CoreChildSerializer
  include JSON::Serializable

  getter age : Int32, sub : CoreChildSerializer?, address : CoreAddressSerializer?, dipper : CoreChildSerializer?

  def initialize(child)
    @age = child.age
    @sub = child.sub
    @address = CoreAddressSerializer.new(child.address.not_nil!) if child.address
    @dipper = CoreChildSerializer.new(child.dipper.not_nil!) if child.dipper
  end
end

class CoreModelSerializer
  include JSON::Serializable

  getter name : String, title : String, own_field : Int32, children : Array(CoreChildSerializer), parents : Array(CoreChildSerializer), friends : Array(CoreChildSerializer)

  def initialize(model)
    @name = model.name
    @title = model.title
    @own_field = own_field
    @children = model.children.map { |e| CoreChildSerializer.new(e) }
    @parents = model.parents.map { |e| CoreChildSerializer.new(e) }
    @friends = model.friends.map { |e| CoreChildSerializer.new(e) }
  end

  def own_field
    12
  end
end

class CoreRootSerializer
  include JSON::Serializable

  def initialize(data)
    @data = CoreModelSerializer.new(data)
  end
end

model = Model.new(friends: [Child.new(60, Child.new(20, address: Address.new))], parents: [] of Child)
nesting = { :children => [:sub], :friends => { :address => nil, :dipper => [:sub] } }

Benchmark.ips do |x|
  x.report("Serializer") { ModelSerializer.new(model).serialize(includes: nesting) }
  x.report("JSON::Serializable") { CoreRootSerializer.new(model).to_json }
end
