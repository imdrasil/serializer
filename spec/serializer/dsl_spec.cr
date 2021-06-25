require "../spec_helper"

describe Serializer::DSL do
  describe ".attribute" do
    describe "key" do
      it "uses name by default" do
        ModelSerializer.new(Model.new).serialize.should contain(%("name":))
      end

      it "uses specified name if given" do
        ModelSerializer.new(Model.new).serialize.should contain(%("Title":))
      end
    end

    describe "if" do
      it do
        serializer = ModelSerializer.new(Model.new)
        serializer.serialize.should contain(%(Title))
        serializer.serialize(opts: {:test => true}).should_not contain(%(Title))
      end
    end
  end

  describe "relation" do
    describe "key" do
      it "uses name by default" do
        ModelSerializer.new(Model.new).serialize(includes: %i(children)).should contain(%("children":))
      end

      it "uses specified name if given" do
        ModelSerializer.new(Model.new).serialize(includes: %i(parents)).should contain(%("Parents":))
      end
    end
  end
end
