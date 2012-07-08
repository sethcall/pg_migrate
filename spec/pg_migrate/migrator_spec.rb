require 'spec_helper'

describe Migrator do
  it "load single manifest" do
    migrator = Migrator.new({})
    manifest = migrator.load_manifest("spec/pg_migrate/manifests/single")

    manifest.length.should == 1
    manifest[0].should == "single_migrations/single1.sql"

  end

end