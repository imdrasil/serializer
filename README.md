# Serializer

**Serializer** is a simple JSON serialization library for your object structure. Unlike core `JSON` module's functionality this library only covers serializing objects to JSON without parsing data back. At the same time it provides some free space for maneuvers, precise and flexible configuration WHAT, HOW and WHEN should be rendered.

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

Let's assume we have next resources relationship

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

To be able to serialize data we need to define serializers for each resource:

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

### Attributes

To specify what should be serialized `attributes` and `attribute` macros are used. `attributes` allows to pass a list of attribute names which maps one-to-one with JSON keys

```crystal
class PostSerializer
  attributes :title, body
end
```

Above serializer will produce next output `{"title": "Some title", "body": "Post body"}`. You can precisely configure every field using `attribute` macro. It allows to specify `key` name to be used in JSON and `if` predicate method name to be used to check whether field should be serialized.

```crystal
class ModelSerializer < Serializer::Base(Model)
  attribute :title, :Title, if: :test_title

  def test_title(object, options)
    options.nil? || !options[:test]?
  end
end
```

Above serializer will produce next output `{"Title": "Some title"}` if serializer has got options without `test` set to `true`.

If serializer has a method with the same name as specified field - it is used.

```crystal
class ModelSerializer < Serializer::Base(Model)
  attribute :name

  def name
    "StaticName"
  end
end
```

### Relations

If resource has underlying resources to serialize they can be specified with `has_one`, `belongs_to` and `has_many` macro methods that describes relation type between them (one-to-one, one-to-any and one-to-many).

```crystal
class ModelSerializer < Serializer::Base(Model)
  has_many :friends, ChildSerializer
end
```

They also accepts `key` option. There is no `if` support because associations by default isn't rendered.

### Meta

Resource meta data can be defined at it's level - overriding `.meta` method.

```crystal
class ModelSerializer < Serializer::Base(Model)
  def self.meta(options)
    {
      :page => options[:page]
    }
  end
end
```

Method return value should be `Hash(Symbol, JSON::Any::Type | Int32)`. Also any additional meta attributes may be defined at serialization moment (calling `#serialize` method).

### Inheritance

If you have complicated domain object relation structure - you can easily present serialization logic using inheritance:

```crystal
class ModelSerializer < Serializer::Base(Model)
  attribute :name
end

class InheritedSerializer < ModelSerializer
  attribute :inherited_field

  def inherited_field
    1.23
  end
end
```

### Rendering

To render resource create an instance of required serializer and call `#serialize`:

```crystal
ModelSerializer.new(model).serialize
```

It accepts several optional arguments:

* `except` - array of fields that should not be serialized;
* `includes` - relations that should be included into serialized string;
* `opts` - options that will be passed to *if* predicate methods and `.meta`;
* `meta` - meta attributes to be added under `"meta"` key at root level; it is merged into default meta attributes returned by `.meta`.

```crystal
ModelSerializer.new(model).serialize(
  except: [:own_field],
  includes: {
    :children => [:some_sub_relation],
    :friends => { :address => nil, :dipper => [:some_sub_relation] }
  },
  meta: { :page => 0 }
)
```

`includes` should be array or hash (any levels deep) which elements presents relation names to be serialized. `nil` value may be used in hashes as a value to define that nothing additional should be serialized for a relation named by corresponding key.

Example above results in:

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

#### Root key

Serialized JSON root level includes `data` key (and optional `meta` key). It can be renamed to anything by defining `.root_key`

```crystal
class ModelSerializer < Serializer::Base(Model)
  def self.root_key
    "model"
  end

  attribute :name
end
```

For API details see [documentation](https://imdrasil.github.io/serializer/latest/serializer).

## Contributing

1. Fork it (<https://github.com/imdrasil/serializer/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Roman Kalnytskyi](https://github.com/imdrasil) - creator and maintainer
