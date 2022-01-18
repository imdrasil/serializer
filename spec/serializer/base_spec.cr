require "../spec_helper.cr"

class AddressWithMetaSerializer < Serializer::Base(Address)
  attributes :street

  def self.meta(*opts)
    {:page => 0}
  end
end

class ModelWithoutRootSerializer < ModelSerializer
  def self.root_key
    nil
  end
end

class ModelWithRootSerializer < ModelSerializer
  def self.root_key
    "model_with_root"
  end
end

describe Serializer::Base do
  single_serializer = ModelSerializer.new(Model.new)

  describe ".new" do
    context "with object" do
      it { ModelSerializer.new(Model.new) }
    end

    context "with collection" do
      it { ModelSerializer.new([Model.new]) }
    end

    context "with nil" do
      it { ModelSerializer.new(nil) }
    end
  end

  describe "#serialize" do
    describe "single object" do
      it { single_serializer.serialize.should eq("{\"data\":{\"name\":\"test\",\"Title\":\"asd\",\"own_field\":12}}") }
    end

    describe "collection" do
      it { ModelSerializer.new([Model.new]).serialize.should eq("{\"data\":[{\"name\":\"test\",\"Title\":\"asd\",\"own_field\":12}]}") }
    end

    describe "nil" do
      it { ModelSerializer.new(nil).serialize.should eq(%({"data":null})) }
    end

    describe "inheritance" do
      it do
        InheritedSerializer.new(Model.new).serialize(except: %i(name), includes: %i(children))
          .should eq("{\"data\":{\"Title\":\"asd\",\"own_field\":12,\"inherited_field\":1.23,\"children\":[]}}")
      end
    end

    context "with except" do
      it { single_serializer.serialize(except: %i(name)).should_not contain(%("name":)) }
    end

    context "with includes" do
      it { single_serializer.serialize(includes: %i(children)).should eq("{\"data\":{\"name\":\"test\",\"Title\":\"asd\",\"own_field\":12,\"children\":[]}}") }
      it do
        single_serializer.serialize(includes: {:children => [:sub], :friends => {:address => nil, :dipper => [:sub]}})
          .should eq("{\"data\":{\"name\":\"test\",\"Title\":\"asd\",\"own_field\":12,\"children\":[],\"friends\":[{\"age\":60,\"address\":{\"street\":\"some street\"},\"dipper\":{\"age\":100,\"sub\":null}}]}}")
      end
    end

    context "with options" do
      it { single_serializer.serialize(opts: {:test => true}).should_not contain(%("Title")) }
      it { single_serializer.serialize(opts: {:key_transform => "upcase"}).should contain(%("TITLE")) }

      context "with root key" do
        it { single_serializer.serialize(opts: {:key_transform => "upcase"}).should contain(%("DATA")) }
        it { single_serializer.serialize(opts: {:key_transform => "upcase"}, meta: { :count => 0}).should contain(%("META")) }
      end
    end

    context "with meta" do
      it do
        single_serializer.serialize(meta: {:page => 0})
          .should eq("{\"data\":{\"name\":\"test\",\"Title\":\"asd\",\"own_field\":12},\"meta\":{\"page\":0}}")
      end

      context "with default meta" do
        it { AddressWithMetaSerializer.new(Address.new).serialize.should eq("{\"data\":{\"street\":\"some street\"},\"meta\":{\"page\":0}}") }
        it { AddressWithMetaSerializer.new(Address.new).serialize(meta: {:total => 0}).should eq("{\"data\":{\"street\":\"some street\"},\"meta\":{\"page\":0,\"total\":0}}") }
        it { AddressWithMetaSerializer.new(Address.new).serialize(meta: {:page => 3}).should eq("{\"data\":{\"street\":\"some street\"},\"meta\":{\"page\":3}}") }
      end

      context "with opts" do
        it do
          single_serializer.serialize(meta: {:page => 0}, opts: { :key_transform => "upcase" }).should contain(%("PAGE"))
        end
      end
    end

    context "without root" do
      it do
        ModelWithoutRootSerializer.new(Model.new).serialize.should eq("{\"name\":\"test\",\"Title\":\"asd\",\"own_field\":12}")
      end

    end

    context "dynamic root" do
      context "without default root" do
        ModelWithoutRootSerializer.new(Model.new).serialize(opts: { :root_key => "model" }).should eq("{\"model\":{\"name\":\"test\",\"Title\":\"asd\",\"own_field\":12}}")
      end
      context "with default root" do
        ModelWithRootSerializer.new(Model.new).serialize(opts: { :root_key => "model" }).should eq("{\"model\":{\"name\":\"test\",\"Title\":\"asd\",\"own_field\":12}}")
      end
    end
  end
end
