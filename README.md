# Serializer

Serializer is simple JSON serialization library for your object structure. Unlike core `JSON` module's functionality this library only converts to JSON string (one direction) but at the same time provides some free space for maneuvers, precise and flexible configuration.

`Serializer::Base` only ~11% slower than `JSON::Serializable`

```text
        Serializer 646.00k (  1.55µs) (± 2.52%)  2.77kB/op   1.11× slower
JSON::Serializable 719.74k (  1.39µs) (± 2.39%)   1.3kB/op        fastest
```

and at the same time provides next functionality:

* conditional rendering at schema definition stage
* excluding specific fields at invocation stage
* separation fields from relations
* deep relation specification (to be rendered) at invocation stage
* inheritance
* optional meta data (can be specified at both definition and invocation stages).

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     serializer:
       github: imdrasil/serializer
   ```

2. Run `shards install`

## Usage

Let's assume we have next classes relationship

```crystal
class Parent
  property name, title,
    children : Array(Child),
    friends : Array(Child)

  def initialize(@name = "test", @title = "asd", @children = [] of Child, @friends = [] of Child)
  end
end

class Child
  property age : Int32, dipper : Child?, address : Address?

  def initialize(@age, @dipper = nil, @address = nil)
  end

  def some_sub_relation; end
end

class Address
  property street

  def initialize(@street = "some street")
  end
end
```

We can define serializers next way:

```crystal
class AddressSerializer < Serializer::Base(Address)
  attributes :street
end

class ChildSerializer < Serializer::Base(Child)
  attribute :age

  has_one :some_sub_relation, ChildSerializer
  has_one :address, AddressSerializer
  has_one :dipper, ChildSerializer
end

class ModelSerializer < Serializer::Base(Model)
  attribute :name
  attribute :title, :Title, if: :test_title
  attribute :own_field

  has_many :children, ChildSerializer
  has_many :friends, ChildSerializer

  def test_title(object, options)
    options.nil? || !options[:test]?
  end

  def own_field
    12
  end
end
```

To invoke serialization:

```crystal
model = Model.new(
  friends: [
    Child.new(
      60,
      Child.new(20, address: Address.new)
    )
  ],
  parents: [] of Child
)

ModelSerializer.new(model).serialize(
  except: [:own_field],
  includes: {
    :children => [:some_sub_relation],
    :friends => { :address => nil, :dipper => [:some_sub_relation] }
  },
  meta: { :page => 0 }
)
```

Which results in:

```json
{
  "data":{
    "name":"test",
    "Title":"asd",
    "children":[],
    "friends":[
      {
        "age":60,
        "address":{
          "street":"some street"
        },
        "dipper":{
          "age":20,
          "some_sub_relation":null
        }
      }
    ]
  },
  "meta":{
    "page":0
  }
}
```

> This is pretty JSON version - actual result contains no spaces and newlines.

For API details see [documentation](https://imdrasil.github.io/serializer/latest/Serializer).

## Contributing

1. Fork it (<https://github.com/imdrasil/serializer/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Roman Kalnytskyi](https://github.com/imdrasil) - creator and maintainer
